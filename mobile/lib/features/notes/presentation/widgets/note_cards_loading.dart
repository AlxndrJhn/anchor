import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/motion/springs.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../core/widgets/shimmer.dart';
import '../../../../l10n/l10n.dart';
import 'card_body.dart';

class NoteCardsLoading extends StatefulWidget {
  const NoteCardsLoading({super.key, required this.layout});

  /// Nothing shows for loads quicker than this.
  static const Duration holdBack = Duration(milliseconds: 300);

  final CardLayout layout;

  @override
  State<NoteCardsLoading> createState() => _NoteCardsLoadingState();
}

class _NoteCardsLoadingState extends State<NoteCardsLoading> {
  static const _masonry = ([5, 2, 4, 2], [3, 4, 3, 5]);
  static const _grid = [4, 3, 4, 3];
  static const _list = [2, 2, 2, 2, 2, 2, 2];

  late final Timer _reveal;
  bool _isShown = false;

  @override
  void initState() {
    super.initState();
    _reveal = Timer(NoteCardsLoading.holdBack, () {
      if (mounted) setState(() => _isShown = true);
    });
  }

  @override
  void dispose() {
    _reveal.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final density = context.density;
    final gap = density.space12;
    Widget column(List<int> lines) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: gap,
      children: [for (final count in lines) _CardShape(lines: count)],
    );

    final cards = switch (widget.layout) {
      CardLayout.masonry => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: gap,
        children: [
          Expanded(child: column(_masonry.$1)),
          Expanded(child: column(_masonry.$2)),
        ],
      ),
      CardLayout.grid => Column(
        spacing: gap,
        children: [
          for (final count in _grid)
            Row(
              spacing: gap,
              children: [
                Expanded(child: _CardShape(lines: count)),
                Expanded(child: _CardShape(lines: count)),
              ],
            ),
        ],
      ),
      CardLayout.list => column(_list),
    };

    return Semantics(
      container: true,
      label: context.l10n.notesLoading,
      child: ExcludeSemantics(
        child: AnimatedOpacity(
          opacity: _isShown ? 1 : 0,
          duration: context.motion(AnchorTokens.motionDurationFade),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, density.space8, 16, 0),
            child: cards,
          ),
        ),
      ),
    );
  }
}

class _CardShape extends StatelessWidget {
  const _CardShape({required this.lines});

  final int lines;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final density = context.density;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.appSurface,
        borderRadius: BorderRadius.circular(AnchorTokens.radiusCard),
        border: Border.all(color: colors.appBorder.withValues(alpha: 0.6)),
        boxShadow: colors.shadowXs,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: density.space12,
        ),
        child: Shimmer(
          color: colors.appSubtle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: density.space8,
            children: [
              const FractionallySizedBox(
                widthFactor: 0.62,
                child: _Bar(height: _Bar.title),
              ),
              for (var i = 0; i < lines; i++) const _Bar(height: _Bar.text),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.height});

  static const double title = 14; // off-scale: a title line's shape
  static const double text = 10; // off-scale: a text line's shape

  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: height,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF000000),
        borderRadius: BorderRadius.circular(height / 2),
      ),
    ),
  );
}
