import 'package:flutter/material.dart';

import '../../../../core/theme/context_extensions.dart';

/// What is carried while a card is dragged: the note and its section, since
/// notes only move within their own (pinned or the others).
@immutable
class DraggedNote {
  const DraggedNote(this.id, this.group);

  final String id;
  final String group;
}

/// A note card that can be held and dragged onto another card of its section
/// to take that card's place ("Custom" sort), as in Google Keep. Holding it
/// without moving selects it, as a long press does elsewhere.
class ReorderableNoteCard extends StatefulWidget {
  const ReorderableNoteCard({
    super.key,
    required this.noteId,
    required this.group,
    required this.onDropped,
    required this.onHeld,
    required this.child,
  });

  final String noteId;
  final String group;

  /// The note with this id was dropped on this card.
  final ValueChanged<String> onDropped;

  /// Held without being moved.
  final VoidCallback onHeld;
  final Widget child;

  @override
  State<ReorderableNoteCard> createState() => _ReorderableNoteCardState();
}

class _ReorderableNoteCardState extends State<ReorderableNoteCard> {
  /// How far the card travelled, to tell a hold from a drag.
  double _moved = 0;

  static const double _holdSlop = 12;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = context.styleTokens.cardRadius;
    return LayoutBuilder(
      builder: (context, constraints) => DragTarget<DraggedNote>(
        onWillAcceptWithDetails: (details) =>
            details.data.id != widget.noteId &&
            details.data.group == widget.group,
        onAcceptWithDetails: (details) => widget.onDropped(details.data.id),
        builder: (context, candidates, _) => LongPressDraggable<DraggedNote>(
          data: DraggedNote(widget.noteId, widget.group),
          hapticFeedbackOnStart: true,
          onDragStarted: () => _moved = 0,
          onDragUpdate: (details) => _moved += details.delta.distance,
          onDraggableCanceled: (_, _) {
            if (_moved < _holdSlop) widget.onHeld();
          },
          feedback: SizedBox(
            width: constraints.maxWidth,
            child: Material(
              color: Colors.transparent,
              elevation: 8,
              borderRadius: radius,
              child: Opacity(opacity: 0.92, child: widget.child),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.3, child: widget.child),
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: candidates.isEmpty
                  ? null
                  : Border.all(color: theme.colorScheme.tertiary, width: 3),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
