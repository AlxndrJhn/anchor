import 'dart:async';

import 'package:just_audio/just_audio.dart';

extension AudioPlayback on AudioPlayer {
  /// Pauses and rewinds the player once it plays to the end.
  Stream<bool> get isPlayingStream => playerStateStream.map((state) {
    final hasFinished = state.processingState == ProcessingState.completed;
    if (hasFinished) {
      unawaited(pause());
      unawaited(seek(Duration.zero));
    }
    return state.playing && !hasFinished;
  });
}
