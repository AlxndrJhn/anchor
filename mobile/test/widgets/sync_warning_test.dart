import 'package:anchor/core/session/session_expired_provider.dart';
import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/features/sync/data/sync_compatibility.dart';
import 'package:anchor/features/sync/presentation/sync_warning.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _signInMessage = 'Signed out. Sign in again to sync your notes.';

Future<ProviderContainer> _pump(WidgetTester tester) async {
  final container = ProviderContainer(
    overrides: [
      syncCompatibilityProvider.overrideWith(
        (ref) async => SyncCompatibility.ok,
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: SyncWarning()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('shows nothing while sync is fine', (tester) async {
    await _pump(tester);

    expect(find.text(_signInMessage, findRichText: true), findsNothing);
  });

  testWidgets('asks the user to sign in again once the server refuses', (
    tester,
  ) async {
    final container = await _pump(tester);

    container.read(sessionExpiredProvider.notifier).expire();
    await tester.pumpAndSettle();
    expect(find.text(_signInMessage, findRichText: true), findsOneWidget);

    await tester.tap(find.text(_signInMessage, findRichText: true));
    await tester.pumpAndSettle();
    expect(find.text('Sign in again'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
  });
}
