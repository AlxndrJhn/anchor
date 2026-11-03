import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'live_signals.dart';

part 'live_host.g.dart';

@Riverpod(keepAlive: true)
LiveHost liveHost(Ref ref) {
  final host = LiveHost(ref.watch(liveSignalsProvider));
  ref.onDispose(host.dispose);
  return host;
}

/// One camera this phone shows as a live image.
class LiveCapture {
  LiveCapture({
    required this.noteId,
    required this.stream,
    required this.isFront,
  });

  final String noteId;
  final MediaStream stream;
  final bool isFront;

  bool get hasMic => stream.getAudioTracks().isNotEmpty;

  bool get isMuted =>
      hasMic && stream.getAudioTracks().every((track) => !track.enabled);

  /// 'on', 'muted', or null without a microphone, as the web app says it.
  String? get mic => hasMic ? (isMuted ? 'muted' : 'on') : null;
}

class _Sender {
  _Sender(this.pc, this.liveId, this.noteId, this.to);

  final RTCPeerConnection pc;
  final String liveId;
  final String noteId;
  final Map<String, dynamic> to;
  bool isConnected = false;
}

/// This phone's side of the live images it added: it keeps the camera on
/// and answers every device that asks for the video, as the web app's
/// live-hub.ts does. The video goes straight to them; only the messages
/// that connect go through the server (see [LiveSignals]).
class LiveHost extends ChangeNotifier {
  LiveHost(this._signals) {
    _messages = _signals.messages.listen(_receive);
  }

  final LiveSignals _signals;
  late final StreamSubscription<Map<String, dynamic>> _messages;
  final _captures = <String, LiveCapture>{};
  final _senders = <String, _Sender>{};

  /// The microphone choice of each live image added here, for turning the
  /// camera on again.
  final _withMic = <String, bool>{};

  final String _tab = 'phone';

  Map<String, dynamic> get _me => {'device': LiveSignals.device, 'tab': _tab};

  LiveCapture? captureOf(String liveId) => _captures[liveId];

  /// How many devices watch live image [liveId] now.
  int viewersOf(String liveId) => _senders.values
      .where((sender) => sender.liveId == liveId && sender.isConnected)
      .length;

  /// Turns on the front or back camera, and the microphone with it.
  static Future<MediaStream> openCamera({
    required bool isFront,
    required bool withMic,
  }) => navigator.mediaDevices.getUserMedia({
    'video': {
      'facingMode': isFront ? 'user' : 'environment',
      'width': {'ideal': 1280},
      'height': {'ideal': 720},
    },
    'audio': withMic,
  });

  /// Shows [stream] as live image [liveId] of [noteId] from now on.
  void adopt(
    String liveId,
    String noteId,
    MediaStream stream, {
    required bool isFront,
  }) {
    stop(liveId);
    _captures[liveId] = LiveCapture(
      noteId: noteId,
      stream: stream,
      isFront: isFront,
    );
    _withMic[liveId] = stream.getAudioTracks().isNotEmpty;
    notifyListeners();
    _send(noteId, liveId, 'ready');
  }

  /// Turns the camera on again for live image [liveId], after a tap.
  Future<void> restart(String liveId, String noteId, {bool? isFront}) async {
    final stream = await openCamera(
      isFront: isFront ?? true,
      withMic: _withMic[liveId] ?? false,
    );
    adopt(liveId, noteId, stream, isFront: isFront ?? true);
  }

  /// Stops the camera; watchers wait for it to come back.
  void stop(String liveId) {
    final capture = _captures.remove(liveId);
    if (capture == null) return;
    for (final track in capture.stream.getTracks()) {
      unawaited(track.stop());
    }
    unawaited(capture.stream.dispose());
    for (final entry in [..._senders.entries]) {
      if (entry.value.liveId != liveId) continue;
      _send(
        capture.noteId,
        liveId,
        'bye',
        to: entry.value.to,
        session: entry.key,
      );
      unawaited(entry.value.pc.close());
      _senders.remove(entry.key);
    }
    notifyListeners();
  }

  /// Stops every live image of [noteId]: the note was trashed or deleted.
  void closeNote(String noteId) {
    for (final entry in [..._captures.entries]) {
      if (entry.value.noteId == noteId) stop(entry.key);
    }
  }

