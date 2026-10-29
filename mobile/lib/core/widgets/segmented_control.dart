import 'package:flutter/material.dart';

import '../motion/haptics.dart';
import '../motion/springs.dart';
import '../theme/app_typography.dart';
import '../theme/context_extensions.dart';
import '../theme/tokens/anchor_tokens.dart';
import 'pressable.dart';

class Segment<T> {
  const Segment({
    required this.value,
    required this.label,
    this.icon,
    this.fontFamily,
  });

  final T value;
  final String label;
  final IconData? icon;

  final String? fontFamily;
}

class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
  });

  final List<Segment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final index = segments.indexWhere((s) => s.value == value);
    const height = AnchorTokens.sizeControlMedium - 8;
    return Semantics(
      label: semanticLabel,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: colors.appText.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(AnchorTokens.radius2xl),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width =
                (constraints.maxWidth - 4 * (segments.length - 1)) /
                segments.length;
            return SizedBox(
              height: height,
              child: Stack(
                children: [
                  if (index >= 0)
                    AnimatedPositioned(
                      duration: context.motion(Spring.snappy.duration),
                      curve: Spring.snappy.curve,
                      left: index * (width + 4),
                      top: 0,
                      bottom: 0,
                      width: width,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.appText,
                          borderRadius: BorderRadius.circular(
                            AnchorTokens.radiusLg,
                          ),
                          boxShadow: colors.shadowXs,
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      for (var i = 0; i < segments.length; i++) ...[
                        if (i > 0) const SizedBox(width: 4),
                        Expanded(
                          child: Pressable(
                            style: PressStyle.button,
                            selected: i == index,
                            semanticLabel: segments[i].label,
                            onTap: () {
                              if (segments[i].value == value) return;
                              Haptics.selection();
                              onChanged(segments[i].value);
                            },
                            child: _Label(
                              segment: segments[i],
                              isSelected: i == index,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.segment, required this.isSelected});

  final Segment<dynamic> segment;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final color = isSelected ? colors.appSurface : colors.appMuted;
    final style = AppTypography.secondary.copyWith(
      fontFamily: segment.fontFamily,
      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
      color: color,
      height: 1.2,
    );
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (segment.icon != null) ...[
            Icon(segment.icon, size: AnchorTokens.sizeIconSmall, color: color),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: AnimatedDefaultTextStyle(
              duration: context.motion(AnchorTokens.motionDurationFade),
              style: style,
              child: Text(
                segment.label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
