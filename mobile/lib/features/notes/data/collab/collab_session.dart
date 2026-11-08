import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/ids.dart';

/// While a dropped connection may still come back, edits wait for it.
const Duration _fallbackAfter = Duration(seconds: 15);
const Duration _minRetry = Duration(seconds: 1);
const Duration _maxRetry = Duration(seconds: 60);
const Duration _cursorThrottle = Duration(milliseconds: 60);
const Duration _drainTimeout = Duration(seconds: 5);
const int _maxResets = 3;

const int _closeGone = 4404;
const int _closeUnauthorized = 4401;
const int _closeFull = 4409;

@immutable
class CollabPeer {
  const CollabPeer({
    required this.id,
    required this.name,
    required this.canEdit,
    required this.index,
    required this.length,
    required this.rev,
  });

  factory CollabPeer.fromJson(Map<String, dynamic> json) => CollabPeer(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    canEdit: json['canEdit'] as bool? ?? false,
    index: json['index'] as int?,
    length: json['length'] as int? ?? 0,
    rev: json['rev'] as int? ?? 0,
  );

  final String id;
  final String name;
  final bool canEdit;
  final int? index;
  final int length;
  final int rev;

  CollabPeer at(int? index, int length, int rev) => CollabPeer(
    id: id,
    name: name,
    canEdit: canEdit,
    index: index,
    length: length,
    rev: rev,
  );
}

abstract interface class CollabEditor {
  /// Null while there is no editor.
  Delta? get collabDoc;

  /// Applies others' change; it must not come back through localChange.
  void applyRemote(Delta change);
}

abstract interface class CollabSocket {
  Stream<dynamic> get messages;
  int? get closeCode;
  void send(String message);
  Future<void> close([int code = 1000]);
}

/// What a session says to whoever holds it.
class CollabEvents {
  const CollabEvents({
    this.onLive,
    this.onPeers,
    this.onMeta,
    this.onCanEdit,
    this.onSaved,
    this.onGone,
  });

  final void Function(bool isLive)? onLive;
  final void Function(List<CollabPeer> peers)? onPeers;

  /// Only the fields present changed.
  final void Function(Map<String, dynamic> meta)? onMeta;
  final void Function(bool canEdit)? onCanEdit;
  final void Function(int version)? onSaved;
  final VoidCallback? onGone;
}

int docLength(Delta doc) {
  var length = 0;
  for (final op in doc.operations) {
    length += op.length ?? 0;
  }
  return length;
}

/// The same text and formatting, whatever order its attributes were set in.
String canonicalOps(Delta doc) => jsonEncode([
  for (final op in Delta().compose(doc).toJson())
    {
      'insert': op['insert'],
      if (op['attributes'] case final Map<dynamic, dynamic> attributes)
        'attributes': {
          for (final key in attributes.keys.toList()..sort())
            key: attributes[key],
        },
    },
]);

bool _sameDoc(Delta a, Delta b) => canonicalOps(a) == canonicalOps(b);

/// This client's end of editing a note together: the same steps as the web
/// app's (`web/features/notes/collab/session.ts`). A change goes up one at a
/// time: what's typed while one is on its way waits, and both are rebased over
/// whatever arrives from others, so every client ends up with the same text.
class CollabSession {
  CollabSession({
    required this.connect,
    required this.joinFields,
    required this.editor,
    required this.getUnsavedBase,
    this.refreshJwt,
    this.events = const CollabEvents(),
    Random? random,
  }) : _random = random ?? Random();

  final Future<CollabSocket> Function() connect;

  /// Who's asking, and for which note.
  final Future<Map<String, dynamic>> Function() joinFields;
  final CollabEditor editor;

  /// The last saved text when the editor holds edits beyond it, else null.
  final Delta? Function() getUnsavedBase;
  final Future<bool> Function()? refreshJwt;
  final CollabEvents events;
  final Random _random;

  final String _sid = newId();
  final Map<String, CollabPeer> _peers = {};
  CollabSocket? _socket;
  StreamSubscription<dynamic>? _messages;
  bool _isOpenForEdits = false;
  bool _isClosed = false;
  bool _isGivenUp = false;
  bool _isLive = false;
  bool _canEdit = false;
  String? _epoch;
  int _rev = 0;

