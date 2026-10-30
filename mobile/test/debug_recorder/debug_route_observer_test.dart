import 'package:anchor/features/debug_recorder/data/debug_recorder_controller.dart';
import 'package:anchor/features/debug_recorder/data/debug_route_observer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  late GoRouter router;

  setUp(() {
    router = GoRouter(
      observers: [DebugRouteObserver()],
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Notes')),
        ),
        GoRoute(
          path: '/other',
          builder: (_, _) => const Scaffold(body: Text('Other')),
        ),
      ],
    );
  });

  tearDown(() {
    router.dispose();
    DebugRecorder.instance.finishReview();
  });

  List<Map<String, Object?>> navigatorEvents() => [
    for (final e in DebugRecorder.instance.events)
      if (e.type == 'navigator') e.data,
  ];

  testWidgets('records pushed screens and sheets, not go_router pages', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    DebugRecorder.instance.start(boundary: () => null, onFinished: (_) {});

    router.go('/other');
    await tester.pumpAndSettle();
    expect(navigatorEvents(), isEmpty);

    final navigator = router.routerDelegate.navigatorKey.currentState!;
    navigator.push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'camera'),
        builder: (_) => const Text('Camera'),
      ),
    );
    await tester.pumpAndSettle();
    navigator.pop();
    await tester.pumpAndSettle();
    showModalBottomSheet<void>(
      context: navigator.context,
      builder: (_) => const Text('Sheet'),
    );
    await tester.pumpAndSettle();

    expect(navigatorEvents(), [
      {'action': 'push', 'route': 'camera'},
      {'action': 'pop', 'route': 'camera'},
      {'action': 'push', 'route': 'ModalBottomSheetRoute<void>'},
    ]);
    DebugRecorder.instance.stop((_) {});
    await tester.pump();
  });

  testWidgets('records nothing while not recording', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.routerDelegate.navigatorKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Text('Camera')),
    );
    await tester.pumpAndSettle();
    expect(DebugRecorder.instance.events, isEmpty);
  });
}
