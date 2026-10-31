import 'dart:typed_data';

import 'package:anchor/features/debug_recorder/data/debug_censor.dart';
import 'package:anchor/features/debug_recorder/data/debug_privacy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('keepShape', () {
    test('keeps names, numbers, flags, enums and ids', () {
      expect(
        keepShape(
          'Auth(status: AuthStatus.ready, id: '
          '0b6f6a52-6c1e-4f53-a0f4-2f9c3b1d7e10, count: 2, offline: false)',
        ),
        'Auth(status: AuthStatus.ready, id: '
        '0b6f6a52-6c1e-4f53-a0f4-2f9c3b1d7e10, count: 2, offline: false)',
      );
    });

    test('hides words, however they are spaced', () {
      expect(keepShape('Tag(name: Dr Who)'), 'Tag(name: ***)');
      expect(keepShape('Tag(name: x, y)'), 'Tag(name: ***, ***)');
    });
  });

  test('keeps the first line of a log, without addresses or queries', () {
    expect(
      scrubLogLine('→[1] GET /api/users?q=ann (12B)\nbody: {"title": "x"}'),
      '→[1] GET /api/users?*** (12B)',
    );
    expect(scrubLogLine('Signed in as ann@example.com'), 'Signed in as ***');
  });

  test('hides what a location was searched for', () {
    expect(scrubLocation('/note/abc'), '/note/abc');
    expect(scrubLocation('/?q=ann&tag=home'), '/?q=***&tag=***');
  });

  test('tells icons from text', () {
    expect(isIconText(String.fromCharCode(0xE15B)), isTrue);
    expect(isIconText('A'), isFalse);
    expect(isIconText('🙂'), isFalse);
  });

  test('paints censored rects grey, inside the frame', () {
    final pixels = Uint8List(4 * 4 * 4);
    censorPixels(pixels, 4, 4, [const Rect.fromLTRB(2, 2, 9, 9)]);
    int at(int x, int y) => pixels[(y * 4 + x) * 4];
    expect(at(1, 1), 0);
    expect(at(2, 2), 0x80);
    expect(at(3, 3), 0x80);
  });

  group('findCensoredRects', () {
    final key = GlobalKey();

    Future<List<Rect>> rectsOf(WidgetTester tester, Widget child) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: key,
            child: Scaffold(body: child),
          ),
        ),
      );
      return findCensoredRects(key.currentContext!.findRenderObject()!);
    }

    testWidgets('covers text line by line, and leaves icons', (tester) async {
      final rects = await rectsOf(
        tester,
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 100, child: Text('one two three four five six')),
            Icon(Icons.add),
          ],
        ),
      );
      expect(rects.length, greaterThan(1)); // the text wrapped
      final text = tester.getRect(find.byType(Text));
      for (final r in rects) {
        expect(text.inflate(2).contains(r.topLeft), isTrue);
      }
      final icon = tester.getRect(find.byType(Icon));
      expect(rects.any((r) => r.overlaps(icon.deflate(4))), isFalse);
    });

    testWidgets('covers pictures and typed text', (tester) async {
      final rects = await rectsOf(
        tester,
        Column(
          children: [
            SizedBox(
              width: 50,
              height: 40,
              child: Image.memory(_png, fit: BoxFit.fill),
            ),
            TextField(controller: TextEditingController(text: 'secret')),
          ],
        ),
      );
      final image = tester.getRect(find.byType(Image));
      expect(rects.any((r) => r.contains(image.center)), isTrue);
      final field = tester.getRect(find.byType(EditableText));
      expect(rects.any((r) => field.overlaps(r)), isTrue);
    });

    testWidgets('skips routes under an opaque one', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: key,
            child: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('below')),
              ),
            ),
          ),
        ),
      );
      final below = tester.getRect(find.text('below'));
      Navigator.of(tester.element(find.text('below'))).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: SizedBox.expand()),
        ),
      );
      await tester.pumpAndSettle();
      final rects = findCensoredRects(key.currentContext!.findRenderObject()!);
      expect(rects.any((r) => r.overlaps(below)), isFalse);
    });
  });
}

/// A 1×1 PNG.
final _png = Uint8List.fromList([
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
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0xF8,
  0xCF,
  0xC0,
  0xF0,
  0x1F,
  0x00,
  0x05,
  0x00,
  0x01,
  0xFF,
  0x89,
  0x99,
  0x3D,
  0x1D,
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
