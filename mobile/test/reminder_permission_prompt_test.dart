import 'package:anchor/core/storage/preferences_repository.dart';
import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/features/reminders/data/notification_gateway.dart';
import 'package:anchor/features/reminders/presentation/reminder_permission_prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'reminder_permissions_test.dart' show FakeGateway;

class FakePreferences extends PreferencesRepository {
  FakePreferences() : super(const FlutterSecureStorage());

  bool offeredExact = false;
  bool askedNotifications = false;

  @override
  Future<bool> getNotificationsAsked() async => askedNotifications;

  @override
  Future<void> setNotificationsAsked(bool value) async =>
      askedNotifications = value;

  @override
  Future<bool> getExactAlarmsOffered() async => offeredExact;

  @override
  Future<void> setExactAlarmsOffered(bool value) async => offeredExact = value;
}

void main() {
  late FakePreferences prefs;

  setUp(() => prefs = FakePreferences());

  Future<void> run(
    WidgetTester tester,
    FakeGateway gateway, {
    required ReminderPermissionTrigger trigger,
    bool settle = true,
  }) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () =>
                      ensureReminderPermissions(context, ref, trigger: trigger),
                  child: const Text('Go'),
                ),
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationGatewayProvider.overrideWithValue(gateway),
          preferencesRepositoryProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );

    await tester.tap(find.text('Go'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  testWidgets('a reminder set here asks the system straight away', (
    tester,
  ) async {
    final gateway = FakeGateway(requiresExactAlarmPermission: false);
    await run(tester, gateway, trigger: ReminderPermissionTrigger.userSet);

    expect(find.text('Allow notifications?'), findsNothing);
    expect(gateway.requests, 1);
  });

  testWidgets('a synced reminder explains itself before the system dialog', (
    tester,
  ) async {
    final gateway = FakeGateway(requiresExactAlarmPermission: false);
    await run(tester, gateway, trigger: ReminderPermissionTrigger.synced);

    expect(find.text('Allow notifications?'), findsOneWidget);
    expect(gateway.requests, 0, reason: 'nothing asked until the user agrees');

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(gateway.requests, 1);
  });

  testWidgets('declining the explanation asks the system nothing', (
    tester,
  ) async {
    final gateway = FakeGateway(requiresExactAlarmPermission: false);
    await run(tester, gateway, trigger: ReminderPermissionTrigger.synced);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(gateway.requests, 0);
    expect(prefs.askedNotifications, isFalse);
  });

  testWidgets('a refusal is never asked again: a later reminder says where '
      'to turn it on', (tester) async {
    prefs.askedNotifications = true;
    final gateway = FakeGateway(requiresExactAlarmPermission: false)
      ..grantOnRequest = false;
    await run(
      tester,
      gateway,
      trigger: ReminderPermissionTrigger.userSet,
      settle: false,
    );

    expect(gateway.requests, 0);
    expect(find.textContaining('phone’s settings'), findsOneWidget);
    await tester.pump(const Duration(seconds: 7));
  });

  testWidgets('a synced reminder after a refusal asks nothing', (tester) async {
    prefs.askedNotifications = true;
    final gateway = FakeGateway(requiresExactAlarmPermission: false)
      ..grantOnRequest = false;
    await run(tester, gateway, trigger: ReminderPermissionTrigger.synced);

    expect(find.text('Allow notifications?'), findsNothing);
    expect(find.textContaining('phone’s settings'), findsNothing);
    expect(gateway.requests, 0);
  });

  testWidgets('asking the system is remembered, whatever the answer', (
    tester,
  ) async {
    final gateway = FakeGateway(requiresExactAlarmPermission: false)
      ..grantOnRequest = false;
    await run(tester, gateway, trigger: ReminderPermissionTrigger.userSet);

    expect(gateway.requests, 1);
    expect(prefs.askedNotifications, isTrue);
  });

  testWidgets('a refused grant says where to turn it back on', (tester) async {
    final gateway = FakeGateway(requiresExactAlarmPermission: false)
      ..grantOnRequest = false;
    // Checked before the snackbar's time runs out.
    await run(
      tester,
      gateway,
      trigger: ReminderPermissionTrigger.userSet,
      settle: false,
    );

    expect(find.textContaining('phone’s settings'), findsOneWidget);
    await tester.pump(const Duration(seconds: 7));
  });

  testWidgets('exact alarms are not raised while notifications are off', (
    tester,
  ) async {
    final gateway = FakeGateway()..grantOnRequest = false;
    await run(tester, gateway, trigger: ReminderPermissionTrigger.userSet);

    expect(find.text('Allow exact alarms?'), findsNothing);
    expect(prefs.offeredExact, isFalse);
  });

  testWidgets('exact alarms are offered once notifications are granted', (
    tester,
  ) async {
    final gateway = FakeGateway();
    await run(tester, gateway, trigger: ReminderPermissionTrigger.userSet);

    expect(find.text('Allow exact alarms?'), findsOneWidget);

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();

    expect(gateway.exactScreensOpened, 1);
  });

  testWidgets('the exact-alarm offer is never made twice', (tester) async {
    prefs.offeredExact = true;
    final gateway = FakeGateway(notifications: true);
    await run(tester, gateway, trigger: ReminderPermissionTrigger.userSet);

    expect(find.text('Allow exact alarms?'), findsNothing);
  });

  testWidgets('declining exact alarms still counts as answered', (
    tester,
  ) async {
    final gateway = FakeGateway(notifications: true);
    await run(tester, gateway, trigger: ReminderPermissionTrigger.userSet);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(gateway.exactScreensOpened, 0);
    expect(prefs.offeredExact, isTrue);
  });

  testWidgets('nothing is asked when the device is already set up', (
    tester,
  ) async {
    final gateway = FakeGateway(notifications: true, exact: true);
    await run(tester, gateway, trigger: ReminderPermissionTrigger.synced);

    expect(find.byType(Dialog), findsNothing);
    expect(gateway.requests, 0);
  });
}
