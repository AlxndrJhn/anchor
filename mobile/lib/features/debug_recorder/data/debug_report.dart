import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'mp4_muxer.dart';

/// Something that happened while recording, [tMs] after it started:
/// a route change, a touch, a provider update, a log line.
class DebugEvent {
  const DebugEvent(this.tMs, this.type, this.data);

  final int tMs;
  final String type;
  final Map<String, Object?> data;

  Map<String, Object?> toJson() => {'t_ms': tMs, 'type': type, ...data};
}

/// A moment the user marked: "problem here", and what they expected.
class DebugProblem {
  const DebugProblem(this.tMs, this.expectation);

  final int tMs;
  final String expectation;

  Map<String, Object?> toJson() => {
    'type': 'problem',
    't_ms': tMs,
    'timestamp': formatVideoTime(tMs),
    'expectation': expectation,
  };
}

/// A finished recording: the screen's frames and what happened meanwhile.
class DebugRecording {
  const DebugRecording({
    required this.startedAt,
    required this.durationMs,
    required this.frames,
    required this.width,
    required this.height,
    required this.events,
  });

  final DateTime startedAt;
  final int durationMs;
  final List<Mp4Frame> frames;
  final int width;
  final int height;
  final List<DebugEvent> events;
}

/// `mm:ss.s` of a moment in the video.
String formatVideoTime(int ms) {
  final minutes = ms ~/ 60000;
  final seconds = (ms % 60000) / 1000;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toStringAsFixed(1).padLeft(4, '0')}';
}

/// The recording's start, ISO 8601 in UTC to the second:
/// `2026-10-28T14:03:22Z`.
String isoSecond(DateTime time) {
  final iso = time.toUtc().toIso8601String();
  return '${iso.substring(0, 19)}Z';
}

/// `anchor-debug-2026-10-28T14-03-22Z.mp4`: the ISO time, with dashes for
/// the colons no file system minds.
String debugReportFilename(DateTime startedAt) =>
    'anchor-debug-${isoSecond(startedAt).replaceAll(':', '-')}.mp4';

/// The one document a machine reads the whole report from.
Map<String, Object?> debugSummary(
  DebugRecording recording,
  List<DebugProblem> problems, {
  required Map<String, Object?> app,
  required Map<String, Object?> device,
  H264Video? h264,
}) {
  final sorted = [...problems]..sort((a, b) => a.tMs.compareTo(b.tMs));
  return {
    'format': 'anchor-debug/1',
    'app': app,
    'device': device,
    'recording': {
      'started_at': recording.startedAt.toUtc().toIso8601String(),
      'duration_ms': recording.durationMs,
      'frame_count': h264?.samples.length ?? recording.frames.length,
      'video_codec': h264 == null ? 'mjpeg' : 'h264',
      'video_width': h264?.width ?? recording.width,
      'video_height': h264?.height ?? recording.height,
    },
    'problems': [for (final p in sorted) p.toJson()],
    'events': [for (final e in recording.events) e.toJson()],
  };
}

/// The report as one MP4: the video, the events and problems as a timed
/// metadata track, and [debugSummary] in the file's metadata. The video
/// is [h264] when the phone could encode it, else the frames' JPEGs.
Uint8List buildDebugReport(
  DebugRecording recording,
  List<DebugProblem> problems, {
  required Map<String, Object?> app,
  required Map<String, Object?> device,
  H264Video? h264,
}) {
  final summary = debugSummary(
    recording,
    problems,
    app: app,
    device: device,
    h264: h264,
  );
  return muxDebugMp4(
    frames: recording.frames,
    width: recording.width,
    height: recording.height,
    durationMs: recording.durationMs,
    h264: h264,
    events: [
      for (final e in recording.events)
        Mp4MetaSample(tMs: e.tMs, json: jsonEncode(e.toJson())),
      for (final p in problems)
        Mp4MetaSample(tMs: p.tMs, json: jsonEncode(p.toJson())),
    ],
    summary: const JsonEncoder.withIndent('  ').convert(summary),
  );
}

/// GitHub's "new issue" page for [repo], filled in with the problems and
/// a reminder to attach [filename]: the API can't take attachments.
Uri debugIssueUrl({
  required String repo,
  required DateTime startedAt,
  required List<DebugProblem> problems,
  required String filename,
  required String appVersion,
}) {
  final sorted = [...problems]..sort((a, b) => a.tMs.compareTo(b.tMs));
  final body = StringBuffer()
    ..writeln('## Problems')
    ..writeln();
  if (sorted.isEmpty) body.writeln('_None marked._');
  for (final p in sorted) {
    final expectation = p.expectation.trim().replaceAll('\n', ' ');
    body.writeln(
      '- [${formatVideoTime(p.tMs)}] Expectation: '
      '${expectation.isEmpty ? '(not given)' : expectation}',
    );
  }
  body
    ..writeln()
    ..writeln('App version: $appVersion')
    ..writeln()
    ..writeln(
      'Debug package: please attach the saved file `$filename` here '
      '(drag it into this box). It holds the screen recording, the app’s '
      'state over time and the problems above.',
    );
  // Browsers and GitHub cut off long links.
  var text = body.toString();
  if (text.length > 6000) text = '${text.substring(0, 6000)}…';
  return Uri.https('github.com', '/$repo/issues/new', {
    'title': 'Debug report ${isoSecond(startedAt)}',
    'body': text,
  });
}

/// A captured frame, RGBA, as a JPEG; run off the UI isolate.
Uint8List encodeFrameJpeg(
  Uint8List rgba,
  int width,
  int height, {
  int quality = 70,
}) {
  final image = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: rgba.buffer,
    bytesOffset: rgba.offsetInBytes,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return img.encodeJpg(image, quality: quality);
}
