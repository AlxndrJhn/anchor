import 'dart:convert';

import 'package:anchor/core/network/server_config_provider.dart';
import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/features/note_locks/data/lock_hash.dart';
import 'package:anchor/features/note_locks/data/note_lock_secrets.dart';
import 'package:anchor/features/note_locks/presentation/lock_pads.dart';
import 'package:anchor/features/note_locks/presentation/lock_secret_setup_screen.dart';
import 'package:anchor/features/note_locks/presentation/note_lock_gate.dart';
import 'package:anchor/features/note_locks/presentation/note_lock_session.dart';
import 'package:anchor/features/notes/data/repository/notes_repository.dart';
import 'package:anchor/features/notes/domain/note.dart';
import 'package:anchor/features/notes/presentation/note_morph_route.dart';
import 'package:anchor/features/notes/presentation/widgets/note_card.dart';
import 'package:anchor/features/tags/presentation/tags_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockNotesRepository extends Mock implements NotesRepository {}

/// The account's PIN is 2580, cached here; the server is never asked.
class FakeSecrets extends NoteLockSecretsController {
  static final pinHash =
      'pbkdf2-sha256\$10\$${base64.encode(utf8.encode('salt'))}\$'
      '${base64.encode(pbkdf2Sha256(utf8.encode('2580'), utf8.encode('salt'), 10, 32))}';

  @override
  Future<NoteLockSecrets> build() async => NoteLockSecrets(pin: pinHash);

  @override
  Future<NoteLockSecrets?> refresh() async => null;
}

/// Records what would be saved on the server.
class RecordingSecrets extends NoteLockSecretsController {
  RecordingSecrets({this.hasPin = false});

  final bool hasPin;
  final saved = <(LockSecretKind, String)>[];
  String? password;

  @override
  Future<NoteLockSecrets> build() async =>
      NoteLockSecrets(pin: hasPin ? FakeSecrets.pinHash : null);

  @override
  Future<NoteLockSecrets?> refresh() async => null;

  @override
  Future<NoteLockSecrets> setSecret(
    LockSecretKind kind,
    String secret, {
    String? current,
    String? password,
  }) async {
    saved.add((kind, secret));
    this.password = password;
    return NoteLockSecrets(pin: FakeSecrets.pinHash);
  }
}

