import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../motion/springs.dart';
import '../theme/app_typography.dart';
import '../theme/context_extensions.dart';
import '../theme/tokens/anchor_tokens.dart';
import 'cap_height_text.dart';
import 'pressable.dart';

IconData backIcon(BuildContext context) =>
    context.isCupertino ? LucideIcons.chevronLeft : LucideIcons.arrowLeft;

enum BarButtonSize {
  regular(AnchorTokens.sizeControlMedium, AnchorTokens.sizeIconLarge),
  medium(AnchorTokens.sizeControlMedium, AnchorTokens.sizeIconMedium),
  small(AnchorTokens.sizeControlSmall, AnchorTokens.sizeIconMedium);

  const BarButtonSize(this.box, this.icon);

  final double box;
  final double icon;
}

class BarButton extends StatelessWidget {
  const BarButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.color,
    this.size = BarButtonSize.regular,
    this.isOn,
    this.indicatorColor,
    this.pressStyle = PressStyle.barButton,
    this.hitPadding,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final BarButtonSize size;

  final PressStyle pressStyle;

  /// Non-null makes it a tool that turns on and off.
  final bool? isOn;

  final Color? indicatorColor;

  final EdgeInsets? hitPadding;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final enabled = onPressed != null;
    final on = isOn ?? false;
    return Pressable(
      style: pressStyle,
      onTap: onPressed,
      semanticLabel: label,
      toggled: isOn,
      hitPadding: hitPadding,
      child: AnimatedContainer(
        duration: context.motion(AnchorTokens.motionDurationHover),
        width: size.box,
        height: size.box,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: on ? colors.appText : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: enabled ? 1 : DisabledOpacity.icon,
              child: Icon(
                icon,
                size: size.icon,
                color: on ? colors.appPage : color ?? colors.appText,
              ),
            ),
            if (indicatorColor case final indicator?)
              Positioned(
                left: 14, // off-scale: as wide as the icon's middle
                right: 14, // off-scale: as above
                bottom: 8,
                child: AnimatedContainer(
                  duration: context.motion(AnchorTokens.motionDurationFade),
                  height: 3,
                  decoration: BoxDecoration(
                    color: indicator,
                    borderRadius: BorderRadius.circular(
                      AnchorTokens.radiusPill,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class BarTextButton extends StatelessWidget {
  const BarTextButton({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    return Pressable(
      style: PressStyle.barButton,
      onTap: onPressed,
      semanticLabel: label,
      child: Container(
        height: AnchorTokens.sizeControlMedium,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        child: CapHeightText(
          label,
          style: AppTypography.row.copyWith(
            fontWeight: FontWeight.w600,
            color: onPressed == null ? colors.appMuted : colors.appText,
          ),
        ),
      ),
    );
  }
}

enum AppButtonKind { primary, secondary, danger, dangerText }

enum AppButtonSize {
  regular,
  medium,
  small;

  double heightOf(BuildContext context) => switch (this) {
    regular => context.density.control,
    medium => AnchorTokens.sizeControlMedium,
    small => AnchorTokens.sizeControlSmall,
  };
}

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.kind = AppButtonKind.primary,
    this.icon,
    this.busyLabel,
    this.isBusy = false,
    this.isExpanded = true,
    this.size = AppButtonSize.regular,
    this.hasShadow = false,
    this.hitPadding,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonKind kind;
  final IconData? icon;

  final String? busyLabel;
  final bool isBusy;

  final bool isExpanded;
  final AppButtonSize size;

  final bool hasShadow;

  final EdgeInsets? hitPadding;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final (background, foreground) = switch (kind) {
      AppButtonKind.primary => (colors.appInverse, colors.appOnInverse),
      AppButtonKind.secondary => (
        colors.appText.withValues(alpha: 0.08),
        colors.appText,
      ),
      AppButtonKind.danger => (colors.statusDanger, colors.statusOnDanger),
      AppButtonKind.dangerText => (
        colors.appText.withValues(alpha: 0),
        colors.statusDanger,
      ),
    };
    final enabled = onPressed != null && !isBusy;
    final text = isBusy ? (busyLabel ?? label) : label;
    final small = size == AppButtonSize.small;
    final iconSize = small
        ? AnchorTokens.sizeIconSmall
        : AnchorTokens.sizeIconMedium;
    Widget content = Row(
      mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isBusy) ...[
          Spinner(size: iconSize, color: foreground),
          const SizedBox(width: 8),
        ] else if (icon != null) ...[
          Icon(icon, size: iconSize, color: foreground),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (small ? AppTypography.secondary : AppTypography.row)
                .copyWith(
                  fontWeight: FontWeight.w600,
                  color: foreground,
                  height: 1.2,
                ),
          ),
        ),
      ],
    );
    return Semantics(
      liveRegion: isBusy,
      child: Pressable(
        style: PressStyle.button,
        onTap: enabled ? onPressed : null,
        semanticLabel: text,
        hitPadding: hitPadding,
        child: AnimatedOpacity(
          opacity: enabled || isBusy ? 1 : DisabledOpacity.button,
          duration: context.motion(AnchorTokens.motionDurationFade),
          child: Container(
            height: size.heightOf(context),
            padding: EdgeInsets.symmetric(
              horizontal: small
                  ? 12
                  : size == AppButtonSize.medium ||
                        kind == AppButtonKind.dangerText
                  ? 16
                  : 24,
            ),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(AnchorTokens.radiusPill),
              boxShadow: hasShadow && enabled ? colors.shadowFab : null,
            ),
            child: ExcludeSemantics(child: content),
          ),
        ),
      ),
    );
  }
}

class Spinner extends StatefulWidget {
  const Spinner({
    super.key,
    this.size = AnchorTokens.sizeIconMedium,
    this.color,
  });

  final double size;
  final Color? color;

  @override
  State<Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<Spinner> with SingleTickerProviderStateMixin {
  late final AnimationController _rotation = AnimationController(
    vsync: this,
    duration: AnchorTokens.motionDurationSpin,
  )..repeat();

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _rotation,
      child: Icon(
        LucideIcons.loaderCircle,
        size: widget.size,
        color: widget.color ?? context.anchor.appMuted,
      ),
    );
  }
}
