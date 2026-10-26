import 'package:anchor/core/network/connectivity_provider.dart';
import 'package:anchor/features/notes/domain/note.dart';
import 'package:anchor/features/picture_search/picture_search.dart';
import 'package:anchor/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepository implements PictureSearchRepository {
  final asked = <String>[];

  @override
  Future<List<String>> search(String query) async {
    asked.add(query);
    return ['n-cat'];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _english = lookupAppLocalizations(const Locale('en'));

String? progressOf(PictureSearchStatus status) =>
    pictureSearchProgressText(status, _english);

void main() {
  group('PictureSearchStatus', () {
    test('says when the download failed', () {
      expect(
        progressOf(
          const PictureSearchStatus(
            available: true,
            enabled: true,
            model: PictureModelState.failed,
          ),
        ),
        startsWith('The picture model couldn’t be downloaded.'),
      );
    });

    test('reads the server status', () {
      final status = PictureSearchStatus.fromJson({
        'available': true,
        'enabled': true,
        'model': {'state': 'downloading', 'progress': 0.42},
        'indexed': 0,
        'total': 3,
      });

      expect(status.model, PictureModelState.downloading);
      expect(status.isBusy, isTrue);
      expect(progressOf(status), 'Downloading the picture model… 42%');
    });

    test('says how far it is', () {
      PictureSearchStatus status(int indexed, int total) => PictureSearchStatus(
        available: true,
        enabled: true,
        model: PictureModelState.ready,
        indexed: indexed,
        total: total,
      );

      expect(progressOf(status(1, 4)), 'Looking at your pictures… 1 of 4');
      expect(progressOf(status(1, 1)), 'Your picture is ready to search.');
      expect(progressOf(status(4, 4)), 'All 4 pictures are ready to search.');
      expect(
        progressOf(status(0, 0)),
        'Your pictures will be searchable as you add them.',
      );
      expect(status(4, 4).isBusy, isFalse);
      expect(progressOf(PictureSearchStatus.off), isNull);
    });
  });

  test('notesForMatches keeps their order, leaving out notes shown', () {
    Note note(String id) => Note(id: id, title: id);
    final notes = [note('a'), note('b'), note('c')];

    expect(
      notesForMatches(
        ['c', 'gone', 'a', 'b'],
        notes,
        [notes[1]],
      ).map((n) => n.id),
      ['c', 'a'],
    );
  });

  group('pictureMatches', () {
    ProviderContainer container(
      _FakeRepository repo, {
      required bool on,
      bool online = true,
    }) {
      final c = ProviderContainer(
        overrides: [
          isOnlineProvider.overrideWithValue(online),
          pictureSearchRepositoryProvider.overrideWithValue(repo),
          pictureSearchStatusProvider.overrideWith(
            (ref) async => PictureSearchStatus(available: true, enabled: on),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('asks the server once typing pauses', () async {
      final repo = _FakeRepository();
      final c = container(repo, on: true);

      // Watched, as the notes list does.
      final sub = c.listen(pictureMatchesProvider('zwei katzen'), (_, _) {});
      addTearDown(sub.close);
      final ids = await c.read(pictureMatchesProvider('zwei katzen').future);

      expect(ids, ['n-cat']);
      expect(repo.asked, ['zwei katzen']);
    });

    test('asks nothing when it is off, or for a single letter', () async {
      final repo = _FakeRepository();
      final c = container(repo, on: false);

      expect(await c.read(pictureMatchesProvider('katze').future), isEmpty);
      expect(
        await container(
          repo,
          on: true,
        ).read(pictureMatchesProvider('k').future),
        isEmpty,
      );
      expect(repo.asked, isEmpty);
    });

    test('asks nothing offline', () async {
      final repo = _FakeRepository();
      final c = container(repo, on: true, online: false);

      expect(await c.read(pictureMatchesProvider('katze').future), isEmpty);
      expect(repo.asked, isEmpty);
    });
  });
}
