import 'package:anchor/core/network/connectivity_provider.dart';
import 'package:anchor/core/network/server_config_provider.dart';
import 'package:anchor/core/storage/storage_keys.dart';
import 'package:anchor/core/text/date_formats.dart';
import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/widgets/segmented_control.dart';
import 'package:anchor/features/auth/domain/oidc_config.dart';
import 'package:anchor/features/auth/domain/user.dart';
import 'package:anchor/features/auth/presentation/auth_controller.dart';
import 'package:anchor/features/auth/presentation/oidc_config_provider.dart';
import 'package:anchor/features/reminders/presentation/reminder_preferences_controller.dart';
import 'package:anchor/features/server/data/server_info_provider.dart';
import 'package:anchor/features/settings/presentation/settings_screen.dart';
import 'package:anchor/features/sync/data/sync_compatibility.dart';
import 'package:anchor/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

class _SignedOut extends AuthController {
  @override
  Future<User?> build() async => null;
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Anchor',
      packageName: 'anchor',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  Future<ProviderContainer> pumpSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        isOnlineProvider.overrideWithValue(true),
        serverUrlProvider.overrideWithValue('https://example.test'),
        authControllerProvider.overrideWith(_SignedOut.new),
        oidcConfigProvider.overrideWith((ref) async => const OidcConfig()),
        serverInfoProvider.overrideWith((ref) async => null),
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Week starts on'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('Reminders shows the times of day and the week start', (
    tester,
  ) async {
    await pumpSettings(tester);

    for (final label in [
      'Morning',
      'Afternoon',
      'Evening',
      'Night',
      'Week starts on',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    for (final hour in [8, 13, 18, 22]) {
      expect(find.text(clockLabel(DateTime(2024, 1, 1, hour))), findsOneWidget);
    }
  });

  testWidgets('picking a week start keeps it', (tester) async {
    final container = await pumpSettings(tester);

    await tester.tap(
      find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is SegmentedControl && w.semanticLabel == 'Week starts on',
        ),
        matching: find.text('Sunday'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      container.read(reminderPreferencesControllerProvider).weekStart,
      DateTime.sunday,
    );
    expect(
      await const FlutterSecureStorage().read(
        key: StorageKeys.reminderWeekStart,
      ),
      '${DateTime.sunday}',
    );
  });
}
