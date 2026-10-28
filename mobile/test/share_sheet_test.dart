import 'package:anchor/core/network/connectivity_provider.dart';
import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/widgets/pill.dart';
import 'package:anchor/features/auth/domain/user.dart';
import 'package:anchor/features/auth/presentation/auth_controller.dart';
import 'package:anchor/features/notes/data/repository/note_shares_repository.dart';
import 'package:anchor/features/notes/data/repository/users_repository.dart';
import 'package:anchor/features/notes/domain/note.dart';
import 'package:anchor/features/notes/domain/note_share.dart';
import 'package:anchor/features/notes/domain/note_share_permission.dart';
import 'package:anchor/features/notes/domain/user_summary.dart';
import 'package:anchor/features/notes/presentation/notes_controller.dart';
import 'package:anchor/features/notes/presentation/widgets/share_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const me = User(id: 'me', email: 'mia@example.com', name: 'Mia Mobile');
const leo = UserSummary(id: 'leo', name: 'Leo Novak', email: 'leo@example.com');
const sam = UserSummary(
  id: 'sam',
  name: 'Sam Carter',
  email: 'sam@example.com',
);
const pat = UserSummary(
  id: 'pat',
  name: 'Pat Partner',
  email: 'pat@example.com',
);

NoteShare shareWith(UserSummary user, [NoteSharePermission? permission]) =>
    NoteShare(
      id: 'share-${user.id}',
      sharedWithUser: user,
      permission: permission ?? NoteSharePermission.editor,
      createdAt: '2026-10-01T00:00:00Z',
      updatedAt: '2026-10-01T00:00:00Z',
    );

class FakeShares implements NoteSharesRepository {
  FakeShares(this.shares);

  List<NoteShare> shares;
  int reads = 0;
  bool isFailing = false;
  final added = <(String, NoteSharePermission)>[];
  final revoked = <String>[];

  @override
  Future<List<NoteShare>> getNoteShares(String noteId) async {
    reads++;
    if (isFailing) throw Exception('server unreachable');
    return [...shares];
  }

  @override
  Future<NoteShare> shareNote(
    String noteId,
    String sharedWithUserId,
    NoteSharePermission permission,
  ) async {
    added.add((sharedWithUserId, permission));
    final user = [leo, sam, pat].firstWhere((u) => u.id == sharedWithUserId);
    final share = shareWith(user, permission);
    shares = [...shares, share];
    return share;
  }

  @override
  Future<NoteShare> updateNoteSharePermission(
    String noteId,
    String shareId,
    NoteSharePermission permission,
  ) async {
    final share = shares.firstWhere((s) => s.id == shareId);
    return share.copyWith(permission: permission);
  }

  @override
  Future<void> revokeShare(String noteId, String shareId) async {
    revoked.add(shareId);
    shares = shares.where((s) => s.id != shareId).toList();
  }
}

class FakeUsers implements UsersRepository {
  final searches = <String>[];

  @override
  Future<List<UserSummary>> searchUsers(String query) async {
    searches.add(query);
    final term = query.toLowerCase();
    return [
      for (final u in [leo, sam, pat])
        if (u.name.toLowerCase().contains(term)) u,
    ];
  }

  @override
  Future<List<UserSummary>> getRecentContacts() async => [sam, pat];
}

class SignedIn extends AuthController {
  @override
  Future<User?> build() async => me;
}

class Online extends Notifier<bool> {
  Online(this.initial);

  final bool initial;

  @override
  bool build() => initial;

  void set(bool value) => state = value;
}

