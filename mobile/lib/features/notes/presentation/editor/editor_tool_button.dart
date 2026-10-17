import 'package:flutter/material.dart';

import '../../../../core/motion/pop_in.dart';
import '../../../../core/motion/springs.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../core/widgets/pressable.dart';

class EditorToolButton extends StatefulWidget {
  const EditorToolButton({
    super.key,
    required this.label,
    this.icon,
    this.swatch,
    this.highlightColor,
    this.isOn,
    this.isDisabled = false,
    required this.width,
    required this.onPressed,
    this.popsIn = false,
  });

  final String label;
  final IconData? icon;

  final ({Color fill, Color ink})? swatch;

  final Color? highlightColor;

  /// Null for a tool that acts rather than turns on.
  final bool? isOn;

  final bool isDisabled;

  final double width;
  final VoidCallback onPressed;

  /// Read once.
  final bool popsIn;

  @override
  State<EditorToolButton> createState() => _EditorToolButtonState();
}

class _EditorToolButtonState extends State<EditorToolButton> {
  late final bool _popsIn = widget.popsIn;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final on = widget.isOn ?? false;
    final swatch = widget.swatch;
    final highlightColor = widget.highlightColor;
    Widget content = SizedBox(
      width: widget.width,
      height: AnchorTokens.sizeControlMedium,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(
                AnchorTokens.space2, // off-scale: chips side by side apart
              ),
              child: AnimatedOpacity(
                opacity: on ? 1 : 0,
                duration: context.motion(AnchorTokens.motionDurationHover),
                child: AnimatedScale(
                  scale: on ? 1 : 0.85,
                  duration: context.motion(Spring.snappy.duration),
                  curve: Spring.snappy.curve,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.appSurface,
                      boxShadow: colors.shadowXs,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (swatch != null)
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.skewX(-0.2443), // off-scale: 14 degrees
              child: Container(
                width: AnchorTokens.sizeIconLarge,
                height: AnchorTokens.sizeIconSmall,
                decoration: BoxDecoration(
                  color: swatch.fill,
                  borderRadius: BorderRadius.circular(3), // off-scale: drawing
                  border: Border.all(color: swatch.ink, width: 1.5),
                ),
              ),
            )
          else
            Icon(
              widget.icon,
              size: AnchorTokens.sizeIconLarge,
              color: on ? colors.accentStrong : colors.appText,
            ),
          if (highlightColor != null)
            Positioned(
              left: 14, // off-scale: under the icon's middle
              right: 14, // off-scale: as above
              bottom: 8,
              child: AnimatedContainer(
                duration: context.motion(AnchorTokens.motionDurationFade),
                height: 3, // off-scale: drawing
                decoration: BoxDecoration(
                  color: highlightColor,
                  borderRadius: BorderRadius.circular(AnchorTokens.radiusPill),
                ),
              ),
            ),
        ],
      ),
    );
    content = AnimatedOpacity(
      opacity: widget.isDisabled ? DisabledOpacity.icon : 1,
      duration: context.motion(AnchorTokens.motionDurationFade),
      child: content,
    );
    if (_popsIn) content = PopIn(from: 0.8, child: content);
    return Pressable(
      style: PressStyle.toolbar,
      onTap: widget.isDisabled ? null : widget.onPressed,
      semanticLabel: widget.label,
      toggled: widget.isOn,
      child: content,
    );
  }
}
