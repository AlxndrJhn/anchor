import 'dart:math' as math;

import 'package:anchor/core/files/image_text.dart';
import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/features/notes/presentation/widgets/image_text_view.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A 1 × 1 transparent PNG: the picture itself doesn't matter here.
final _pixel = Uint8List.fromList([
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

const _imageSize = Size(1000, 600);

ImageWord _word(String text, double left, double top, int line, int block) =>
    ImageWord(
      text: text,
      rect: Rect.fromLTWH(left, top, 180, 50),
      line: line,
      block: block,
    );

final _text = ImageText([
  _word('Shopping', 50, 50, 0, 0),
  _word('list', 250, 50, 0, 0),
  _word('Milk', 50, 200, 1, 1),
  _word('and', 250, 200, 1, 1),
  _word('bread', 450, 200, 1, 1),
  _word('Call', 50, 350, 2, 1),
]);

void main() {
  String? copied;
  String? inserted;

  setUp(() {
    copied = null;
    inserted = null;
  });

  Future<void> pumpView(WidgetTester tester, {bool canInsert = true}) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ImageTextView(
          image: MemoryImage(_pixel),
          imageSize: _imageSize,
          text: _text,
          onInsert: canInsert ? (text) => inserted = text : null,
        ),
      ),
    );
  }

  /// Where a point of the picture is on the screen.
  Offset onScreen(WidgetTester tester, Offset point) {
    final area = tester.getRect(find.byKey(const ValueKey('image-text-area')));
    final scale = math.min(
      area.width / _imageSize.width,
      area.height / _imageSize.height,
    );
    final offset = Offset(
      (area.width - _imageSize.width * scale) / 2,
      (area.height - _imageSize.height * scale) / 2,
    );
    return area.topLeft + offset + point * scale;
  }

  Offset wordCentre(WidgetTester tester, int index) =>
      onScreen(tester, _text.words[index].rect.center);

  Future<void> holdAndDrag(WidgetTester tester, int from, int to) async {
    final gesture = await tester.startGesture(
      wordCentre(tester, from),
      kind: PointerDeviceKind.touch,
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.moveTo(wordCentre(tester, to));
    await tester.pump();
    await gesture.up();
    await tester.pump();
  }

  testWidgets('nothing is chosen at first, so there is nothing to copy', (
    tester,
  ) async {
    await pumpView(tester);

    expect(find.text('Select text'), findsOneWidget);
    expect(
      find.textContaining('hold beside it and drag a box'),
      findsOneWidget,
    );
    await tester.tap(find.bySemanticsLabel('Copy'));
    await tester.pump();
    expect(copied, isNull);
  });

  testWidgets('holding a word and dragging selects the words between', (
    tester,
  ) async {
    await pumpView(tester);

    await holdAndDrag(tester, 1, 4);
    expect(find.text('4 words selected'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Copy'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(copied, 'list\n\nMilk and bread');
    expect(
      find.textContaining('Text copied', findRichText: true),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('dragging backwards selects the same way', (tester) async {
    await pumpView(tester);

    await holdAndDrag(tester, 5, 3);
    await tester.tap(find.bySemanticsLabel('Copy'));
    await tester.pump();

    expect(copied, 'and bread\nCall');
    await tester.pump(const Duration(seconds: 11));
  });

  Future<void> holdAndDrawBox(
    WidgetTester tester,
    Offset from,
    Offset to,
  ) async {
    final gesture = await tester.startGesture(
      onScreen(tester, from),
      kind: PointerDeviceKind.touch,
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.moveTo(onScreen(tester, (from + to) / 2));
    await tester.pump();
    await gesture.moveTo(onScreen(tester, to));
    await tester.pump();
    await gesture.up();
    await tester.pump();
  }

  testWidgets('holding beside the text and dragging boxes in words', (
    tester,
  ) async {
    await pumpView(tester);

    await holdAndDrawBox(tester, const Offset(20, 20), const Offset(440, 260));
    expect(find.text('4 words selected'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Copy'));
    await tester.pump();
    expect(copied, 'Shopping list\nMilk and');
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('a box down one side picks words from several lines', (
    tester,
  ) async {
    await pumpView(tester);

    await holdAndDrawBox(tester, const Offset(20, 20), const Offset(240, 420));
    await tester.tap(find.bySemanticsLabel('Copy'));
    await tester.pump();

    expect(copied, 'Shopping\nMilk\nCall');
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('the hint fades over the picture without moving it', (
    tester,
  ) async {
    await pumpView(tester);
    final area = find.byKey(const ValueKey('image-text-area'));
    final before = tester.getRect(area);
    double hintOpacity() => tester
        .widget<AnimatedOpacity>(
          find.ancestor(
            of: find.textContaining('drag a box'),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity;
    expect(hintOpacity(), 1);

    await holdAndDrawBox(tester, const Offset(20, 20), const Offset(440, 260));
    await tester.pumpAndSettle();

    expect(hintOpacity(), 0);
    expect(tester.getRect(area), before);
  });

  testWidgets('a boxed selection can go into the note', (tester) async {
    await pumpView(tester);

    await holdAndDrawBox(tester, const Offset(20, 20), const Offset(440, 260));
    await tester.tap(find.bySemanticsLabel('Insert in note'));
    await tester.pump();

    expect(inserted, 'Shopping list\nMilk and');
  });

  testWidgets('a tap picks one word, and a tap beside the text clears it', (
    tester,
  ) async {
    await pumpView(tester);

    await tester.tapAt(wordCentre(tester, 2));
    await tester.pump();
    expect(find.text('1 word selected'), findsOneWidget);

    await tester.tapAt(onScreen(tester, const Offset(900, 550)));
    await tester.pump();
    expect(find.text('Select text'), findsOneWidget);
  });

  testWidgets('Select all, then Insert in note, gives the note all the text', (
    tester,
  ) async {
    await pumpView(tester);

    await tester.tap(find.bySemanticsLabel('Select all'));
    await tester.pump();
    expect(find.text('6 words selected'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Insert in note'));
    await tester.pump();
    expect(inserted, 'Shopping list\n\nMilk and bread\nCall');
  });

  testWidgets('a note that can\'t be edited offers copying only', (
    tester,
  ) async {
    await pumpView(tester, canInsert: false);

    expect(find.bySemanticsLabel('Insert in note'), findsNothing);
    expect(find.bySemanticsLabel('Copy'), findsOneWidget);
  });
}
