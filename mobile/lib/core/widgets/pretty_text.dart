import 'package:flutter/widgets.dart';

/// A [Text] that moves a word down rather than end on a line of one word,
/// when that keeps the number of lines.
class PrettyText extends StatelessWidget {
  const PrettyText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final plain = Text(
      text,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
    );
    if (maxLines == 1 || !text.trim().contains(' ')) return plain;
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(
            text: text,
            style: DefaultTextStyle.of(context).style.merge(style),
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: maxLines,
        )..layout(maxWidth: constraints.maxWidth);
        double? width;
        final lines = painter.computeLineMetrics();
        if (lines.length > 1 && _endsWithOneWord(painter)) {
          final narrower = lines[lines.length - 2].width - 0.5;
          painter.layout(maxWidth: narrower);
          if (painter.computeLineMetrics().length == lines.length &&
              !painter.didExceedMaxLines &&
              !_endsWithOneWord(painter)) {
            width = narrower;
          }
        }
        painter.dispose();
        return width == null ? plain : SizedBox(width: width, child: plain);
      },
    );
  }

  bool _endsWithOneWord(TextPainter painter) {
    final last = painter.getLineBoundary(
      TextPosition(offset: text.trimRight().length - 1),
    );
    return !text.substring(last.start, last.end).trim().contains(' ');
  }
}
