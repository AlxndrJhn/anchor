import 'package:flutter/material.dart';

import '../../../../core/motion/haptics.dart';
import '../../../../core/motion/springs.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import 'card_registry.dart';

/// What is carried while a card is dragged: the note and its section, since
/// notes only move within their own (pinned or the others).
@immutable
class DraggedNote {
  const DraggedNote(this.id, this.group);

  final String id;
  final Object group;
}

/// A note card that can be held and dragged among the others, as in Google
/// Keep: it lifts off and follows the finger, its place stays open as a gap
/// ([isLifted]), and the list shows the new order before it is let go.
///
/// The list keeps the drag's state, not this card: the card may be rebuilt
/// elsewhere while the others make room, and the drag carries on.
class ReorderableNoteCard extends StatelessWidget {
  const ReorderableNoteCard({
    super.key,
    required this.noteId,
    required this.group,
    required this.isLifted,
    required this.onDragStarted,
    required this.onHover,
    required this.onDragEnded,
    required this.child,
  });

  final String noteId;
  final Object group;

  /// This is the card in hand; its place shows as a gap.
  final bool isLifted;

  /// Lifted, from [start] (global).
  final ValueChanged<Offset> onDragStarted;

  /// The dragged note is over this card.
  final ValueChanged<String> onHover;

  /// Let go with the lifted card at [end] (global).
  final ValueChanged<Offset> onDragEnded;

  final Widget child;

  bool _isOther(DraggedNote note) => note.group == group && note.id != noteId;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => DragTarget<DraggedNote>(
        // Nothing is dropped on a card: the order is already shown, and the
        // drag ends as "cancelled", which is reported even if this card has
        // been rebuilt elsewhere meanwhile.
        onWillAcceptWithDetails: (_) => false,
        onMove: (details) {
          if (_isOther(details.data)) onHover(details.data.id);
        },
        builder: (context, _, _) => LongPressDraggable<DraggedNote>(
          data: DraggedNote(noteId, group),
          delay: AnchorTokens.motionDurationLongPress,
          hapticFeedbackOnStart: false,
          onDragStarted: () {
            Haptics.light();
            final box = context.findRenderObject() as RenderBox?;
            onDragStarted(box?.localToGlobal(Offset.zero) ?? Offset.zero);
          },
          onDraggableCanceled: (_, offset) => onDragEnded(offset),
          feedback: _LiftedCard(noteId: noteId, width: constraints.maxWidth),
          child: IgnorePointer(
            ignoring: isLifted,
            child: Opacity(opacity: isLifted ? 0 : 1, child: child),
          ),
        ),
      ),
    );
  }
}

/// The card in hand, a little larger and tilted, above the list.
class _LiftedCard extends StatelessWidget {
  const _LiftedCard({required this.noteId, required this.width});

  final String noteId;
  final double width;

  @override
  Widget build(BuildContext context) {
    final isReduced = context.isMotionReduced;
    // The card's own content, without the key that marks its place.
    final content = CardRegistry.contentOf(noteId) ?? const SizedBox();
    return SizedBox(
      width: width,
      child: Transform.rotate(
        angle: isReduced ? 0 : 0.025,
        child: Transform.scale(
          scale: isReduced ? 1 : 1.04,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: context.appStyle.corners(AnchorTokens.radiusCard),
              boxShadow: context.anchor.shadowLift,
            ),
            child: Material(type: MaterialType.transparency, child: content),
          ),
        ),
      ),
    );
  }
}
