import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/features/reminders/presentation/month_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpAugust(WidgetTester tester, Locale locale) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: locale,
          supportedLocales: [locale],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Material(
            child: MonthGrid(
              month: DateTime(2026, 8),
              selected: null,
              now: DateTime(2026, 7),
              onDay: (_) {},
              onMonth: (_) {},
            ),
          ),
        ),
      );

  double leftOf(WidgetTester tester, String day) =>
      tester.getRect(find.bySemanticsLabel(day)).left;

  testWidgets('weeks start on Sunday in US English', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpAugust(tester, const Locale('en', 'US'));

    expect(
      leftOf(tester, 'Sunday, July 26'),
      lessThan(leftOf(tester, 'Monday, July 27')),
    );
    expect(
      tester.getRect(find.bySemanticsLabel('Saturday, August 1')).top,
      tester.getRect(find.bySemanticsLabel('Sunday, July 26')).top,
    );
    expect(find.text('S'), findsNWidgets(2));
    semantics.dispose();
  });

  testWidgets('weeks start on Monday where the locale does', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpAugust(tester, const Locale('en', 'GB'));

    expect(find.bySemanticsLabel('Sunday, July 26'), findsNothing);
    expect(
      leftOf(tester, 'Monday, July 27'),
      lessThan(leftOf(tester, 'Tuesday, July 28')),
    );
    expect(
      tester.getRect(find.bySemanticsLabel('Sunday, August 2')).top,
      tester.getRect(find.bySemanticsLabel('Monday, July 27')).top,
    );
    semantics.dispose();
  });
}
