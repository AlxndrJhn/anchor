import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import '../../l10n/l10n.dart';

/// Screen reader actions for something that is otherwise dragged into a new
/// place: Move up, Move down, Move to top and Move to bottom, for each one
/// given.
Map<CustomSemanticsAction, VoidCallback> moveActions(
  BuildContext context, {
  VoidCallback? up,
  VoidCallback? down,
  VoidCallback? top,
  VoidCallback? bottom,
}) {
  final l10n = context.l10n;
  return {
    CustomSemanticsAction(label: l10n.commonMoveUp): ?up,
    CustomSemanticsAction(label: l10n.commonMoveDown): ?down,
    CustomSemanticsAction(label: l10n.commonMoveToTop): ?top,
    CustomSemanticsAction(label: l10n.commonMoveToBottom): ?bottom,
  };
}

/// [moveActions] for the item at [index] of [count], which [onMove] puts at
/// its new index. To top and to bottom only show when they go further than
/// up and down.
Map<CustomSemanticsAction, VoidCallback> indexMoveActions(
  BuildContext context, {
  required int index,
  required int count,
  required ValueChanged<int> onMove,
}) => moveActions(
  context,
  up: index > 0 ? () => onMove(index - 1) : null,
  down: index < count - 1 ? () => onMove(index + 1) : null,
  top: index > 1 ? () => onMove(0) : null,
  bottom: index < count - 2 ? () => onMove(count - 1) : null,
);
