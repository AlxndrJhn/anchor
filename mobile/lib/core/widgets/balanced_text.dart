import 'package:flutter/widgets.dart';

/// A [Text] that breaks into lines of even length.
class BalancedText extends StatelessWidget {
  const BalancedText(this.text, {super.key, this.style, this.textAlign});

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: DefaultTextStyle.of(context).style.merge(style),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: constraints.maxWidth);
      final lines = painter.computeLineMetrics().length;
      var width = constraints.maxWidth;
      if (lines > 1) {
        var low = 0.0;
        while (width - low > 1) {
          final middle = (low + width) / 2;
          painter.layout(maxWidth: middle);
          if (painter.computeLineMetrics().length > lines) {
            low = middle;
          } else {
            width = middle;
          }
        }
      }
      painter.dispose();
      return SizedBox(
        width: lines > 1 ? width : null,
        child: Text(text, style: style, textAlign: textAlign),
      );
    },
  );
}
