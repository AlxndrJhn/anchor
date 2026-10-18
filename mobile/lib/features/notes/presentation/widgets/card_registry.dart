import 'package:flutter/widgets.dart';

import '../../../../core/widgets/global_rect_of.dart';

abstract final class CardRegistry {
  static final Map<String, GlobalKey> _keys = {};

  static final ValueNotifier<Set<String>> hidden = ValueNotifier(const {});

  static final ValueNotifier<Set<String>> leaving = ValueNotifier(const {});

  static void leave(Iterable<String> noteIds) =>
      leaving.value = {...leaving.value, ...noteIds};

  static void forgetLeavingExcept(Set<String> shownIds) {
    final kept = leaving.value.where(shownIds.contains).toSet();
    if (kept.length != leaving.value.length) leaving.value = kept;
  }

  static GlobalKey keyFor(String noteId) =>
      _keys.putIfAbsent(noteId, () => GlobalKey(debugLabel: 'card $noteId'));

  static Rect? rectOf(String noteId) =>
      globalRectOf(_keys[noteId]?.currentContext);

  /// [keyFor] marks the [RepaintBoundary] around the content.
  static Widget? contentOf(String? noteId) =>
      switch (_keys[noteId]?.currentWidget) {
        RepaintBoundary(:final child) => child,
        _ => null,
      };

  static final GlobalKey newNoteButton = GlobalKey(debugLabel: 'new note');

  static Rect? newNoteRect() => globalRectOf(newNoteButton.currentContext);

  static final Map<String, int> _hideCounts = {};

  /// Each [hide] needs its own [show]: two open notes can hide one card.
  static void hide(String noteId) {
    _hideCounts[noteId] = (_hideCounts[noteId] ?? 0) + 1;
    hidden.value = {..._hideCounts.keys};
  }

  static void show(String noteId) {
    final count = (_hideCounts[noteId] ?? 0) - 1;
    count > 0 ? _hideCounts[noteId] = count : _hideCounts.remove(noteId);
    hidden.value = {..._hideCounts.keys};
  }
}
