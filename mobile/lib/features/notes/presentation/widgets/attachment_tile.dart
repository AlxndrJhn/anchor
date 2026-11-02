import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../core/widgets/pressable.dart';
import 'note_surface.dart';

class AttachmentTile extends StatelessWidget {
  const AttachmentTile({
    super.key,
    required this.width,
    required this.appearance,
    required this.deleteLabel,
    required this.onDelete,
    required this.child,
    this.growsWithText = false,
  });

  static const double height = 96; // off-scale: a picture tile

  /// [height], taller by as much as a name and the line under it grow with
  /// large text, so a recording's or a file's words stay whole.
  static double heightOf(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    double growth(double size) => (scaler.scale(size) - size) * 1.4;
    // off-scale: the name's and the line's sizes
    return height + math.max(0.0, growth(13.5) + growth(12)).ceilToDouble();
  }

  final double width;
  final NoteAppearance appearance;
  final String deleteLabel;
  final VoidCallback? onDelete;
  final Widget child;

  /// A recording or a file, whose words grow with large text.
  final bool growsWithText;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: growsWithText ? heightOf(context) : height,
      child: Stack(
        children: [
          Positioned.fill(child: child),
          if (onDelete != null)
            Positioned(
              top: 4,
              right: 4,
              child: _RemoveButton(
                label: deleteLabel,
                appearance: appearance,
                onTap: onDelete!,
              ),
            ),
        ],
      ),
    );
  }
}

class _RemoveButton extends StatelessWidget {
  const _RemoveButton({
    required this.label,
    required this.appearance,
    required this.onTap,
  });

  final String label;
  final NoteAppearance appearance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    return Pressable(
      style: PressStyle.plain,
      onTap: onTap,
      semanticLabel: label,
      minSize: const Size.square(AnchorTokens.sizeControlMedium),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: appearance.colors.surface.withValues(alpha: 0.92),
          shape: BoxShape.circle,
          boxShadow: colors.shadowKnob,
        ),
        child: Icon(
          LucideIcons.x,
          size: 12, // off-scale: remove mark on a tile
          color: colors.appText,
        ),
      ),
    );
  }
}