  /// The text at [_rev], without what's on its way or waiting.
  Delta? _shadow;
  int? _flightId;
  Delta? _flight;
  Delta _waiting = Delta();
  int _nextId = 1;
  int _attempt = 0;
  int _resets = 0;
  bool _hasRefreshedJwt = false;
  Timer? _retryTimer;
  Timer? _fallbackTimer;
  Timer? _cursorTimer;
  TextRangeLike? _cursor;
  bool _isCursorDirty = false;
  Completer<void>? _drained;

  bool get isLive => _isLive;

  /// While true, the editor's changes go here and nowhere else.
  bool get isTracking => _shadow != null;

  /// Typed changes the server hasn't confirmed.
  bool get hasPending => _flight != null || _waiting.isNotEmpty;

  Delta? get serverDoc => _shadow;

  void start() {
    if (_socket == null && !_isClosed && !_isGivenUp) unawaited(_connect());
  }

  void localChange(Delta change) {
    if (!isTracking || change.isEmpty) return;
    _waiting = _waiting.compose(change);
    _shiftPeers(change, null);
    _flush();
  }

  /// Null when this client's caret isn't in the text.
  void setCursor(int? index, int length) {
    _cursor = index == null ? null : TextRangeLike(index, length);
    _isCursorDirty = true;
    _cursorTimer ??= Timer(_cursorThrottle, () {
      _cursorTimer = null;
      _sendCursor();
    });
  }

  void setMeta(Map<String, dynamic> meta) {
    if (_isOpenForEdits && _canEdit) _send({'t': 'meta', ...meta});
  }

  /// Waits a moment for what's on its way, then leaves.
  Future<void> close() async {
    if (_isClosed) return;
    if (hasPending && _isOpenForEdits) {
      final drained = _drained = Completer<void>();
      await drained.future.timeout(_drainTimeout, onTimeout: () {});
    }
    _isClosed = true;
    _stopTimers();
    final socket = _socket;
    _socket = null;
    unawaited(_messages?.cancel());
    if (_isLive) {
      _isLive = false;
      events.onLive?.call(false);
    }
    await socket?.close();
  }

  void _stopTimers() {
    _retryTimer?.cancel();
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    _cursorTimer?.cancel();
    _cursorTimer = null;
  }

  Future<void> _connect() async {
    if (_isClosed || _isGivenUp) return;
    final CollabSocket socket;
    final Map<String, dynamic> fields;
    try {
      fields = await joinFields();
      socket = await connect();
    } catch (_) {
      _scheduleRetry();
      _armFallback();
      return;
    }
    if (_isClosed || _isGivenUp) {
      unawaited(socket.close());
      return;
    }
    _socket = socket;
    _messages = socket.messages.listen(
      (raw) {
        if (!identical(_socket, socket)) return;
        try {
          _receive(jsonDecode(raw as String) as Map<String, dynamic>);
        } catch (_) {
          // The texts no longer line up: start over from the server's.
          _startOver();
        }
      },
      onDone: () {
        if (identical(_socket, socket)) _dropped(socket.closeCode);
      },
      onError: (_) {
        if (identical(_socket, socket)) _dropped(socket.closeCode);
      },
      cancelOnError: true,
    );
    socket.send(
      jsonEncode({
        't': 'join',
        'sid': _sid,
        ...fields,
        if (_epoch != null) ...{'epoch': _epoch, 'rev': _rev},
      }),
    );
  }

  void _dropped(int? code) {
    _socket = null;
    _isOpenForEdits = false;
    _peers.clear();
    _tellPeers();
    if (_isClosed) return;
    if (code == _closeGone) {
      _giveUp();
      events.onGone?.call();
      return;
    }
    if (code == _closeFull) {
      _giveUp();
      return;
    }
    if (code == _closeUnauthorized) {
      final refresh = refreshJwt;
      if (refresh == null || _hasRefreshedJwt) {
        _giveUp();
        return;
      }
      _hasRefreshedJwt = true;
      unawaited(
        refresh().then((ok) {
          if (ok) {
            _scheduleRetry();
          } else {
            _giveUp();
          }
        }),
      );
      return;
    }
    _armFallback();
    _scheduleRetry();
  }

  void _armFallback() {
    if (_isLive && _fallbackTimer == null) {
      _fallbackTimer = Timer(_fallbackAfter, _fallBack);
    }
  }

