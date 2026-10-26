import 'package:anchor/core/network/connectivity_provider.dart';
import 'package:anchor/core/network/server_config_provider.dart';
import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/features/auth/domain/oidc_config.dart';
import 'package:anchor/features/auth/domain/user.dart';
import 'package:anchor/features/auth/presentation/auth_controller.dart';
import 'package:anchor/features/auth/presentation/oidc_config_provider.dart';
import 'package:anchor/features/picture_search/picture_search.dart';
import 'package:anchor/features/server/data/server_info_provider.dart';
import 'package:anchor/features/settings/presentation/settings_screen.dart';
import 'package:anchor/features/sync/data/sync_compatibility.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';

class _SignedOut extends AuthController {
  @override
  Future<User?> build() async => null;
}

class _MockPictureSearchRepository extends Mock
    implements PictureSearchRepository {}

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

  Future<void> pumpSettings(
    WidgetTester tester,
    PictureSearchRepository repo,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isOnlineProvider.overrideWithValue(true),
          serverUrlProvider.overrideWithValue('https://example.test'),
          authControllerProvider.overrideWith(_SignedOut.new),
          oidcConfigProvider.overrideWith((ref) async => const OidcConfig()),
          serverInfoProvider.overrideWith((ref) async => null),
          syncCompatibilityProvider.overrideWith(
            (ref) async => SyncCompatibility.ok,
          ),
          pictureSearchRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder pictureSwitch() => find.text('Find pictures by what they show');

  testWidgets('a server without picture search shows no Search section', (
    tester,
  ) async {
    final repo = _MockPictureSearchRepository();
    when(repo.status).thenAnswer((_) async => PictureSearchStatus.off);

    await pumpSettings(tester, repo);

    expect(pictureSwitch(), findsNothing);
  });

  testWidgets('turning it on follows the download until it is done', (
    tester,
  ) async {
    final repo = _MockPictureSearchRepository();
    var status = const PictureSearchStatus(available: true, enabled: false);
    when(repo.status).thenAnswer((_) async => status);
    when(() => repo.setEnabled(true)).thenAnswer((_) async {
      status = const PictureSearchStatus(
        available: true,
        enabled: true,
        model: PictureModelState.downloading,
        progress: 0.1,
      );
      return status;
    });

    await pumpSettings(tester, repo);
    await tester.scrollUntilVisible(pictureSwitch(), 200);
    await tester.pumpAndSettle();
    expect(find.text('SEARCH'), findsOneWidget);

    await tester.tap(pictureSwitch());
    await tester.pumpAndSettle();
    verify(() => repo.setEnabled(true)).called(1);
    expect(
      find.textContaining('Downloading the picture model… 10%'),
      findsOneWidget,
    );

    status = const PictureSearchStatus(
      available: true,
      enabled: true,
      model: PictureModelState.ready,
      indexed: 3,
      total: 3,
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('All 3 pictures are ready to search.'),
      findsOneWidget,
    );

    // Done: no more asking.
    clearInteractions(repo);
    await tester.pump(const Duration(seconds: 5));
    verifyNever(repo.status);
  });

  testWidgets('a failed change says so', (tester) async {
    final repo = _MockPictureSearchRepository();
    when(repo.status).thenAnswer(
      (_) async => const PictureSearchStatus(available: true, enabled: false),
    );
    when(() => repo.setEnabled(true)).thenThrow(Exception('offline'));

    await pumpSettings(tester, repo);
    await tester.scrollUntilVisible(pictureSwitch(), 200);
    await tester.pumpAndSettle();
    await tester.tap(pictureSwitch());
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(
      find.textContaining('Couldn’t change picture search', findRichText: true),
      findsOneWidget,
    );
  });
}
