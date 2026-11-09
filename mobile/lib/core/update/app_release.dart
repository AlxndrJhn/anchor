import 'dart:ffi' show Abi;

/// This build's number in the releases (the CI run that built it), and the
/// GitHub repository it updates from. Set by the release workflow; a build
/// without them (local, F-Droid) doesn't update itself.
const installedBuild = int.fromEnvironment('RELEASE_BUILD');
const updateRepository = String.fromEnvironment('UPDATE_REPO');

/// The APK in a release for this phone's processor.
String apkAssetForThisPhone() => apkAssetFor(Abi.current());

/// The APK in a release for a processor.
String apkAssetFor(Abi abi) => switch (abi) {
  Abi.androidArm => 'anchor-plus-armeabi-v7a.apk',
  Abi.androidX64 => 'anchor-plus-x86_64.apk',
  _ => 'anchor-plus.apk',
};

/// F-Droid and the F-Droid clients, which keep an Anchor+ installed from the
/// project's F-Droid repositories up to date themselves.
const fdroidClients = {
  'org.fdroid.fdroid',
  'org.fdroid.basic',
  'com.looker.droidify',
  'com.machiav3lli.fdroid',
  'eu.bubu1.fdroidclassic',
};

/// Whether the app that installed this one is an F-Droid client.
bool isFdroidClient(String? installer) => fdroidClients.contains(installer);

/// Whether a server's image is the preview one, whose users may get release
/// candidates.
bool isPreviewImage(String? image) =>
    image != null && image.endsWith(':preview');

/// The build number in a release tag: `v0.18.0.81` is build 81.
int? buildOfTag(String tag) {
  final match = RegExp(r'^v\d+\.\d+\.\d+\.(\d+)$').firstMatch(tag);
  return match == null ? null : int.parse(match.group(1)!);
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

/// The Android app's change lines in a release's notes, without the commit
/// hashes: the list under "## Android changes", or, in releases from before
/// that section, every change under "## Changes".
List<String> changesInNotes(String notes) {
  final lines = notes.split('\n');
  final section = lines.any((l) => l.trim() == '## Android changes')
      ? '## Android changes'
      : '## Changes';
  final changes = <String>[];
  var inChanges = false;
  for (final line in lines) {
    if (line.startsWith('#')) {
      if (inChanges) break;
      inChanges = line.trim() == section;
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
