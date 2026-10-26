import 'dart:ffi' show Abi;

import 'package:anchor/core/storage/preferences_repository.dart';
import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/update/app_release.dart';
import 'package:anchor/core/update/app_updater.dart';
import 'package:anchor/core/update/update_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockPreferences extends Mock implements PreferencesRepository {}

/// A release as GitHub's API lists it, with notes as the workflow writes.
Map<String, Object?> _release(
  int build, {
  List<String> changes = const [],
  List<String> assets = const ['anchor-fork.apk', 'anchor-fork-x86_64.apk'],
  bool draft = false,
}) => {
  'tag_name': 'fork-0.17.2.$build',
  'html_url': 'https://github.com/o/r/releases/tag/fork-0.17.2.$build',
  'draft': draft,
  'prerelease': false,
  'body':
      'Built from abc1234.\n\n## Android\n\nInstall it.\n\n## Changes\n\n'
      '${changes.map((c) => '- $c (abc1234)\n').join()}\n'
      '**Full changelog:** https://github.com/o/r/compare/a...b\n',
  'assets': [
    for (final name in assets)
      {
        'name': name,
        'size': 44168880,
        'browser_download_url': 'https://github.com/o/r/$build/$name',
      },
  ],
};

class FakeSource extends UpdateSource {
  FakeSource(this.list);

  List<Object?> list;
  Object? failure;
  final installed = <String>[];

  @override
  Future<List<Object?>> releases() async {
    if (failure != null) throw failure!;
    return list;
  }

  @override
  Future<String> download(
    AppRelease release,
    void Function(double progress) onProgress,
  ) async {
    onProgress(0.5);
    onProgress(1);
    return '/cache/updates/${release.tag}.apk';
  }

  @override
  Future<void> install(String path) async => installed.add(path);
}

void main() {
  group('release names', () {
    test('a tag ends in its build number', () {
      expect(buildOfTag('fork-0.17.2.22'), 22);
      expect(buildOfTag('fork-1.0.0.140'), 140);
      expect(buildOfTag('v0.17.2'), isNull);
      expect(buildOfTag('android-latest'), isNull);
    });

    test('each phone gets the APK for its processor', () {
      expect(apkAssetFor(Abi.androidArm64), 'anchor-fork.apk');
      expect(apkAssetFor(Abi.androidArm), 'anchor-fork-armeabi-v7a.apk');
      expect(apkAssetFor(Abi.androidX64), 'anchor-fork-x86_64.apk');
    });

    test('the changes come from the notes, without commit hashes', () {
      final notes = _release(22, changes: ['feat: one', 'fix: two'])['body'];
      expect(changesInNotes(notes! as String), ['feat: one', 'fix: two']);
      expect(changesInNotes('No changes section'), isEmpty);
    });
  });

  group('the newest release', () {
    test('is the highest build above the installed one', () {
      final release = newestRelease(
        [
          _release(23, changes: ['c']),
          _release(22, changes: ['b']),
          _release(21, changes: ['a']),
        ],
        installed: 21,
        asset: 'anchor-fork.apk',
      );

      expect(release?.tag, 'fork-0.17.2.23');
      expect(release?.build, 23);
      expect(release?.apkUrl, 'https://github.com/o/r/23/anchor-fork.apk');
      expect(release?.apkSize, 44168880);
      // Everything since the installed build, newest first.
      expect(release?.changes, ['c', 'b']);
    });

    test('is none when the installed build is the newest', () {
      expect(
        newestRelease(
          [_release(21), _release(20)],
          installed: 21,
          asset: 'anchor-fork.apk',
        ),
        isNull,
      );
    });

    test('skips drafts, and releases without this phone\'s APK', () {
      final release = newestRelease(
        [
          _release(25, draft: true),
          _release(24, assets: ['anchor-fork-x86_64.apk']),
          _release(23),
        ],
        installed: 20,
        asset: 'anchor-fork.apk',
      );

      expect(release?.build, 23);
    });
  });

  group('the update controller', () {
    late FakeSource source;
    late MockPreferences prefs;

    setUp(() {
      source = FakeSource([
        _release(23, changes: ['feat: new']),
        _release(22),
      ]);
      prefs = MockPreferences();
      when(() => prefs.getDismissedUpdate()).thenAnswer((_) async => null);
      when(() => prefs.setDismissedUpdate(any())).thenAnswer((_) async {});
    });

    ProviderContainer container({int installed = 22}) {
      final c = ProviderContainer(
        overrides: [
          updateSourceProvider.overrideWithValue(source),
          installedBuildNumberProvider.overrideWithValue(installed),
          preferencesRepositoryProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('finds a newer release and offers it', () async {
      final c = container();

      final release = await c.read(updateControllerProvider.notifier).check();

      expect(release?.tag, 'fork-0.17.2.23');
      final state = c.read(updateControllerProvider);
      expect(state.status, UpdateStatus.available);
      expect(state.showBanner, isTrue);
    });

    test('says so when this is the newest build', () async {
      final c = container(installed: 23);

      expect(await c.read(updateControllerProvider.notifier).check(), isNull);
      expect(c.read(updateControllerProvider).status, UpdateStatus.upToDate);
      expect(c.read(updateControllerProvider).showBanner, isFalse);
    });

    test('"Later" hides that release, and remembers it', () async {
      final c = container();
      final controller = c.read(updateControllerProvider.notifier);
      await controller.check();

      await controller.dismiss();

      expect(c.read(updateControllerProvider).showBanner, isFalse);
      verify(() => prefs.setDismissedUpdate(23)).called(1);

      // Checking again later still finds it put off.
      when(() => prefs.getDismissedUpdate()).thenAnswer((_) async => 23);
      await controller.check();
      expect(c.read(updateControllerProvider).showBanner, isFalse);
    });

    test('downloads the APK and hands it to the installer', () async {
      final c = container();
      final controller = c.read(updateControllerProvider.notifier);
      await controller.check();

      await controller.install();

      expect(source.installed, ['/cache/updates/fork-0.17.2.23.apk']);
      expect(c.read(updateControllerProvider).progress, 1);
    });

    test('a failed check says so', () async {
      source.failure = Exception('offline');
      final c = container();

      expect(await c.read(updateControllerProvider.notifier).check(), isNull);
      final state = c.read(updateControllerProvider);
      expect(state.status, UpdateStatus.failed);
      expect(state.error, UpdateError.check);
    });

    testWidgets('the sheet downloads and installs the update', (tester) async {
      final c = container();
      await c.read(updateControllerProvider.notifier).check();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showUpdateSheet(context),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('What’s new'), findsOneWidget);
      expect(
        find.bySemanticsLabel('View the release on GitHub'),
        findsOneWidget,
      );
      await tester.tap(find.bySemanticsLabel('Download and install (42 MB)'));
      await tester.pumpAndSettle();

      expect(source.installed, ['/cache/updates/fork-0.17.2.23.apk']);
    });

    testWidgets('the banner opens the update, and Later hides it', (
      tester,
    ) async {
      final c = container();
      await c.read(updateControllerProvider.notifier).check();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: UpdateBanner()),
          ),
        ),
      );

      final banner = find.textContaining(
        'Update available fork-0.17.2.23',
        findRichText: true,
      );
      expect(banner, findsOneWidget);
      await tester.tap(find.bySemanticsLabel('See what’s new'));
      await tester.pumpAndSettle();
      expect(find.textContaining('feat: new'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Download and install (42 MB)'),
        findsOneWidget,
      );

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Later'));
      await tester.pump();
      expect(banner, findsNothing);
      verify(() => prefs.setDismissedUpdate(23)).called(1);
    });
  });
}