  void _scheduleRetry() {
    if (_isClosed || _isGivenUp) return;
    final backoff = min(
      _minRetry.inMilliseconds * (1 << _attempt),
      _maxRetry.inMilliseconds,
    );
    _attempt = min(_attempt + 1, 6);
    final jitter = 0.75 + _random.nextDouble() * 0.5;
    _retryTimer?.cancel();
    _retryTimer = Timer(
      Duration(milliseconds: (backoff * jitter).round()),
      () => unawaited(_connect()),
    );
  }

  /// The host's own saving takes over, from the text on screen.
  void _fallBack() {
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    _shadow = null;
    _flight = null;
    _flightId = null;
    _waiting = Delta();
    _epoch = null;
    if (_isLive) {
      _isLive = false;
      events.onLive?.call(false);
    }
    _settle();
  }

  void _giveUp() {
    _isGivenUp = true;
    _stopTimers();
    final socket = _socket;
    _socket = null;
    unawaited(socket?.close());
    _fallBack();
  }

  void _startOver() {
    _resets += 1;
    if (_resets > _maxResets) {
      _giveUp();
      return;
    }
    _epoch = null;
    final socket = _socket;
    _socket = null;
    _isOpenForEdits = false;
    unawaited(socket?.close());
    _scheduleRetry();
  }

  void _settle() {
    if (!hasPending) {
      final drained = _drained;
      if (drained != null && !drained.isCompleted) drained.complete();
    }
  }

  void _receive(Map<String, dynamic> message) {
    switch (message['t']) {
      case 'hello':
        _hello(message);
      case 'ack':
        _ack(message['id'] as int, message['rev'] as int);
      case 'nack':
        _flight = null;
        _flightId = null;
        _waiting = Delta();
        _settle();
      case 'op':
        _remote(_deltaOf(message['ops']), message['rev'] as int);
      case 'peer':
        final peer = CollabPeer.fromJson(message);
        _peers[peer.id] = peer;
        _tellPeers();
      case 'peerGone':
        _peers.remove(message['id']);
        _tellPeers();
      case 'cursor':
        final peer = _peers[message['id']];
        if (peer != null) {
          final index = message['index'] as int?;
          _peers[peer.id] = peer.at(
            index == null ? null : _pendingChange().transformPosition(index),
            message['length'] as int? ?? 0,
            message['rev'] as int? ?? _rev,
          );
          _tellPeers();
        }
      case 'meta':
        final canEdit = message['canEdit'];
        if (canEdit is bool) {
          _canEdit = canEdit;
          events.onCanEdit?.call(canEdit);
        }
        final meta = {
          if (message.containsKey('title')) 'title': message['title'],
          if (message.containsKey('background'))
            'background': message['background'],
        };
        if (meta.isNotEmpty) events.onMeta?.call(meta);
      case 'saved':
        events.onSaved?.call(message['version'] as int);
    }
  }

  Delta _deltaOf(dynamic ops) =>
      Delta.fromJson((ops as List).cast<Map<String, dynamic>>());

  Delta _pendingChange() => (_flight ?? Delta()).compose(_waiting);

  void _hello(Map<String, dynamic> message) {
    if (editor.collabDoc == null) return;
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    _attempt = 0;
    _hasRefreshedJwt = false;
    _epoch = message['epoch'] as String?;
    _canEdit = message['canEdit'] as bool? ?? false;
    events.onCanEdit?.call(_canEdit);

    final catchup = message['catchup'];
    final shadow = _shadow;
    if (catchup is List && shadow != null) {
      for (final raw in catchup.cast<Map<String, dynamic>>()) {
        final ops = _deltaOf(raw['ops']);
        final rev = raw['rev'] as int;
        if (raw['sid'] != _sid) {
          _remote(ops, rev);
        } else if (_flightId == raw['id']) {
          _ack(raw['id'] as int, rev);
        } else {
          // An older change of ours, acknowledged before.
          _shadow = _shadow!.compose(ops);
          _rev = rev;
        }
      }
    } else {
      _adopt(_deltaOf(message['doc']), message['rev'] as int);
    }

    _isOpenForEdits = true;
    _peers.clear();
    for (final raw
        in (message['peers'] as List? ?? []).cast<Map<String, dynamic>>()) {
      final peer = CollabPeer.fromJson(raw);
      _peers[peer.id] = peer;
    }
    _tellPeers();
    if (!_isLive) {
      _isLive = true;
      events.onLive?.call(true);
    }
    events.onMeta?.call({
      'title': message['title'],
      'background': message['background'],
    });
    final version = message['version'];
    if (version is int) events.onSaved?.call(version);

    final flight = _flight;
    if (flight != null) {
      // Lost with the connection: if it did arrive, the server knows its id.
      _send({'t': 'op', 'rev': _rev, 'id': _flightId, 'ops': flight.toJson()});
    }
    _flush();
    _settle();
    _isCursorDirty = true;
    _sendCursor();
  }

