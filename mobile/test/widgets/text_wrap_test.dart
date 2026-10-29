import 'package:anchor/core/widgets/balanced_text.dart';
import 'package:anchor/core/widgets/pretty_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The test font draws every letter and space 10 wide.
  const style = TextStyle(fontSize: 10, height: 1);

  Future<RenderParagraph> pumpText(WidgetTester tester, Widget text) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 120,
            child: Align(alignment: Alignment.topLeft, child: text),
          ),
        ),
      ),
    );
    return tester.renderObject<RenderParagraph>(find.byType(RichText));
  }

  int lineOf(RenderParagraph paragraph, int offset) =>
      paragraph
          .getBoxesForSelection(
            TextSelection(baseOffset: offset, extentOffset: offset + 1),
          )
          .single
          .top ~/
      10;

  testWidgets('balanced text keeps its lines and evens them out', (
    tester,
  ) async {
    final paragraph = await pumpText(
      tester,
      const BalancedText('aa bb cc dd ee', style: style),
    );

    expect(paragraph.size.height, 20);
    expect(paragraph.size.width, lessThan(90));
    expect(lineOf(paragraph, 9), 1, reason: 'dd moves down beside ee');
  });

  testWidgets('balanced text on one line stays as it is', (tester) async {
    final paragraph = await pumpText(
      tester,
      const BalancedText('aa bb', style: style),
    );

    expect(paragraph.size, const Size(50, 10));
  });

  testWidgets('pretty text moves a word down rather than leave one alone', (
    tester,
  ) async {
    final paragraph = await pumpText(
      tester,
      const PrettyText('aaa bbb ccc ddd', style: style),
    );

    expect(paragraph.size.height, 20);
    expect(lineOf(paragraph, 4), 0);
    expect(lineOf(paragraph, 8), 1, reason: 'ccc joins ddd');
  });

  testWidgets('pretty text keeps a one-word line when moving would add a '
      'line', (tester) async {
    final paragraph = await pumpText(
      tester,
      const PrettyText('aaaaaaaaaaa bbb', style: style),
    );

    expect(paragraph.size.height, 20);
    expect(lineOf(paragraph, 12), 1);
  });
}
