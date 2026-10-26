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

/// A note card that can be held and dragged among the others, as in Google
/// Keep: it lifts off and follows the finger, its place stays open as a gap,
/// and the list shows the new order before it is let go. Holding it without
/// moving selects it.
class ReorderableNoteCard extends StatefulWidget {
  const ReorderableNoteCard({
    super.key,
    required this.noteId,
    required this.group,
    required this.onDragStarted,
    required this.onHover,
    required this.onDragEnded,
    required this.onHeld,
    required this.child,
  });

  final String noteId;
  final String group;
  final VoidCallback onDragStarted;

  /// The dragged note is over this card.
  final ValueChanged<String> onHover;
  final VoidCallback onDragEnded;

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
    final radius = context.styleTokens.cardRadius;
    return LayoutBuilder(
      builder: (context, constraints) => DragTarget<DraggedNote>(
        onWillAcceptWithDetails: (details) =>
            details.data.group == widget.group &&
            details.data.id != widget.noteId,
        onMove: (details) {
          if (details.data.group == widget.group &&
              details.data.id != widget.noteId) {
            widget.onHover(details.data.id);
          }
        },
        builder: (context, _, _) => LongPressDraggable<DraggedNote>(
          data: DraggedNote(widget.noteId, widget.group),
          hapticFeedbackOnStart: true,
          onDragStarted: () {
            _moved = 0;
            widget.onDragStarted();
          },
          onDragUpdate: (details) => _moved += details.delta.distance,
          onDragEnd: (_) {
            if (_moved < _holdSlop) widget.onHeld();
            widget.onDragEnded();
          },
          // Lifted off the list, a little larger and tilted.
          feedback: SizedBox(
            width: constraints.maxWidth,
            child: Transform.rotate(
              angle: 0.025,
              child: Transform.scale(
                scale: 1.04,
                child: Material(
                  color: Colors.transparent,
                  elevation: 12,
                  borderRadius: radius,
                  child: widget.child,
                ),
              ),
            ),
          ),
          // Its place stays open while it is away.
          childWhenDragging: Opacity(opacity: 0, child: widget.child),
          child: widget.child,
        ),
      ),
    );
  }
}
