import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:anchor/features/notes/data/collab/collab_session.dart';
import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

Delta _delta(Object? ops) =>
    Delta.fromJson((ops as List).cast<Map<String, dynamic>>());

String _textOf(Delta doc) => doc.operations
    .map((op) => op.data is String ? op.data as String : '')
    .join();

/// Plays the server: one text, one order of changes.
class FakeServer {
  Delta doc = Delta()..insert('hello\n');
  int rev = 0;
  String epoch = 'e1';
  final List<Map<String, dynamic>> history = [];
  final List<FakeSocket> sockets = [];

  void receive(FakeSocket socket, Map<String, dynamic> message) {
    switch (message['t']) {
      case 'join':
        socket.sid = message['sid'] as String;
        final catchup = message['epoch'] == epoch
            ? history
                  .where((e) => (e['rev'] as int) > (message['rev'] as int))
                  .toList()
            : null;
        socket.deliver({
          't': 'hello',
          'me': 'peer-${socket.sid}',
          'epoch': epoch,
          'rev': rev,
          'canEdit': true,
          'title': 'T',
          'background': null,
          'peers': <Object>[],
          if (catchup != null) 'catchup': catchup else 'doc': doc.toJson(),
        });
      case 'op':
        final id = message['id'];
        final earlier = history.where(
          (e) => e['sid'] == socket.sid && e['id'] == id,
        );
        if (earlier.isNotEmpty) {
          socket.deliver({'t': 'ack', 'id': id, 'rev': earlier.first['rev']});
          return;
        }
        var change = _delta(message['ops']);
        for (final entry in history.where(
          (e) => (e['rev'] as int) > (message['rev'] as int),
        )) {
          change = _delta(entry['ops']).transform(change, true);
        }
        doc = doc.compose(change);
        rev += 1;
        final at = rev;
        history.add({
          'rev': at,
          'ops': change.toJson(),
          'sid': socket.sid,
          'id': id,
        });
        for (final other in sockets) {
          if (!identical(other, socket) && !other.isClosed) {
            other.deliver({'t': 'op', 'rev': at, 'ops': change.toJson()});
          }
        }
        socket.deliver({'t': 'ack', 'id': id, 'rev': at});
    }
  }
}

class FakeSocket implements CollabSocket {
  FakeSocket(this.server) {
    server.sockets.add(this);
  }

  final FakeServer server;
  final StreamController<String> _in = StreamController.broadcast(sync: true);
  String sid = '';
  bool isClosed = false;
  bool hold = false;
  final List<Map<String, dynamic>> outbox = [];
  final List<Map<String, dynamic>> inbox = [];
  int? code;
  final List<String> _queue = [];
  bool _isEmitting = false;

  @override
  Stream<dynamic> get messages => _in.stream;

  @override
  int? get closeCode => code;

  @override
  void send(String message) {
    if (isClosed) return;
    final decoded = jsonDecode(message) as Map<String, dynamic>;
    if (hold) {
      outbox.add(decoded);
    } else {
      server.receive(this, decoded);
    }
  }

  void deliver(Map<String, dynamic> message) {
    if (isClosed) return;
    final wire = jsonDecode(jsonEncode(message)) as Map<String, dynamic>;
    if (hold) {
      inbox.add(wire);
    } else {
      _emit(jsonEncode(wire));
    }
  }

  /// Answers to what a message makes the client send wait their turn, as they
  /// would on a real connection.
  void _emit(String message) {
    _queue.add(message);
    if (_isEmitting) return;
    _isEmitting = true;
    while (_queue.isNotEmpty && !_in.isClosed) {
      _in.add(_queue.removeAt(0));
    }
    _isEmitting = false;
    if (isClosed && !_in.isClosed) unawaited(_in.close());
  }

  /// What the server sent first arrives first, as on a real connection.
  void pump() {
    for (final message in List.of(inbox)) {
      _emit(jsonEncode(message));
    }
    inbox.clear();
    hold = false;
    for (final message in List.of(outbox)) {
      server.receive(this, message);
    }
    outbox.clear();
  }

  void dropWith(int closeCode) {
    code = closeCode;
    isClosed = true;
    if (!_isEmitting) unawaited(_in.close());
  }

  @override
  Future<void> close([int code = 1000]) async {
    if (!isClosed) dropWith(code);
  }
}

class FakeEditor implements CollabEditor {
  FakeEditor(this.doc);

  Delta doc;
  late CollabSession session;

  @override
  Delta? get collabDoc => doc;

  @override
  void applyRemote(Delta change) => doc = doc.compose(change);

  void type(Delta change) {
    doc = doc.compose(change);
    session.localChange(change);
  }
}

