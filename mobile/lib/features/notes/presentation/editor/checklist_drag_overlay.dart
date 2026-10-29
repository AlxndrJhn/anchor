import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/motion/springs.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../l10n/l10n.dart';
import 'checklist_drag_controller.dart';

class ChecklistDragOverlay extends StatelessWidget {
  const ChecklistDragOverlay({super.key, required this.drag});

  final ChecklistDragController drag;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: drag,
      builder: (context, _) {
        final y = drag.isDragging ? drag.indicatorY : null;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            if (y != null)
              _DropLine(
                key: const Key('checklist-drag-indicator'),
                y: y,
                left: drag.indicatorLeft,
              ),
          ],
        );
      },
    );
  }
}

class _DropLine extends StatelessWidget {
  const _DropLine({super.key, required this.y, required this.left});

  final double y;
  final double left;

  static const double _dot = 8;
  static const double _dotRadius = _dot / 2; // off-scale: half the dot

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    return AnimatedPositioned(
      duration: context.motion(AnchorTokens.motionDurationPress),
      curve: AnchorTokens.motionEaseStandard,
      left: left - _dotRadius,
      right: 0,
      top: y - _dotRadius,
      height: _dot,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Positioned(
            left: _dotRadius,
            right: 0,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                color: colors.accentStrong,
                borderRadius: BorderRadius.circular(
                  1,
                ), // off-scale: drop line drawing
              ),
            ),
          ),
          Container(
            width: _dot,
            height: _dot,
            decoration: BoxDecoration(
              color: colors.accentStrong,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class ChecklistDragGhost extends StatelessWidget {
  const ChecklistDragGhost({super.key, required this.drag});

  final ChecklistDragController drag;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: drag,
      builder: (context, _) {
        final finger = drag.finger;
        final overlay = Overlay.maybeOf(context)?.context.findRenderObject();
        if (finger == null || overlay is! RenderBox || !overlay.hasSize) {
          return const SizedBox.shrink();
        }
        return IgnorePointer(
          child: ExcludeSemantics(
            child: CustomSingleChildLayout(
              delegate: _GhostPositionDelegate(overlay.globalToLocal(finger)),
              child: _Ghost(
                key: const Key('checklist-drag-ghost'),
                text: drag.text,
                isChecked: drag.isChecked,
                childCount: drag.childCount,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GhostPositionDelegate extends SingleChildLayoutDelegate {
  _GhostPositionDelegate(this.finger);

  final Offset finger;

  static const double _side = AnchorTokens.space8;
  static const double _left = AnchorTokens.space24;
  static const double _aboveFinger = 56; // off-scale: above the finger

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) => Offset(
    (finger.dx - _left).clamp(
      _side,
      math.max(_side, size.width - _side - childSize.width),
    ),
    finger.dy - _aboveFinger,
  );

  @override
  bool shouldRelayout(_GhostPositionDelegate old) => old.finger != finger;
}

class _Ghost extends StatelessWidget {
  const _Ghost({
    super.key,
    required this.text,
    required this.isChecked,
    required this.childCount,
  });

  final String text;
  final bool isChecked;
  final int childCount;

  static const double _maxWidth = 240; // off-scale: the drag ghost
  static const double _boxRadius = 5; // off-scale: the ghost's box

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final style = AppTypography.secondary.copyWith(
      color: colors.appText,
      height: 1,
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _maxWidth),
      child: Container(
        height: AnchorTokens.sizeControlSmall,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: colors.appSurface,
          borderRadius: BorderRadius.circular(AnchorTokens.radiusPill),
          boxShadow: colors.shadowMenu,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            Container(
              width: AnchorTokens.sizeIconSmall,
              height: AnchorTokens.sizeIconSmall,
              decoration: BoxDecoration(
                color: isChecked ? colors.accentStrong : null,
                borderRadius: BorderRadius.circular(_boxRadius),
                border: isChecked
                    ? null
                    : Border.all(color: colors.appMuted, width: 1.5),
              ),
            ),
            Flexible(
              child: Text(
                text.isEmpty ? context.l10n.editorEmptyItem : text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
            if (childCount > 0)
              Text(
                '+$childCount',
                style: style.copyWith(
                  color: colors.appMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