  void setMicMuted(String liveId, bool isMuted) {
    final capture = _captures[liveId];
    if (capture == null) return;
    for (final track in capture.stream.getAudioTracks()) {
      track.enabled = !isMuted;
    }
    for (final entry in _senders.entries) {
      if (entry.value.liveId != liveId) continue;
      _send(
        capture.noteId,
        liveId,
        'mic',
        to: entry.value.to,
        session: entry.key,
        data: {'mic': capture.mic},
      );
    }
    notifyListeners();
  }

  void _send(
    String noteId,
    String liveId,
    String kind, {
    Map<String, dynamic>? to,
    String? session,
    Map<String, dynamic>? data,
  }) {
    unawaited(
      _signals.send({
        'noteId': noteId,
        'liveId': liveId,
        'kind': kind,
        'from': _me,
        'to': ?to,
        'session': ?session,
        'data': ?data,
      }),
    );
  }

  void _announceViewers(String liveId) {
    final capture = _captures[liveId];
    if (capture == null) return;
    final count = viewersOf(liveId);
    for (final entry in _senders.entries) {
      if (entry.value.liveId != liveId) continue;
      _send(
        capture.noteId,
        liveId,
        'viewers',
        to: entry.value.to,
        session: entry.key,
        data: {'count': count},
      );
    }
    notifyListeners();
  }

  void _receive(Map<String, dynamic> message) {
    final kind = message['kind'];
    final noteId = message['noteId'];
    if (noteId is! String) return;
    if (kind == 'stop') {
      closeNote(noteId);
      return;
    }
    final to = message['to'];
    if (to is! Map || to['device'] != LiveSignals.device) return;
    if (to['tab'] != null && to['tab'] != _tab) return;
    final from = message['from'];
    final liveId = message['liveId'];
    final session = message['session'];
    if (from is! Map<String, dynamic> || liveId is! String) return;
    if (session is! String) return;
    final data = message['data'];
    switch (kind) {
      case 'want':
        final capture = _captures[liveId];
        if (capture == null) {
          _send(noteId, liveId, 'unavailable', to: from, session: session);
        } else if (capture.noteId == noteId) {
          unawaited(_offer(liveId, capture, from, session).catchError((_) {}));
        }
      case 'answer':
        final sender = _senders[session];
        final sdp = data is Map ? data['sdp'] : null;
        if (sender != null && sdp is String) {
          unawaited(
            sender.pc
                .setRemoteDescription(RTCSessionDescription(sdp, 'answer'))
                .catchError((_) {}),
          );
        }
      case 'ice':
        final sender = _senders[session];
        final candidate = data is Map ? data['candidate'] : null;
        if (sender != null && candidate is String && candidate.isNotEmpty) {
          unawaited(
            sender.pc
                .addCandidate(
                  RTCIceCandidate(
                    candidate,
                    data['sdpMid'] as String?,
                    (data['sdpMLineIndex'] as num?)?.toInt(),
                  ),
                )
                .catchError((_) {}),
          );
        }
      case 'bye':
        final sender = _senders.remove(session);
        if (sender != null) {
          unawaited(sender.pc.close());
          _announceViewers(sender.liveId);
        }
    }
  }

  Future<void> _offer(
    String liveId,
    LiveCapture capture,
    Map<String, dynamic> to,
    String session,
  ) async {
    unawaited(_senders.remove(session)?.pc.close());
    final pc = await createPeerConnection({
      'iceServers': await _signals.iceServers(),
      'sdpSemantics': 'unified-plan',
    });
    final sender = _Sender(pc, liveId, capture.noteId, to);
    _senders[session] = sender;
    for (final track in capture.stream.getTracks()) {
      await pc.addTrack(track, capture.stream);
    }
    pc.onIceCandidate = (candidate) {
      final text = candidate.candidate;
      if (text == null || text.isEmpty) return;
      _send(
        capture.noteId,
        liveId,
        'ice',
        to: to,
        session: session,
        data: {
          'candidate': text,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      );
    };
    pc.onConnectionState = (state) {
      if (_senders[session] != sender) return;
      switch (state) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          sender.isConnected = true;
          _announceViewers(liveId);
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
          _senders.remove(session);
          unawaited(pc.close());
          _announceViewers(liveId);
        default:
      }
    };
    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    if (_senders[session] != sender) return;
    _send(
      capture.noteId,
      liveId,
      'offer',
      to: to,
      session: session,
      data: {'type': offer.type, 'sdp': offer.sdp, 'mic': capture.mic},
    );
  }

  @override
  void dispose() {
    unawaited(_messages.cancel());
    for (final liveId in [..._captures.keys]) {
      stop(liveId);
    }
    super.dispose();
  }
}
