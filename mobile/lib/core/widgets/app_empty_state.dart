import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_typography.dart';
import '../theme/context_extensions.dart';
import '../theme/tokens/anchor_tokens.dart';

enum EmptyStateKind { notes, search, archive, trash, history, loadFailed }

class EmptyStateIllustration extends StatelessWidget {
  const EmptyStateIllustration({super.key, this.kind = EmptyStateKind.notes});

  final EmptyStateKind kind;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    return ExcludeSemantics(
      child: CustomPaint(
        size: const Size(132, 96),
        painter: _IllustrationPainter(
          kind: kind,
          yellow: colors.notes['yellow']!,
          blue: colors.notes['blue']!,
          surface: colors.appSurface,
          border: colors.appBorder,
          muted: colors.appMuted,
        ),
      ),
    );
  }
}

class _IllustrationPainter extends CustomPainter {
  _IllustrationPainter({
    required this.kind,
    required this.yellow,
    required this.blue,
    required this.surface,
    required this.border,
    required this.muted,
  });

  final EmptyStateKind kind;
  final AnchorNoteColors yellow;
  final AnchorNoteColors blue;
  final Color surface;
  final Color border;
  final Color muted;

  void _note(
    Canvas canvas,
    Rect rect,
    double radius,
    double degrees,
    Offset around,
    AnchorNoteColors colors,
  ) {
    canvas
      ..save()
      ..translate(around.dx, around.dy)
      ..rotate(degrees * math.pi / 180)
      ..translate(-around.dx, -around.dy);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas
      ..drawRRect(rrect, Paint()..color = colors.bg)
      ..drawRRect(
        rrect.deflate(0.5),
        Paint()
          ..color = colors.border
          ..style = PaintingStyle.stroke,
      )
      ..restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 132, size.height / 96);
    _note(
      canvas,
      const Rect.fromLTWH(14, 20, 52, 62),
      10,
      -9,
      const Offset(40, 51),
      yellow,
    );
    _note(
      canvas,
      const Rect.fromLTWH(72, 16, 50, 60),
      10,
      8,
      const Offset(97, 46),
      blue,
    );
    final front = RRect.fromRectAndRadius(
      const Rect.fromLTWH(44, 26, 56, 64),
      const Radius.circular(11),
    );
    canvas
      ..drawRRect(front, Paint()..color = surface)
      ..drawRRect(
        front.deflate(0.5),
        Paint()
          ..color = border
          ..style = PaintingStyle.stroke,
      );
    final band = Path()
      ..moveTo(44, 37)
      ..arcToPoint(const Offset(55, 26), radius: const Radius.circular(11))
      ..lineTo(89, 26)
      ..arcToPoint(const Offset(100, 37), radius: const Radius.circular(11))
      ..lineTo(100, 39)
      ..lineTo(44, 39)
      ..close();
    canvas.drawPath(band, Paint()..color = AnchorTokens.colorAccentFill);

    final pen = Paint()
      ..color = muted
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (kind) {
      case EmptyStateKind.notes:
        pen.strokeWidth = 2.4;
        canvas
          ..drawLine(const Offset(58, 44), const Offset(84, 44), pen)
          ..drawLine(const Offset(58, 52), const Offset(78, 52), pen)
          ..drawLine(const Offset(58, 60), const Offset(82, 60), pen);
      case EmptyStateKind.search:
        pen.strokeWidth = 2.4;
        canvas
          ..drawCircle(const Offset(72, 54), 9, pen)
          ..drawLine(const Offset(79, 61), const Offset(85, 67), pen);
      case EmptyStateKind.archive:
        canvas
          ..drawRect(const Rect.fromLTWH(60, 46, 24, 6), pen)
          ..drawRect(const Rect.fromLTWH(62, 52, 20, 14), pen)
          ..drawLine(const Offset(69, 57), const Offset(75, 57), pen);
      case EmptyStateKind.trash:
        canvas.drawPath(
          Path()
            ..moveTo(61, 47)
            ..lineTo(83, 47)
            ..moveTo(68, 47)
            ..lineTo(68, 44)
            ..lineTo(76, 44)
            ..lineTo(76, 47)
            ..moveTo(63, 47)
            ..lineTo(64.5, 66)
            ..lineTo(79.5, 66)
            ..lineTo(81, 47),
          pen,
        );
      case EmptyStateKind.history:
        canvas.drawPath(
          Path()
            ..moveTo(63.5, 50.5)
            ..arcToPoint(
              const Offset(62, 56),
              radius: const Radius.circular(10),
              largeArc: true,
            )
            ..moveTo(62, 46)
            ..lineTo(62, 51)
            ..lineTo(67, 51)
            ..moveTo(72, 51)
            ..lineTo(72, 57)
            ..lineTo(76, 59.5),
          pen,
        );
      case EmptyStateKind.loadFailed:
        Offset at(double x, double y) =>
            Offset(72 + (x - 12) * 1.3, 57 + (y - 12) * 1.3);
        canvas
          ..drawPath(
            Path()
              ..moveTo(at(17.5, 19).dx, at(17.5, 19).dy)
              ..lineTo(at(9, 19).dx, at(9, 19).dy)
              ..arcToPoint(
                at(15.71, 10),
                radius: const Radius.circular(7 * 1.3),
                largeArc: true,
              )
              ..lineTo(at(17.5, 10).dx, at(17.5, 10).dy)
              ..arcToPoint(
                at(17.5, 19),
                radius: const Radius.circular(4.5 * 1.3),
              )
              ..close(),
            pen,
          )
          ..drawLine(at(12, 9.5), at(12, 13.5), pen)
          ..drawCircle(at(12, 16.3), 1.3, Paint()..color = muted);
    }
  }

  @override
  bool shouldRepaint(_IllustrationPainter old) =>
      old.kind != kind || old.surface != surface || old.yellow.bg != yellow.bg;
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.kind = EmptyStateKind.notes,
    this.action,
    this.padding,
  });

  final String title;
  final String message;
  final EmptyStateKind kind;
  final Widget? action;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final density = context.density;
    return Padding(
      padding:
          padding ??
          EdgeInsets.fromLTRB(24, density.space48, 24, density.space24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 380, // off-scale: keeps the lines short
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EmptyStateIllustration(kind: kind),
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTypography.sheetTitle.copyWith(
                    color: colors.appText,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.secondary.copyWith(color: colors.appMuted),
              ),
              if (action != null) ...[const SizedBox(height: 24), action!],
            ],
          ),
        ),
      ),
    );
  }
}

class SliverAppEmptyState extends StatelessWidget {
  const SliverAppEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.kind = EmptyStateKind.notes,
    this.action,
  });

  final String title;
  final String message;
  final EmptyStateKind kind;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: AppEmptyState(
        title: title,
        message: message,
        kind: kind,
        action: action,
      ),
    );
  }
}
