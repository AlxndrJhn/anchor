import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/context_extensions.dart';
import '../theme/tokens/anchor_tokens.dart';
import 'page_settled.dart';

ui.ImageFilter frostedGlassFilter(double sigma) => ui.ImageFilter.compose(
  outer: const ColorFilter.matrix(_saturationMatrix),
  inner: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
);

const List<double> _saturationMatrix = [
  1.4927, -0.4573, -0.0354, 0, 0, //
  -0.1503, 1.1997, -0.0494, 0, 0, //
  -0.1503, -0.4573, 1.6076, 0, 0, //
  0, 0, 0, 1, 0,
];

class FrostedGlass extends StatelessWidget {
  const FrostedGlass({super.key, required this.child, this.color});

  final Widget child;

  final Color? color;

  static const BorderRadius _borderRadius = BorderRadius.all(
    Radius.circular(AnchorTokens.radiusPill),
  );

  static final ui.ImageFilter _filter = frostedGlassFilter(22);

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final dark = context.isDark;
    final base = color ?? colors.appSurface;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: _borderRadius,
        boxShadow: dark
            ? const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 28,
                  offset: Offset(0, 10),
                ),
              ]
            : colors.shadowFloating,
      ),
      child: PageSettledBuilder(
        builder: (context, blur) => ClipRRect(
          borderRadius: _borderRadius,
          child: BackdropFilter.grouped(
            enabled: blur,
            filter: _filter,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: _borderRadius,
                color: base.withValues(alpha: blur ? (dark ? 0.78 : 0.74) : 1),
                border: Border.all(
                  color: dark
                      ? const Color(0x14FFFFFF)
                      : const Color(0x0F000000),
                  width: 0.5,
                ),
              ),
              position: DecorationPosition.background,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: _borderRadius,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, 0.06],
                    colors: [
                      Colors.white.withValues(alpha: dark ? 0.06 : 0.45),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
