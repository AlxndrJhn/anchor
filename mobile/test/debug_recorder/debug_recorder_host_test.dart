import 'package:anchor/app/router/app_router.dart';
import 'package:anchor/features/debug_recorder/data/debug_recorder_controller.dart';
import 'package:anchor/features/debug_recorder/presentation/debug_recorder_host.dart';
import 'package:anchor/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  late GoRouter router;

  setUp(() {
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Notes')),
        ),
      ],
    );
  });

  tearDown(() {
    router.dispose();
    DebugRecorder.instance.finishReview();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [goRouterProvider.overrideWith((_) => router)],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => DebugRecorderHost(child: child),
        ),
      ),
    );
  }

  testWidgets('two fingers held still for 3 s start recording', (tester) async {
    await pumpApp(tester);
    final a = await tester.startGesture(const Offset(100, 200), pointer: 1);
    final b = await tester.startGesture(const Offset(200, 200), pointer: 2);
    await tester.pump(const Duration(seconds: 2));
    expect(DebugRecorder.instance.isRecording, isFalse);

    await tester.pump(const Duration(seconds: 1, milliseconds: 100));
    expect(DebugRecorder.instance.isRecording, isTrue);
    expect(find.byIcon(LucideIcons.video), findsOneWidget);
    expect(find.bySemanticsLabel('Stop debug recording'), findsOneWidget);
    await a.up();
    await b.up();

    // The camera stops it.
    await tester.tap(find.byIcon(LucideIcons.video));
    await tester.pump();
    expect(DebugRecorder.instance.isRecording, isFalse);
    expect(find.byIcon(LucideIcons.video), findsNothing);
  });

  testWidgets('moving fingers or a third one cancel the hold', (tester) async {
    await pumpApp(tester);
    final a = await tester.startGesture(const Offset(100, 200), pointer: 1);
    final b = await tester.startGesture(const Offset(200, 200), pointer: 2);
    await tester.pump(const Duration(seconds: 1));
    await a.moveBy(const Offset(0, 60));
    await tester.pump(const Duration(seconds: 3));
    expect(DebugRecorder.instance.isRecording, isFalse);

    final c = await tester.startGesture(const Offset(300, 200), pointer: 3);
    await tester.pump(const Duration(seconds: 4));
    expect(DebugRecorder.instance.isRecording, isFalse);
    await a.up();
    await b.up();
    await c.up();
  });
}
