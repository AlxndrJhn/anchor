import 'dart:io';

import 'package:anchor/core/files/page_scan.dart';
import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/features/notes/presentation/widgets/page_scan_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  late Directory tmp;
  late String picture;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('scan');
    picture = '${tmp.path}/page.png';
    File(
      picture,
    ).writeAsBytesSync(img.encodePng(img.Image(width: 300, height: 400)));
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  const found = [
    Offset(0.2, 0.1),
    Offset(0.8, 0.15),
    Offset(0.85, 0.9),
    Offset(0.15, 0.85),
  ];

  /// Opens the screen from a button and returns what it gave back.
  Future<List<PageCorners?>> pumpScreen(
    WidgetTester tester, {
    PageCorners? corners = found,
  }) async {
    final results = <PageCorners?>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              results.add(
                await Navigator.of(context).push<PageCorners>(
                  MaterialPageRoute(
                    builder: (_) => PageScanScreen(
                      path: picture,
                      findCorners: (_) async => corners,
                    ),
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    // The picture is read for real, which takes real time.
    final area = find.byKey(const ValueKey('page-scan-area'));
    for (var i = 0; i < 100 && area.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(area, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    return results;
  }

  testWidgets('starts from the page it found and hands its corners back', (
    tester,
  ) async {
    final results = await pumpScreen(tester);

    expect(find.text('Drag a corner to fit it to the page.'), findsOneWidget);
    await tester.tap(find.text('Straighten'));
    await tester.pumpAndSettle();

    expect(results.single, found);
  });

  testWidgets('says so when no page was found', (tester) async {
    final results = await pumpScreen(tester, corners: null);

    expect(
      find.text('No page found. Drag the corners onto the page’s corners.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Straighten'));
    await tester.pumpAndSettle();

    expect(results.single, insetCorners);
  });

  testWidgets('a corner follows the finger', (tester) async {
    final results = await pumpScreen(tester);
    final area = find.byKey(const ValueKey('page-scan-area'));
    final box = tester.getRect(area);
    // Where the top left corner is drawn: the picture fills the height.
    final pictureWidth = box.height * 300 / 400;
    final left = box.center.dx - pictureWidth / 2;
    final corner = Offset(
      left + found[0].dx * pictureWidth,
      box.top + found[0].dy * box.height,
    );

    final drag = await tester.startGesture(corner);
    await drag.moveBy(const Offset(20, 0));
    await drag.moveBy(const Offset(20, 30));
    await tester.pump();
    await drag.up();
    await tester.pump();

    await tester.tap(find.text('Straighten'));
    await tester.pumpAndSettle();
    final moved = results.single!;
    expect(moved[0].dx, greaterThan(found[0].dx));
    expect(moved[0].dy, greaterThan(found[0].dy));
    expect(moved.sublist(1), found.sublist(1));
  });

  testWidgets('Whole picture puts the corners on the picture’s own', (
    tester,
  ) async {
    final results = await pumpScreen(tester);

    await tester.tap(find.text('Whole picture'));
    await tester.pump();
    await tester.tap(find.text('Straighten'));
    await tester.pumpAndSettle();

    expect(results.single, wholeCorners);
  });
}
