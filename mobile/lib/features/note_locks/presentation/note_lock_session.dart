import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/logging/log_tags.dart';
import '../../../core/session/active_user_id_provider.dart';
import '../../notes/domain/note.dart';

part 'note_lock_session.g.dart';

/// Talks to MainActivity, which watches for the screen turning off.
const noteLockChannel = MethodChannel('anchor/lock');

/// The locked notes opened since the phone was last locked. Kept in memory
/// only, so it also ends with the app's process. Switching apps keeps it;
/// the screen turning off ends it ("screenOff" from MainActivity, or, if
/// that came while Flutter wasn't listening, "takeScreenOff" on resume).
@Riverpod(keepAlive: true)
class NoteLockSession extends _$NoteLockSession {
  AppLifecycleListener? _lifecycle;

  @override
  Set<String> build() {
    // Someone else signing in starts afresh.
    ref.watch(activeUserIdProvider);

    noteLockChannel.setMethodCallHandler((call) async {
      if (call.method == 'screenOff') end();
    });
    _lifecycle = AppLifecycleListener(onResume: _checkScreenOff);
    ref.onDispose(() {
      noteLockChannel.setMethodCallHandler(null);
      _lifecycle?.dispose();
      _lifecycle = null;
    });
    return const {};
  }

  Future<void> _checkScreenOff() async {
    try {
      final wentOff = await noteLockChannel.invokeMethod<bool>('takeScreenOff');
      if (wentOff == true) end();
    } on PlatformException catch (e) {
      AppLogger.instance.warn(LogTags.noteLocks, 'Screen state unknown: $e');
    } on MissingPluginException {
      // Not running on the activity (tests, other platforms).
    }
  }

  void unlock(String noteId) {
    if (state.contains(noteId)) return;
    state = {...state, noteId};
  }

  /// This note locks again, the others stay as they are.
  void relock(String noteId) {
    if (!state.contains(noteId)) return;
    state = {...state}..remove(noteId);
  }

  /// Every note locks again.
  void end() {
    if (state.isEmpty) return;
    AppLogger.instance.info(
      LogTags.noteLocks,
      'Session ended, notes locked again',
    );
    state = const {};
  }
}

/// Locked and not opened this session: shown with its title only.
bool isNoteHidden(Note note, Set<String> unlocked) =>
    note.lock != null && !unlocked.contains(note.id);
