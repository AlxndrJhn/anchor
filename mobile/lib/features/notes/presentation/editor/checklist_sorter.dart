import 'dart:async';

import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../domain/note_blocks.dart';
import 'checklist_lines.dart';
import 'document_lines.dart';

class ChecklistSorter {
  ChecklistSorter(
    this._controller, {
    required bool Function() isEnabled,
    Duration Function()? delay,
    void Function(Delta move, TextSelection selection)? compose,
    VoidCallback? onSettled,
  }) : _isEnabled = isEnabled,
       _delay = delay ?? (() => Duration.zero),
       _compose = compose,
       _onSettled = onSettled;

  final QuillController _controller;
  final bool Function() _isEnabled;
  final Duration Function() _delay;
  final void Function(Delta move, TextSelection selection)? _compose;

  /// A waiting line stopped waiting without a move.
  final VoidCallback? _onSettled;
  final List<_PendingSort> _waiting = [];
  bool _isDisposed = false;

  void handleChange(DocChange change) {
    if (_isDisposed) return;
    for (final pending in _waiting) {
      pending.newline = change.change.transformPosition(pending.newline);
    }
    if (change.source != ChangeSource.local || !_isEnabled()) return;

    final newline = _toggledNewlineOffset(change);
    if (newline == null) return;

    final waiting = _waiting.where((s) => s.newline == newline).firstOrNull;
    if (waiting != null) {
      _cancel(waiting);
      return;
    }
    // A line that stays put isn't waiting: nothing would settle it.
    if (_sortOf(newline) == null) return;
    final history = _controller.document.history;
    final pending = _PendingSort(
      newline,
      lastRecorded: history.lastRecorded,
      steps: history.stack.undo.length,
    );
    _waiting.add(pending);
    final delay = _delay();
    if (delay == Duration.zero) {
      // A microtask runs before the editor's post-frame selection restore.
      scheduleMicrotask(() => _run(pending));
    } else {
      pending.timer = Timer(delay, () => _run(pending));
    }
  }

  /// Whether [line] was just toggled and is still to move to its place.
  bool isWaiting(Line line) {
    if (_waiting.isEmpty) return false;
    final newline = line.documentOffset + line.length - 1;
    return _waiting.any((s) => s.newline == newline);
  }

  void cancelAll() {
    for (final pending in [..._waiting]) {
      _cancel(pending);
    }
  }

  void dispose() {
    _isDisposed = true;
    cancelAll();
  }

  void _cancel(_PendingSort pending) {
    pending.timer?.cancel();
    _waiting.remove(pending);
  }

  void _run(_PendingSort pending) {
    if (_isDisposed || !_waiting.remove(pending)) return;
    if (!_isEnabled()) return _onSettled?.call();
    final history = _controller.document.history;
    // The move joins the check's Undo step unless something came between.
    if (history.lastRecorded == pending.lastRecorded &&
        history.stack.undo.length == pending.steps) {
      history.lastRecorded = DateTime.now().millisecondsSinceEpoch;
    }
    _sortToggledLine(pending.newline);
  }

  int? _toggledNewlineOffset(DocChange change) {
    var position = 0;
    int? found;
    Object? value;
    for (final op in change.change.toList()) {
      if (!op.isRetain) return null;
      final list = op.attributes?[Attribute.list.key];
      if (isChecklistValue(list)) {
        if (found != null || op.length != 1) return null;
        found = position;
        value = list;
      }
      position += op.length!;
    }
    if (found == null) return null;
    final was = _listValueAt(change.before, found);
    return isChecklistValue(was) && was != value ? found : null;
  }

  static Object? _listValueAt(Delta document, int offset) {
    var position = 0;
    for (final op in document.toList()) {
      position += op.length!;
      if (position > offset) return op.attributes?[Attribute.list.key];
    }
    return null;
  }

  _Sort? _sortOf(int newlineOffset) {
    final lines = parseDocumentLines(_controller.document);
    final lineIndex = lineIndexAt(lines, newlineOffset);
    if (lineIndex == -1 || !lines[lineIndex].isChecklist) return null;

    final (groupStart, groupEnd) = checklistGroupAround(lines, lineIndex);
    final order = checklistSortOrder(lines, groupStart, groupEnd, lineIndex);
    if (order == null) return null;
    return (
      lines: lines,
      lineIndex: lineIndex,
      groupStart: groupStart,
      order: order,
    );
  }

  void _sortToggledLine(int newlineOffset) {
    final sort = _sortOf(newlineOffset);
    if (sort == null) {
      _onSettled?.call();
      return;
    }
    final (:lines, :lineIndex, :groupStart, :order) = sort;

    final move = buildGroupReorderDelta(
      _controller.document,
      lines,
      groupStart,
      order,
    );
    int follow(int offset) {
      final index = lineIndexAt(lines, offset);
      final position = order.indexOf(index);
      if (position == -1 || index == lineIndex) return offset;
      var start = lines[groupStart].startOffset;
      for (final moved in order.take(position)) {
        start += lines[moved].length;
      }
      return start + offset - lines[index].startOffset;
    }

    final selection = _controller.selection;
    final kept = selection.copyWith(
      baseOffset: follow(selection.baseOffset),
      extentOffset: follow(selection.extentOffset),
    );
    final compose = _compose;
    if (compose != null) {
      compose(move, kept);
    } else {
      _controller
        ..compose(move, selection, ChangeSource.local)
        ..updateSelection(kept, ChangeSource.local);
    }
  }
}

typedef _Sort = ({
  List<ParsedLine> lines,
  int lineIndex,
  int groupStart,
  List<int> order,
});

class _PendingSort {
  _PendingSort(this.newline, {required this.lastRecorded, required this.steps});

  int newline;
  final int lastRecorded;
  final int steps;
  Timer? timer;
}
