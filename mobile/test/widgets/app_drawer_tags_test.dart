import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/features/auth/domain/user.dart';
import 'package:anchor/features/auth/presentation/auth_controller.dart';
import 'package:anchor/features/notes/presentation/notes_controller.dart';
import 'package:anchor/features/notes/presentation/widgets/app_drawer.dart';
import 'package:anchor/features/tags/data/repository/tags_repository.dart';
import 'package:anchor/features/tags/domain/tag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mocktail/mocktail.dart';

class _MockTagsRepository extends Mock implements TagsRepository {}

class _SignedIn extends AuthController {
  @override
  Future<User?> build() async =>
      const User(id: 'user-1', email: 'me@example.com', name: 'Me');
}

void main() {
  late _MockTagsRepository repo;

  setUpAll(() => registerFallbackValue(const Tag(id: '', name: '')));

  setUp(() {
    repo = _MockTagsRepository();
    when(() => repo.reorderTags(any())).thenAnswer((_) async {});
    when(() => repo.updateTag(any())).thenAnswer((_) async {});
    when(() => repo.getTags()).thenAnswer((_) async => const []);
  });

  Future<void> pumpDrawer(WidgetTester tester, List<Tag> tags) async {
    when(() => repo.watchTags()).thenAnswer((_) => Stream.value(tags));
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tagsRepositoryProvider.overrideWithValue(repo),
          authControllerProvider.overrideWith(_SignedIn.new),
          allActiveNotesProvider.overrideWith((ref) => Stream.value([])),
          archivedNotesProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: AppDrawer(
              onClose: () {},
              onOpenSettings: () {},
              onOpenList: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<Tag> named(List<String> names) => [
    for (final name in names) Tag(id: name, name: name),
  ];

  List<double> topsOf(WidgetTester tester, List<String> names) => [
    for (final name in names) tester.getTopLeft(find.text(name)).dy,
  ];

  testWidgets('a tag dragged by its grip moves, and stays there', (
    tester,
  ) async {
    await pumpDrawer(tester, named(['alpha', 'beta', 'gamma']));
    final tops = topsOf(tester, ['alpha', 'beta', 'gamma']);
    final rowHeight = tops[1] - tops[0];

    final grip = find.byIcon(LucideIcons.gripVertical).at(2);
    final gesture = await tester.startGesture(tester.getCenter(grip));
    await tester.pump(const Duration(milliseconds: 50));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(Offset(0, -rowHeight * 2.4 / 10));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    verify(() => repo.reorderTags(['gamma', 'alpha', 'beta'])).called(1);
    // Shown in the new order before the stored one catches up.
    final after = topsOf(tester, ['alpha', 'beta', 'gamma']);
    expect(after[2], lessThan(after[0]));
  });

  // It used to count as a long press on the tag, and open its options.
  testWidgets('holding the grip still before moving drags the tag', (
    tester,
  ) async {
    await pumpDrawer(tester, named(['alpha', 'beta', 'gamma']));
    final tops = topsOf(tester, ['alpha', 'beta', 'gamma']);
    final rowHeight = tops[1] - tops[0];
    final restingWidth = tester.getSize(find.text('gamma')).width;

    final grip = find.byIcon(LucideIcons.gripVertical).at(2);
    final gesture = await tester.startGesture(tester.getCenter(grip));
    await tester.pump(const Duration(milliseconds: 800));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(Offset(0, -rowHeight * 2.4 / 10));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 300));
    // In hand, the tag is lifted off the list, a little larger.
    final scaled = tester.getRect(find.text('gamma'));
    expect(scaled.width, greaterThan(restingWidth));

    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('#gamma'), findsNothing);
    verify(() => repo.reorderTags(['gamma', 'alpha', 'beta'])).called(1);
  });

  testWidgets('dragged tags come first, the others after by name', (
    tester,
  ) async {
    await pumpDrawer(tester, [
      const Tag(id: 'a', name: 'art'),
      const Tag(id: 'w', name: 'work', position: 0),
      const Tag(id: 'h', name: 'home', position: 1),
      const Tag(id: 'b', name: 'books'),
    ]);

    final tops = topsOf(tester, ['work', 'home', 'art', 'books']);
    expect(tops, orderedEquals([...tops]..sort()));
  });

  testWidgets('each grip is named for screen readers', (tester) async {
    await pumpDrawer(tester, named(['alpha']));

    expect(find.bySemanticsLabel('Move alpha'), findsOneWidget);
  });

  testWidgets('holding a tag name still opens its options', (tester) async {
    await pumpDrawer(tester, named(['alpha', 'beta']));

    await tester.longPress(find.text('beta'));
    await tester.pumpAndSettle();

    expect(find.text('#beta'), findsOneWidget);
    verifyNever(() => repo.reorderTags(any()));
  });

  testWidgets('a colour picked in the options is saved at once', (
    tester,
  ) async {
    await pumpDrawer(tester, named(['alpha', 'beta']));
    await tester.longPress(find.text('beta'));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Teal'));
    await tester.pumpAndSettle();

    final saved = verify(() => repo.updateTag(captureAny())).captured.single;
    expect((saved as Tag).id, 'beta');
    expect(saved.color, isNotNull);
    // The sheet stays open.
    expect(find.text('#beta'), findsOneWidget);
  });
}
