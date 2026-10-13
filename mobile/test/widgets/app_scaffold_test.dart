import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/widgets/app_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a focused field scrolls up above the keyboard', (tester) async {
    tester.view
      ..physicalSize = const Size(1080, 2376)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    const field = Key('field');
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: AppScaffold(
          title: 'Sign in',
          slivers: [
            SliverList.list(
              children: const [
                SizedBox(height: 560),
                TextField(key: field),
              ],
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.byKey(field));
    await tester.pump();

    const keyboard = 320.0;
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard * 3);
    await tester.pumpAndSettle();

    expect(
      tester.getRect(find.byKey(field)).bottom,
      lessThanOrEqualTo(792 - keyboard),
    );
  });
}