  /// Everything's rebased from the last text both sides knew onto the server's.
  void _adopt(Delta server, int rev) {
    final here = editor.collabDoc;
    if (here == null) return;
    final Delta from;
    final Delta mine;
    final shadow = _shadow;
    if (shadow != null) {
      from = shadow;
      mine = _pendingChange();
    } else {
      final base = getUnsavedBase();
      from = base ?? here;
      mine = base == null ? Delta() : base.diff(here);
    }
    _flight = null;
    _flightId = null;
    if (_sameDoc(from.compose(mine), server)) {
      // Nothing to do: what's here arrived, even if we weren't told.
      _waiting = Delta();
    } else {
      final theirs = from.diff(server);
      final toApply = mine.transform(theirs, false);
      _waiting = theirs.transform(mine, true);
      if (toApply.isNotEmpty) editor.applyRemote(toApply);
    }
    _shadow = server;
    _rev = rev;
    final expected = docLength(server.compose(_waiting));
    final now = editor.collabDoc;
    if (now != null && docLength(now) != expected) _startOver();
  }

  void _ack(int id, int rev) {
    final flight = _flight;
    final shadow = _shadow;
    if (flight == null || _flightId != id || shadow == null) return;
    _shadow = shadow.compose(flight);
    _rev = rev;
    _flight = null;
    _flightId = null;
    _flush();
    _settle();
    _checkLinedUp();
    if (_isCursorDirty) _sendCursor();
  }

  void _remote(Delta change, int rev) {
    final shadow = _shadow;
    if (shadow == null) return;
    _shadow = shadow.compose(change);
    _rev = rev;
    var incoming = change;
    final flight = _flight;
    if (flight != null) {
      _flight = incoming.transform(flight, true);
      incoming = flight.transform(incoming, false);
    }
    final waiting = _waiting;
    _waiting = incoming.transform(waiting, true);
    incoming = waiting.transform(incoming, false);
    if (incoming.isNotEmpty) editor.applyRemote(incoming);
    _shiftPeers(incoming, rev);
    _checkLinedUp();
  }

  /// A caret sent after this change already allows for it.
  void _shiftPeers(Delta change, int? rev) {
    for (final peer in _peers.values.toList()) {
      final index = peer.index;
      if (index == null || (rev != null && rev <= peer.rev)) continue;
      final end = change.transformPosition(index + peer.length);
      final start = change.transformPosition(index);
      _peers[peer.id] = peer.at(start, max(end - start, 0), peer.rev);
    }
    _tellPeers();
  }

  void _checkLinedUp() {
    final shadow = _shadow;
    final doc = editor.collabDoc;
    if (hasPending || shadow == null || doc == null) return;
    if (docLength(doc) != docLength(shadow)) _startOver();
  }

  void _flush() {
    if (_flight != null || !_isOpenForEdits || !_canEdit || _waiting.isEmpty) {
      return;
    }
    _flight = _waiting;
    _flightId = _nextId++;
    _waiting = Delta();
    _send({'t': 'op', 'rev': _rev, 'id': _flightId, 'ops': _flight!.toJson()});
  }

  void _sendCursor() {
    // Its position counts what's typed, which the server must have first.
    if (!_isCursorDirty ||
        !_isOpenForEdits ||
        !_canEdit ||
        _waiting.isNotEmpty) {
      return;
    }
    _isCursorDirty = false;
    _send({
      't': 'cursor',
      'index': _cursor?.index,
      'length': _cursor?.length ?? 0,
      'rev': _rev,
    });
  }

  void _tellPeers() => events.onPeers?.call(_peers.values.toList());

  void _send(Map<String, dynamic> message) {
    _socket?.send(jsonEncode(message));
  }
}

class TextRangeLike {
  const TextRangeLike(this.index, this.length);

  final int index;
  final int length;
}
