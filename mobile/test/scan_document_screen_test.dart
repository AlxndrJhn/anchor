import 'dart:io';

import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/features/notes/domain/scan_document.dart';
import 'package:anchor/features/notes/presentation/widgets/scan_document_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  Future<List<ScanResult?>> pumpScreen(
    WidgetTester tester,
    ScanDocument scan,
  ) async {
    final results = <ScanResult?>[];
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(
              await ScanDocumentScreen.open(
                context,
                scan: scan,
                findPhoto: (_) async => null,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  final list = find
      .descendant(
        of: find.byType(ReorderableListView),
        matching: find.byType(Scrollable),
      )
      .first;

  const scan = ScanDocument(
    title: 'Receipts',
    pages: [
      ScanPage(id: 'a'),
      ScanPage(id: 'b', profile: ScanProfile.bw),
    ],
  );

  testWidgets('lists the pages with their profiles', (tester) async {
    await pumpScreen(tester, scan);

    expect(find.text('Page 1'), findsOneWidget);
    expect(find.text('Page 2'), findsOneWidget);
    expect(find.text('Color text'), findsOneWidget);
    expect(find.text('B/W'), findsOneWidget);
    expect(find.text('Receipts'), findsOneWidget);
  });

  testWidgets('turns and drops pages, sets up the PDF, and saves it all', (
    tester,
  ) async {
    final results = await pumpScreen(tester, scan);

    await tester.tap(find.bySemanticsLabel('Turn right').first);
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Delete page').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('10 mm'), 100, scrollable: list);
    await tester.tap(find.text('10 mm'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('scan-done')));
    await tester.pumpAndSettle();

    final saved = results.single! as ScanSaved;
    expect(saved.scan.title, 'Receipts');
    expect(saved.scan.pages, hasLength(1));
    expect(saved.scan.pages.single.id, 'a');
    expect(saved.scan.pages.single.rotate, 90);
    expect(saved.scan.pdf.margin, 10);
  });

  testWidgets('a scan in the note can be removed', (tester) async {
    final results = await pumpScreen(tester, scan);

    await tester.scrollUntilVisible(
      find.text('Remove scan'),
      100,
      scrollable: list,
    );
    await tester.tap(find.text('Remove scan'));
    await tester.pumpAndSettle();

    expect(results.single, isA<ScanRemoved>());
  });

  testWidgets('a page thumbnail shows the page once it is made', (
    tester,
  ) async {
    final temp = Directory.systemTemp.createTempSync('scan-thumb');
    addTearDown(() => temp.deleteSync(recursive: true));
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => temp.path,
    );
    final photo = '${temp.path}/photo.jpg';
    File(
      photo,
    ).writeAsBytesSync(img.encodeJpg(img.Image(width: 300, height: 400)));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Center(
          child: SizedBox(
            width: 72,
            height: 96,
            child: ScanPageThumbnail(
              photo: Future.value(photo),
              page: const ScanPage(id: 'a'),
            ),
          ),
        ),
      ),
    );
    final image = find.byType(Image);
    for (var i = 0; i < 200 && image.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }

    expect(image, findsOneWidget);
  });
}