void main() {
  late FakeServer server;

  (CollabSession, FakeEditor) open({
    Delta? here,
    Delta? unsavedBase,
    CollabEvents events = const CollabEvents(),
  }) {
    final editor = FakeEditor(here ?? (Delta()..insert('hello\n')));
    final session = CollabSession(
      connect: () async => FakeSocket(server),
      joinFields: () async => {'link': 'tok'},
      editor: editor,
      getUnsavedBase: () => unsavedBase,
      events: events,
      random: Random(1),
    );
    editor.session = session;
    session.start();
    return (session, editor);
  }

  setUp(() => server = FakeServer());

  test("goes live with the server's text", () {
    fakeAsync((async) {
      server.doc = Delta()..insert('newer text\n');
      final (session, editor) = open();
      async.flushMicrotasks();
      expect(_textOf(editor.doc), 'newer text\n');
      expect(session.isLive, isTrue);
    });
  });

  test("keeps edits made before joining, over the server's newer text", () {
    fakeAsync((async) {
      server.doc = Delta()..insert('hello world\n');
      final (_, editor) = open(
        here: Delta()..insert('Ahello\n'),
        unsavedBase: Delta()..insert('hello\n'),
      );
      async.flushMicrotasks();
      expect(_textOf(editor.doc), 'Ahello world\n');
      expect(_textOf(server.doc), 'Ahello world\n');
    });
  });

  test('merges two people typing at once', () {
    fakeAsync((async) {
      final (_, one) = open();
      final (_, two) = open();
      async.flushMicrotasks();
      for (final socket in server.sockets) {
        socket.hold = true;
      }

      one.type(Delta()..insert('A'));
      two.type(
        Delta()
          ..retain(5)
          ..insert('B'),
      );
      two.type(
        Delta()
          ..retain(6)
          ..insert('C'),
      );

      for (var turn = 0; turn < 4; turn++) {
        for (final socket in server.sockets) {
          socket.pump();
        }
      }
      expect(_textOf(one.doc), 'AhelloBC\n');
      expect(_textOf(two.doc), 'AhelloBC\n');
      expect(_textOf(server.doc), 'AhelloBC\n');
    });
  });

  test("doesn't apply a change twice when its answer was lost", () {
    fakeAsync((async) {
      final (_, editor) = open();
      async.flushMicrotasks();
      final socket = server.sockets.single;
      socket.hold = true;
      editor.type(Delta()..insert('a'));
      // It arrives, but the connection drops before the answer does.
      server.receive(socket, socket.outbox.single);
      socket.dropWith(1006);
      async.flushMicrotasks();

      async.elapse(const Duration(seconds: 3));
      expect(_textOf(server.doc), 'ahello\n');
      expect(_textOf(editor.doc), 'ahello\n');
    });
  });

  test("keeps what's typed while disconnected", () {
    fakeAsync((async) {
      final (_, editor) = open();
      async.flushMicrotasks();
      server.sockets.single.dropWith(1006);
      async.flushMicrotasks();
      editor.type(Delta()..insert('offline '));
      final theirs = Delta()
        ..retain(5)
        ..insert('!');
      server.doc = server.doc.compose(theirs);
      server.rev += 1;
      server.history.add({
        'rev': server.rev,
        'ops': theirs.toJson(),
        'sid': 'other',
        'id': 1,
      });

      async.elapse(const Duration(seconds: 3));
      expect(_textOf(editor.doc), 'offline hello!\n');
      expect(_textOf(server.doc), 'offline hello!\n');
    });
  });

  test('hands saving back after a long loss of connection', () {
    fakeAsync((async) {
      final live = <bool>[];
      final editor = FakeEditor(Delta()..insert('hello\n'));
      var connections = 0;
      final session = CollabSession(
        connect: () async {
          connections += 1;
          if (connections > 1) throw const SocketException('down');
          return FakeSocket(server);
        },
        joinFields: () async => {'link': 'tok'},
        editor: editor,
        getUnsavedBase: () => null,
        events: CollabEvents(onLive: live.add),
        random: Random(1),
      );
      editor.session = session;
      session.start();
      async.flushMicrotasks();
      server.sockets.single.dropWith(1006);
      async.flushMicrotasks();
      editor.type(Delta()..insert('a'));

      async.elapse(const Duration(seconds: 16));
      expect(live, [true, false]);
      expect(session.isTracking, isFalse);
    });
  });

  test('says when the note is gone, and stops', () {
    fakeAsync((async) {
      var gone = false;
      open(events: CollabEvents(onGone: () => gone = true));
      async.flushMicrotasks();
      server.sockets.single.dropWith(4404);
      async.flushMicrotasks();
      expect(gone, isTrue);
      async.elapse(const Duration(seconds: 70));
      expect(server.sockets, hasLength(1));
    });
  });

  test("moves others' carets over text that changes", () {
    fakeAsync((async) {
      var peers = <CollabPeer>[];
      final (_, editor) = open(
        events: CollabEvents(onPeers: (next) => peers = next),
      );
      async.flushMicrotasks();
      final socket = server.sockets.single;
      socket.deliver({
        't': 'peer',
        'id': 'p',
        'name': 'Guest',
        'canEdit': true,
        'index': 3,
        'length': 0,
        'rev': 0,
      });
      expect(peers.single.index, 3);

      editor.type(Delta()..insert('AB'));
      expect(peers.single.index, 5);

      socket.deliver({
        't': 'op',
        'rev': 2,
        'ops': [
          {'insert': 'Z'},
        ],
      });
      expect(peers.single.index, 6);
    });
  });

  group('the vectors from the server', () {
    final vectors =
        jsonDecode(
              File(
                '../server/test/fixtures/collab-ot-vectors.json',
              ).readAsStringSync(),
            )
            as List;

    test('rebase and merge as the server and web do', () {
      expect(vectors.length, greaterThan(100));
      for (final raw in vectors.cast<Map<String, dynamic>>()) {
        final doc = _delta(raw['doc']);
        final a = _delta(raw['a']);
        final b = _delta(raw['b']);
        final aThenB = doc.compose(a).compose(a.transform(b, true));
        final bThenA = doc.compose(b).compose(b.transform(a, false));
        expect(
          canonicalOps(aThenB),
          canonicalOps(_delta(raw['aThenB'])),
          reason: 'a then b, for $raw',
        );
        expect(
          canonicalOps(bThenA),
          canonicalOps(_delta(raw['bThenA'])),
          reason: 'b then a, for $raw',
        );
      }
    });

    test('move a caret as the web does', () {
      for (final raw in vectors.cast<Map<String, dynamic>>()) {
        final a = _delta(raw['a']);
        final position = raw['position'] as int;
        expect(a.transformPosition(position), raw['positionOverA']);
        expect(
          a.transformPosition(position, force: false),
          raw['positionOverAForced'],
        );
      }
    });
  });
}
