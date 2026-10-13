import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/widgets/app_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> show(
    WidgetTester tester, {
    String? actionLabel,
    ValueChanged<bool>? onClosed,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => AppSnackbar.show(
                context,
                'Note archived',
                actionLabel: actionLabel,
                onAction: actionLabel == null ? null : () {},
                onClosed: onClosed,
              ),
              child: const Text('Archive'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Archive'));
    await tester.pump();
  }

  bool isShown() => find.text('Note archived').evaluate().isNotEmpty;

  testWidgets('Undo stays its full time with animations off', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await show(tester, actionLabel: 'Undo');

    await tester.pump(const Duration(seconds: 5));
    expect(isShown(), isTrue);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(isShown(), isFalse);
  });

  testWidgets('with a screen reader on, a snackbar with an action waits', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await show(tester, actionLabel: 'Undo');

    await tester.pump(const Duration(seconds: 30));
    expect(isShown(), isTrue);
  });

  testWidgets('a screen reader can close a snackbar that waits', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final closed = <bool>[];
    await show(tester, actionLabel: 'Undo', onClosed: closed.add);
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();

    SemanticsNode? node = tester.getSemantics(find.text('Note archived'));
    while (node != null &&
        !node.getSemanticsData().hasAction(SemanticsAction.dismiss)) {
      node = node.parent;
    }
    expect(node, isNotNull);
    node!.owner!.performAction(node.id, SemanticsAction.dismiss);
    await tester.pumpAndSettle();

    expect(isShown(), isFalse);
    expect(closed, [false]);
    semantics.dispose();
  });

  testWidgets('with a screen reader on, a plain snackbar still leaves', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await show(tester);

    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    expect(isShown(), isFalse);
  });
}
