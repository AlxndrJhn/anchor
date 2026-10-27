import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/network/dio_provider.dart';
import '../notes/domain/note.dart';

part 'picture_search.g.dart';

/// Where the server's picture model is.
enum PictureModelState { absent, downloading, ready, failed }

/// Picture search on the server: whether it's offered, turned on, and how
/// far along it is.
class PictureSearchStatus {
  const PictureSearchStatus({
    required this.available,
    required this.enabled,
    this.model = PictureModelState.absent,
    this.progress = 0,
    this.indexed = 0,
    this.total = 0,
  });

  /// Whether this server offers it at all (PICTURE_SEARCH=off doesn't).
  final bool available;

  /// Whether this user turned it on.
  final bool enabled;
  final PictureModelState model;

  /// The model download, from 0 to 1.
  final double progress;

  /// The user's pictures done, of all of them.
  final int indexed;
  final int total;

  static const off = PictureSearchStatus(available: false, enabled: false);

  factory PictureSearchStatus.fromJson(Map<String, dynamic> json) {
    final model = json['model'] as Map<String, dynamic>? ?? const {};
    return PictureSearchStatus(
      available: json['available'] as bool? ?? false,
      enabled: json['enabled'] as bool? ?? false,
      model: PictureModelState.values.firstWhere(
        (s) => s.name == model['state'],
        orElse: () => PictureModelState.absent,
      ),
      progress: (model['progress'] as num?)?.toDouble() ?? 0,
      indexed: json['indexed'] as int? ?? 0,
      total: json['total'] as int? ?? 0,
    );
  }

  /// Still downloading or looking at pictures: worth asking again soon.
  bool get isBusy =>
      enabled && (model == PictureModelState.downloading || indexed < total);

  /// Where indexing is, in a few words.
  String? get progressText {
    if (!enabled) return null;
    if (model == PictureModelState.downloading) {
      return 'Downloading the picture model… ${(progress * 100).round()}%';
    }
    if (model == PictureModelState.failed) {
      return 'The picture model couldn’t be downloaded. '
          'Turn it off and on to try again.';
    }
    if (indexed < total) return 'Looking at your pictures… $indexed of $total';
    return total == 1
        ? 'Your picture is ready to search.'
        : 'All $total pictures are ready to search.';
  }
}

/// A word for what a picture shows, in English and German.
class PictureLabel {
  const PictureLabel({required this.en, required this.de, this.score = 0});

  factory PictureLabel.fromJson(Map<String, dynamic> json) => PictureLabel(
    en: json['en'] as String? ?? '',
    de: json['de'] as String? ?? '',
    score: (json['score'] as num?)?.toDouble() ?? 0,
  );

  final String en;
  final String de;
  final double score;

  /// In the reader's language: German for German, else English.
  String textFor(String languageCode) => languageCode == 'de' ? de : en;
}

@riverpod
PictureSearchRepository pictureSearchRepository(Ref ref) =>
    PictureSearchRepository(ref.watch(dioProvider));

class PictureSearchRepository {
  PictureSearchRepository(this._dio);

  final Dio _dio;

  Future<PictureSearchStatus> status() async {
    final response = await _dio.get('/api/picture-search/status');
    return PictureSearchStatus.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PictureSearchStatus> setEnabled(bool enabled) async {
    final response = await _dio.put(
      '/api/picture-search/settings',
      data: {'enabled': enabled},
    );
    return PictureSearchStatus.fromJson(response.data as Map<String, dynamic>);
  }

  /// What a picture shows, best first ("Show detected tags").
  Future<List<PictureLabel>> labels(String attachmentId) async {
    final response = await _dio.get(
      '/api/picture-search/attachments/$attachmentId/labels',
    );
    final labels = (response.data as Map<String, dynamic>)['labels'] as List;
    return [
      for (final label in labels.cast<Map<String, dynamic>>())
        PictureLabel.fromJson(label),
    ];
  }

  /// The ids of notes whose pictures look like [query], best first.
  Future<List<String>> search(String query) async {
    final response = await _dio.get(
      '/api/picture-search',
      queryParameters: {'q': query},
    );
    final results = (response.data as Map<String, dynamic>)['results'] as List;
    return [
      for (final match in results.cast<Map<String, dynamic>>())
        match['noteId'] as String,
    ];
  }
}

/// The server's picture search status; off when it can't be reached (an
/// older server, or offline).
@riverpod
Future<PictureSearchStatus> pictureSearchStatus(Ref ref) async {
  try {
    return await ref.watch(pictureSearchRepositoryProvider).status();
  } on DioException {
    return PictureSearchStatus.off;
  }
}

/// How long typing pauses before the server is asked.
const pictureSearchPause = Duration(milliseconds: 400);

/// The ids of notes whose pictures look like [query], for users who turned
/// picture search on, while online; none otherwise.
@riverpod
Future<List<String>> pictureMatches(Ref ref, String query) async {
  final q = query.trim();
  if (q.length < 2) return const [];
  final status = await ref.watch(pictureSearchStatusProvider.future);
  if (!status.enabled) return const [];
  // Asked once typing pauses: a newer query disposes this one meanwhile.
  var disposed = false;
  ref.onDispose(() => disposed = true);
  await Future<void>.delayed(pictureSearchPause);
  if (disposed) return const [];
  try {
    return await ref.read(pictureSearchRepositoryProvider).search(q);
  } on DioException {
    return const [];
  }
}

/// The notes [matches] name, in their order, leaving out those [shown].
List<Note> notesForMatches(
  List<String> matches,
  Iterable<Note> notes,
  Iterable<Note> shown,
) {
  final byId = {for (final n in notes) n.id: n};
  final already = {for (final n in shown) n.id};
  return [
    for (final id in matches)
      if (byId[id] case final note? when !already.contains(id)) note,
  ];
}
