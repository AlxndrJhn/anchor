import 'dart:ffi' show Abi;

/// This build's number in the fork's releases (the CI run that built it), and
/// the GitHub repository it updates from. Set by the release workflow; a
/// build without them (local, upstream) doesn't update itself.
const installedBuild = int.fromEnvironment('FORK_BUILD');
const updateRepository = String.fromEnvironment('UPDATE_REPO');

/// The APK in a release for this phone's processor.
String apkAssetForThisPhone() => apkAssetFor(Abi.current());

/// The APK in a release for a processor.
String apkAssetFor(Abi abi) => switch (abi) {
  Abi.androidArm => 'anchor-fork-armeabi-v7a.apk',
  Abi.androidX64 => 'anchor-fork-x86_64.apk',
  _ => 'anchor-fork.apk',
};

/// Whether a server's image is the fork's preview one, whose users may get
/// release candidates.
bool isPreviewImage(String? image) =>
    image != null && image.endsWith(':fork-preview');

/// The build number in a release tag: `fork-0.17.2.22` is build 22.
int? buildOfTag(String tag) {
  if (!tag.startsWith('fork-')) return null;
  return int.tryParse(tag.substring(tag.lastIndexOf('.') + 1));
}

/// A newer release than the installed build, with what changed since it.
class AppRelease {
  const AppRelease({
    required this.tag,
    required this.build,
    required this.apkUrl,
    required this.apkSize,
    required this.pageUrl,
    required this.changes,
  });

  final String tag;
  final int build;
  final String apkUrl;
  final int apkSize;
  final String pageUrl;

  /// What changed in every release since the installed one, newest first.
  final List<String> changes;
}

/// The change lines in a release's notes: the list under "## Changes",
/// without the commit hashes.
List<String> changesInNotes(String notes) {
  final changes = <String>[];
  var inChanges = false;
  for (final line in notes.split('\n')) {
    if (line.startsWith('#')) {
      if (inChanges) break;
      inChanges = line.trim() == '## Changes';
    } else if (inChanges && line.startsWith('- ')) {
      changes.add(
        line.substring(2).replaceFirst(RegExp(r'\s*\([0-9a-f]{7,}\)$'), ''),
      );
    }
  }
  return changes;
}

/// The newest release in GitHub's list that is newer than [installed] and
/// has an APK named [asset]; null when there is none. Its changes gather
/// those of every release in between. Release candidates (prereleases) count
/// only with [candidates].
AppRelease? newestRelease(
  List<Object?> releases, {
  required int installed,
  required String asset,
  bool candidates = false,
}) {
  final newer = <({int build, Map<String, Object?> json})>[];
  for (final item in releases) {
    if (item is! Map<String, Object?>) continue;
    if (item['draft'] == true) continue;
    if (item['prerelease'] == true && !candidates) continue;
    final build = buildOfTag(item['tag_name'] as String? ?? '');
    if (build != null && build > installed) {
      newer.add((build: build, json: item));
    }
  }
  newer.sort((a, b) => b.build.compareTo(a.build));

  for (final (i, candidate) in newer.indexed) {
    final assets = candidate.json['assets'] as List<Object?>? ?? const [];
    final apk = assets.whereType<Map<String, Object?>>().where(
      (a) => a['name'] == asset,
    );
    if (apk.isEmpty) continue;
    return AppRelease(
      tag: candidate.json['tag_name'] as String,
      build: candidate.build,
      apkUrl: apk.first['browser_download_url'] as String,
      apkSize: (apk.first['size'] as num?)?.toInt() ?? 0,
      pageUrl: candidate.json['html_url'] as String? ?? '',
      changes: [
        for (final r in newer.skip(i))
          ...changesInNotes(r.json['body'] as String? ?? ''),
      ],
    );
  }
  return null;
}
