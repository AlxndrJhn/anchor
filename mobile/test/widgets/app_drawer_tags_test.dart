import 'package:anchor/core/network/server_config_provider.dart';
import 'package:anchor/core/widgets/app_drawer.dart';
import 'package:anchor/features/auth/domain/user.dart';
import 'package:anchor/features/auth/presentation/auth_controller.dart';
import 'package:anchor/features/tags/data/repository/tags_repository.dart';
import 'package:anchor/features/tags/domain/tag.dart' as domain;
import 'package:mocktail/mocktail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class _MockTagsRepository extends Mock implements TagsRepository {}

class _StubAuthController extends AuthController {
  @override
  Future<User?> build() async =>
      const User(id: 'user-1', email: 'me@example.com', name: 'Me');
}

void main() {
  late _MockTagsRepository repo;

  setUp(() {
    repo = _MockTagsRepository();
    when(() => repo.watchTags()).thenAnswer(
      (_) => Stream.value([
        for (final name in ['alpha', 'beta', 'gamma'])
          domain.Tag(id: name, name: name),
      ]),
    );
    when(() => repo.reorderTags(any())).thenAnswer((_) async {});
  });

  Future<void> pumpDrawer(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tagsRepositoryProvider.overrideWithValue(repo),
          authControllerProvider.overrideWith(_StubAuthController.new),
          serverUrlProvider.overrideWith((ref) => null),
        ],
        child: const MaterialApp(home: Scaffold(body: AppDrawer())),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<double> rowsTop(WidgetTester tester) => [
    for (final name in ['alpha', 'beta', 'gamma'])
      tester.getTopLeft(find.text(name)).dy,
  ];

  testWidgets('a tag dragged by its handle moves, and stays there', (
    tester,
  ) async {
    await pumpDrawer(tester);
    final tops = rowsTop(tester);
    final rowHeight = tops[1] - tops[0];

    final handle = find.byIcon(LucideIcons.gripVertical).at(2);
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 50));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(Offset(0, -rowHeight * 2.4 / 10));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    verify(() => repo.reorderTags(['gamma', 'alpha', 'beta'])).called(1);
    // Shown in the new order before the stored one catches up.
    final after = rowsTop(tester);
    expect(after[2], lessThan(after[0]));
  });

  testWidgets('holding a tag name still opens its options', (tester) async {
    await pumpDrawer(tester);

    await tester.longPress(find.text('beta'));
    await tester.pumpAndSettle();

    expect(find.text('Rename tag'), findsOneWidget);
  });
}
