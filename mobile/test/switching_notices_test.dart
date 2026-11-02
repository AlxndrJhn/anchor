import 'package:anchor/core/storage/preferences_repository.dart';
import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/widgets/notice.dart';
import 'package:anchor/features/switching/data/other_anchor_app.dart';
import 'package:anchor/features/switching/presentation/switching_notices.dart';
import 'package:anchor/features/sync/data/sync_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPrefs extends Mock implements PreferencesRepository {}

class _FakeOtherApp extends OtherAnchorAppController {
  _FakeOtherApp(this.app);

  final OtherAnchorApp? app;

  @override
  Future<OtherAnchorApp?> build() async => app;
}

const _official = OtherAnchorApp(
  package: 'com.zhfahim.anchor',
  label: 'Anchor',
);

void main() {
  late _MockPrefs prefs;
  late List<MethodCall> calls;

  setUp(() {
    prefs = _MockPrefs();
    when(() => prefs.getOtherAppDismissed()).thenAnswer((_) async => false);
    when(() => prefs.setOtherAppDismissed()).thenAnswer((_) async {});
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('anchor/other_app'), (
          call,
        ) async {
          calls.add(call);
          return true;
        });
  });

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    OtherAnchorApp? other = _official,
    FirstDownload firstDownload = FirstDownload.done,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesRepositoryProvider.overrideWithValue(prefs),
          otherAnchorAppControllerProvider.overrideWith(
            () => _FakeOtherApp(other),
          ),
          firstDownloadProvider.overrideWithValue(firstDownload),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pump();
  }

  group('on the server page', () {
    testWidgets('asks to let the other app sync first, and opens it', (
      tester,
    ) async {
      await pump(tester, const SwitchingFromNotice());

      expect(
        find.textContaining('Moving from Anchor?', findRichText: true),
        findsOneWidget,
      );
      await tester.tap(find.bySemanticsLabel('Open Anchor'));
      expect(calls.single.method, 'open');
      expect(calls.single.arguments, {'package': 'com.zhfahim.anchor'});
    });

    testWidgets('says nothing without another Anchor app', (tester) async {
      await pump(tester, const SwitchingFromNotice(), other: null);

      expect(find.byType(Notice), findsNothing);
    });
  });

  group('above the notes', () {
    final banner = find.textContaining(
      'Your notes are here.',
      findRichText: true,
    );

    testWidgets('offers to uninstall the other app once notes are here', (
      tester,
    ) async {
      await pump(tester, const SwitchingDoneBanner());

      expect(banner, findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Uninstall Anchor'));
      expect(calls.single.method, 'showDetails');
      expect(calls.single.arguments, {'package': 'com.zhfahim.anchor'});
    });

    testWidgets('waits for the first download', (tester) async {
      await pump(
        tester,
        const SwitchingDoneBanner(),
        firstDownload: FirstDownload.running,
      );

      expect(banner, findsNothing);
    });

    testWidgets('Keep it hides it for good', (tester) async {
      await pump(tester, const SwitchingDoneBanner());

      await tester.tap(find.bySemanticsLabel('Keep it'));
      await tester.pump();
      expect(banner, findsNothing);
      verify(() => prefs.setOtherAppDismissed()).called(1);
    });

    testWidgets('stays away once dismissed', (tester) async {
      when(() => prefs.getOtherAppDismissed()).thenAnswer((_) async => true);
      await pump(tester, const SwitchingDoneBanner());

      expect(banner, findsNothing);
    });
  });
}
