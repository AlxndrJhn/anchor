import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/widgets/app_scaffold.dart';
import 'package:anchor/features/notes/presentation/widgets/pull_to_refresh.dart';
import 'package:anchor/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _english = lookupAppLocalizations(const Locale('en'));

void main() {
  Future<int> pullDown(WidgetTester tester, {required bool isSynced}) async {
    var syncs = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AppScaffold(
          title: 'Notes',
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          refreshSliver: PullToRefresh(
            isOnline: () => true,
            onSync: () async {
              syncs++;
              return isSynced;
            },
          ),
          slivers: [
            SliverList.list(
              children: [
                for (var i = 0; i < 30; i++)
                  SizedBox(height: 60, child: Text('Note $i')),
              ],
            ),
          ],
        ),
      ),
    );
    await tester.drag(find.text('Note 0'), const Offset(0, 300));
    return syncs;
  }

  Future<bool> shows(WidgetTester tester, String text) async {
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text(text).evaluate().isNotEmpty) return true;
    }
    return false;
  }

  testWidgets('a pull below the bar syncs and says it is up to date', (
    tester,
  ) async {
    await pullDown(tester, isSynced: true);
    expect(await shows(tester, _english.pullUpToDate), isTrue);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('a pull that fails to sync says so', (tester) async {
    await pullDown(tester, isSynced: false);
    expect(await shows(tester, _english.pullFailed), isTrue);
    expect(find.text(_english.pullUpToDate), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });
}