void main() {
  late FakeShares shares;
  late FakeUsers users;
  late NotifierProvider<Online, bool> online;

  setUp(() {
    shares = FakeShares([shareWith(pat)]);
    users = FakeUsers();
  });

  Future<ProviderContainer> openSheet(
    WidgetTester tester, {
    bool isOnline = true,
    List<String> syncedShareIds = const ['pat'],
    ProviderContainer? container,
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    online = NotifierProvider<Online, bool>(() => Online(isOnline));
    final scope =
        container ??
        ProviderContainer(
          overrides: [
            isOnlineProvider.overrideWith((ref) => ref.watch(online)),
            noteSharesRepositoryProvider.overrideWithValue(shares),
            usersRepositoryProvider.overrideWithValue(users),
            authControllerProvider.overrideWith(SignedIn.new),
            noteProvider('n1').overrideWith(
              (ref) => Stream.value(
                Note(id: 'n1', title: 'Lisbon trip', shareIds: syncedShareIds),
              ),
            ),
          ],
        );
    if (container == null) addTearDown(scope.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: scope,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showShareSheet(context, noteId: 'n1'),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return scope;
  }

  final field = find.byType(TextField);

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(field, text);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  }

  Future<void> drainSnackbar(WidgetTester tester) =>
      tester.pump(const Duration(seconds: 11));

  /// pumpAndSettle would wait out a snackbar's timer.
  Future<void> settleUnderSnackbar(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  double topOf(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text)).dy;

  testWidgets('an empty field suggests people you share with, above the '
      'people who have access', (tester) async {
    await openSheet(tester);
    expect(find.text('RECENTLY SHARED WITH'), findsNothing);

    await tester.tap(field);
    await tester.pumpAndSettle();

    expect(find.text('RECENTLY SHARED WITH'), findsOneWidget);
    expect(find.text('Sam Carter'), findsOneWidget);
    expect(find.text('Pat Partner'), findsOneWidget, reason: 'already on it');
    expect(
      topOf(tester, 'RECENTLY SHARED WITH'),
      lessThan(topOf(tester, 'PEOPLE WITH ACCESS')),
    );
  });

  testWidgets('the line between people starts at their names', (tester) async {
    await openSheet(tester);

    final lines = tester.widgetList<Container>(
      find.byWidgetPredicate(
        (widget) => widget is Container && widget.constraints?.maxHeight == 1,
      ),
    );
    expect(lines, isNotEmpty);
    expect(
      tester.getTopLeft(find.byWidget(lines.last)).dx,
      tester.getTopLeft(find.text('Pat Partner')).dx,
    );
  });

  testWidgets('typed matches show under People, and People with access stays', (
    tester,
  ) async {
    await openSheet(tester);
    await type(tester, 'le');

    expect(users.searches, ['le']);
    expect(find.text('PEOPLE'), findsOneWidget);
    expect(find.text('RECENTLY SHARED WITH'), findsNothing);
    expect(find.bySemanticsLabel('Add Leo Novak'), findsOneWidget);
    expect(find.text('PEOPLE WITH ACCESS'), findsOneWidget);
    expect(topOf(tester, 'PEOPLE'), lessThan(topOf(tester, 'Leo Novak')));
    expect(
      topOf(tester, 'Leo Novak'),
      lessThan(topOf(tester, 'PEOPLE WITH ACCESS')),
    );
  });

  testWidgets('one letter waits for a second before searching', (tester) async {
    await openSheet(tester);
    await type(tester, 'l');

    expect(users.searches, isEmpty);
    expect(find.text('RECENTLY SHARED WITH'), findsOneWidget);
  });

  testWidgets('no match says who can be added', (tester) async {
    await openSheet(tester);
    await type(tester, 'zed');

    expect(
      find.text(
        'No one found. Only people with an account on this server can be '
        'added.',
      ),
      findsOneWidget,
    );
    expect(find.text('PEOPLE WITH ACCESS'), findsOneWidget);
  });

  testWidgets('Enter adds the first match, who lands under People with '
      'access as Can view', (tester) async {
    await openSheet(tester);
    await type(tester, 'leo');

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settleUnderSnackbar(tester);

    expect(shares.added, [('leo', NoteSharePermission.viewer)]);
    expect(find.text('Shared with Leo'), findsOneWidget);
    expect(find.bySemanticsLabel('Add Leo Novak'), findsNothing);
    expect(find.text('Leo Novak'), findsOneWidget);
    expect(
      topOf(tester, 'PEOPLE WITH ACCESS'),
      lessThan(topOf(tester, 'Leo Novak')),
    );
    expect(
      find.bySemanticsLabel(RegExp(r'^Can view\. Change access for Leo')),
      findsOneWidget,
    );
    await drainSnackbar(tester);
  });

  testWidgets('a tapped suggestion is added', (tester) async {
    await openSheet(tester);
    await tester.tap(field);
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Add Sam Carter'));
    await settleUnderSnackbar(tester);

    expect(shares.added, [('sam', NoteSharePermission.viewer)]);
    expect(find.bySemanticsLabel('Add Sam Carter'), findsNothing);
    expect(
      find.bySemanticsLabel(RegExp(r'^Can view\. Change access for Sam')),
      findsOneWidget,
    );
    await drainSnackbar(tester);
  });

  testWidgets('changing access says so', (tester) async {
    await openSheet(tester);

    await tester.tap(find.bySemanticsLabel(RegExp('Change access for Pat')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Can view'));
    await settleUnderSnackbar(tester);

    expect(find.text('Pat can now view'), findsOneWidget);
    expect(find.widgetWithText(Pill, 'Can view'), findsOneWidget);
    await drainSnackbar(tester);
  });

  testWidgets('Remove hides the person and waits for the snackbar to close', (
    tester,
  ) async {
    await openSheet(tester, syncedShareIds: const []);

    await tester.tap(find.bySemanticsLabel(RegExp('Change access for Pat')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await settleUnderSnackbar(tester);

    expect(find.text('Pat Partner'), findsNothing);
    expect(find.text('Only you can see this note.'), findsOneWidget);
    expect(shares.revoked, isEmpty);

    await drainSnackbar(tester);
    await tester.pumpAndSettle();
    expect(shares.revoked, ['share-pat']);
  });

  testWidgets('offline, the people from the last answer still show and wait', (
    tester,
  ) async {
    final container = await openSheet(tester);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    container.read(online.notifier).set(false);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(
      find.text('Connect to the internet to share this note.'),
      findsOneWidget,
    );
    expect(find.text('Pat Partner'), findsOneWidget);
    expect(tester.widget<TextField>(field).enabled, isFalse);
    final pill = find.ancestor(
      of: find.widgetWithText(Pill, 'Can edit'),
      matching: find.byType(PillButton),
    );
    expect(tester.widget<PillButton>(pill).onPressed, isNull);
    expect(find.text('Only you can see this note.'), findsNothing);
  });

  testWidgets('offline with nothing fetched yet, it counts the people', (
    tester,
  ) async {
    await openSheet(tester, isOnline: false, syncedShareIds: ['pat', 'leo']);

    expect(shares.reads, 0);
    expect(
      find.text('Shared with 2 people. Connect to see who has access.'),
      findsOneWidget,
    );
    expect(find.text('Only you can see this note.'), findsNothing);
  });

  testWidgets('people that don’t load say so, and Try again loads them', (
    tester,
  ) async {
    shares.isFailing = true;
    await openSheet(tester);

    expect(find.text('Couldn’t load the people with access.'), findsOneWidget);
    expect(find.text('Shared with 1 person.'), findsNothing);
    expect(find.text('Pat Partner'), findsNothing);

    shares.isFailing = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Couldn’t load the people with access.'), findsNothing);
    expect(find.text('Pat Partner'), findsOneWidget);
  });

  testWidgets('back online, the people and suggestions load', (tester) async {
    final container = await openSheet(tester, isOnline: false);
    expect(find.text('Pat Partner'), findsNothing);

    container.read(online.notifier).set(true);
    await tester.pumpAndSettle();

    expect(find.text('Pat Partner'), findsOneWidget);
    expect(tester.widget<TextField>(field).enabled, isTrue);
    await tester.tap(field);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Add Sam Carter'), findsOneWidget);
  });
}
