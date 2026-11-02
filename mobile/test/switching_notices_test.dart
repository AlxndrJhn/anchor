import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/widgets/notice.dart';
import 'package:anchor/features/switching/data/other_anchor_app.dart';
import 'package:anchor/features/switching/presentation/switching_notices.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
  late List<MethodCall> calls;

  setUp(() {
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
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          otherAnchorAppControllerProvider.overrideWith(
            () => _FakeOtherApp(other),
          ),
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
}