void main() {
  const lockedNote = Note(
    id: 'n1',
    title: 'Diary',
    content: '{"ops":[{"insert":"the secret text\\n"}]}',
    lock: NoteLock.pin,
  );

  group('pattern pad', () {
    Future<List<String>> drawn(
      WidgetTester tester,
      List<int> dots, {
      bool stepwise = true,
    }) async {
      final out = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox.square(
                dimension: 300,
                child: LockPatternPad(onComplete: out.add),
              ),
            ),
          ),
        ),
      );
      final origin = tester.getTopLeft(find.byType(LockPatternPad));
      Offset at(int dot) =>
          origin + Offset((dot % 3) * 100 + 50, (dot ~/ 3) * 100 + 50);
      final gesture = await tester.startGesture(at(dots.first));
      for (final dot in dots.skip(1)) {
        if (stepwise) {
          // Through the space between the dots, as a finger goes.
          final from = at(dots[dots.indexOf(dot) - 1]);
          for (var i = 1; i <= 10; i++) {
            await gesture.moveTo(Offset.lerp(from, at(dot), i / 10)!);
          }
        } else {
          await gesture.moveTo(at(dot));
        }
      }
      await gesture.up();
      await tester.pump();
      return out;
    }

    testWidgets('gives the dots joined, in order', (tester) async {
      expect(await drawn(tester, [0, 3, 6, 7, 8]), ['03678']);
    });

    testWidgets('a dot passed straight over is joined too', (tester) async {
      expect(await drawn(tester, [0, 2, 8], stepwise: false), ['01258']);
      expect(await drawn(tester, [6, 2, 0], stepwise: false), ['64210']);
    });

    testWidgets('a dot is joined once', (tester) async {
      expect(await drawn(tester, [0, 1, 4, 1, 2]), ['0142']);
    });
  });

  group('note card', () {
    Future<ProviderContainer> pumpCard(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tagsControllerProvider.overrideWith(TagsController.new),
            serverUrlProvider.overrideWithValue('https://example.test'),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(
              body: SizedBox(
                width: 300,
                child: NoteCard(note: lockedNote, tags: []),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return ProviderScope.containerOf(tester.element(find.byType(NoteCard)));
    }

    testWidgets('a locked note shows its title, not its text', (tester) async {
      final semantics = tester.ensureSemantics();
      final container = await pumpCard(tester);

      expect(find.text('Diary'), findsOneWidget);
      expect(find.text('Locked'), findsOneWidget);
      expect(find.textContaining('secret'), findsNothing);
      // Nor do screen readers read it out.
      expect(find.bySemanticsLabel(RegExp('secret')), findsNothing);
      expect(find.bySemanticsLabel(RegExp('Diary. Locked')), findsOneWidget);

      container.read(noteLockSessionProvider.notifier).unlock('n1');
      await tester.pump();

      expect(find.textContaining('secret'), findsOneWidget);
      expect(find.text('Locked'), findsNothing);
      expect(find.byKey(const ValueKey('card-unlocked')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('secret')), findsOneWidget);
      semantics.dispose();
    });
  });

  group('lock gate', () {
    late MockNotesRepository repo;

    setUp(() {
      repo = MockNotesRepository();
      when(
        () => repo.watchNote('n1'),
      ).thenAnswer((_) => Stream.value(lockedNote));
    });

    Future<void> pumpGate(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notesRepositoryProvider.overrideWithValue(repo),
            noteLockSecretsControllerProvider.overrideWith(FakeSecrets.new),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const NoteLockGate(
              noteId: 'n1',
              note: lockedNote,
              child: Scaffold(body: Text('the secret text')),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    Future<void> enterPin(WidgetTester tester, String pin) async {
      for (final digit in pin.split('')) {
        await tester.tap(find.byKey(ValueKey('pin-key-$digit')));
      }
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('pin-key-ok')));
        // The hash is checked on another isolate.
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pump();
      await tester.pump();
    }

    testWidgets('opens with the right PIN only', (tester) async {
      await pumpGate(tester);

      expect(find.text('Diary'), findsOneWidget);
      expect(find.text('Enter your PIN'), findsOneWidget);
      expect(find.text('the secret text'), findsNothing);

      await enterPin(tester, '1111');
      expect(find.text('Wrong PIN'), findsOneWidget);
      expect(find.text('the secret text'), findsNothing);

      await enterPin(tester, '2580');
      expect(find.text('the secret text'), findsOneWidget);
      expect(find.text('Enter your PIN'), findsNothing);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('a tap lock opens with a tap, and locks again when the '
        'screen goes off', (tester) async {
      when(() => repo.watchNote('n1')).thenAnswer(
        (_) => Stream.value(lockedNote.copyWith(lock: NoteLock.tap)),
      );
      await pumpGate(tester);

      await tester.tap(find.byKey(const ValueKey('tap-to-unlock')));
      await tester.pump();
      expect(find.text('the secret text'), findsOneWidget);

      await _screenOff(tester);

      expect(find.text('the secret text'), findsNothing);
      expect(find.byKey(const ValueKey('tap-to-unlock')), findsOneWidget);
    });
  });

  group('session', () {
    testWidgets('ends when the screen goes off', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final session = container.read(noteLockSessionProvider.notifier);

      session.unlock('n1');
      session.unlock('n2');
      expect(container.read(noteLockSessionProvider), {'n1', 'n2'});

      await _screenOff(tester);
      expect(container.read(noteLockSessionProvider), isEmpty);
    });

    testWidgets('ends on resume if the screen went off while Flutter wasn’t '
        'listening', (tester) async {
      var wentOff = true;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        noteLockChannel,
        (call) async {
          if (call.method != 'takeScreenOff') return null;
          final answer = wentOff;
          wentOff = false;
          return answer;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          noteLockChannel,
          null,
        ),
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(noteLockSessionProvider.notifier).unlock('n1');

      await _backgroundAndBack(tester);

      expect(container.read(noteLockSessionProvider), isEmpty);

      // Switching apps (no screen off) keeps what was unlocked.
      container.read(noteLockSessionProvider.notifier).unlock('n1');
      await _backgroundAndBack(tester);

      expect(container.read(noteLockSessionProvider), {'n1'});
    });
  });

  group('opening from the list', () {
    testWidgets('the note morphs open on its unlock page; its text never '
        'shows before the lock opens', (tester) async {
      final repo = MockNotesRepository();
      when(
        () => repo.watchNote('n1'),
      ).thenAnswer((_) => Stream.value(lockedNote));
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: Text('Notes')),
            routes: [
              GoRoute(
                path: 'note/:id',
                pageBuilder: (context, state) => NoteMorphPage(
                  key: ValueKey('note/${state.pathParameters['id']}'),
                  noteId: state.pathParameters['id'],
                  child: NoteLockGate(
                    noteId: state.pathParameters['id']!,
                    note: state.extra as Note?,
                    child: const Scaffold(body: Text('the secret text')),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notesRepositoryProvider.overrideWithValue(repo),
            noteLockSecretsControllerProvider.overrideWith(FakeSecrets.new),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      router.go('/note/n1', extra: lockedNote);
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text('the secret text'), findsNothing);
      }
      expect(find.text('Diary'), findsOneWidget);
      expect(find.text('Enter your PIN'), findsOneWidget);

      // Back closes it, still locked.
      await tester.tap(find.bySemanticsLabel('Back'));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text('the secret text'), findsNothing);
      }
      expect(find.text('Notes'), findsOneWidget);
    });
  });

  group('setting the PIN', () {
    Future<void> type(WidgetTester tester, String pin) async {
      for (final digit in pin.split('')) {
        await tester.tap(find.byKey(ValueKey('pin-key-$digit')));
      }
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('pin-key-ok')));
      await tester.pump();
      await tester.pump();
    }

    Future<void> pumpSetup(
      WidgetTester tester,
      RecordingSecrets secrets, {
      required bool replacing,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            noteLockSecretsControllerProvider.overrideWith(() => secrets),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: LockSecretSetupScreen(
              kind: LockSecretKind.pin,
              replacing: replacing,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('a new PIN is asked twice, then saved', (tester) async {
      final secrets = RecordingSecrets();
      await pumpSetup(tester, secrets, replacing: false);
      expect(find.text('Choose a PIN'), findsOneWidget);

      await type(tester, '12');
      expect(find.text('Use 4 to 12 digits'), findsOneWidget);
      await type(tester, '2580');
      expect(find.text('Enter the PIN again'), findsOneWidget);
      await type(tester, '2580');
      expect(secrets.saved, [(LockSecretKind.pin, '2580')]);
    });

    testWidgets('changing it can take the password for the old one', (
      tester,
    ) async {
      final secrets = RecordingSecrets(hasPin: true);
      await pumpSetup(tester, secrets, replacing: true);
      expect(find.text('Enter your PIN'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('lock-use-password')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'hunter22');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('lock-password-continue')));
      await tester.pumpAndSettle();

      expect(find.text('Choose a new PIN'), findsOneWidget);
      await type(tester, '1357');
      await type(tester, '1357');
      expect(secrets.saved, [(LockSecretKind.pin, '1357')]);
      expect(secrets.password, 'hunter22');
    });
  });
}

/// Away to another app (or the screen off) and back.
Future<void> _backgroundAndBack(WidgetTester tester) async {
  for (final state in const [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  await tester.pump();
}

/// What MainActivity sends when the screen turns off.
Future<void> _screenOff(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    noteLockChannel.name,
    const StandardMethodCodec().encodeMethodCall(const MethodCall('screenOff')),
    (_) {},
  );
  await tester.pump();
}
