import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:anchor/features/debug_recorder/data/debug_report.dart';
import 'package:anchor/features/debug_recorder/data/mp4_muxer.dart';
import 'package:flutter_test/flutter_test.dart';

/// A [w]×[h] picture in one colour, as RGBA.
Uint8List _rgba(int w, int h, int r, int g, int b) {
  final out = Uint8List(w * h * 4);
  for (var i = 0; i < out.length; i += 4) {
    out
      ..[i] = r
      ..[i + 1] = g
      ..[i + 2] = b
      ..[i + 3] = 255;
  }
  return out;
}

/// The names of the boxes directly inside [start]..[end].
List<String> _children(Uint8List bytes, int start, int end) {
  final names = <String>[];
  var pos = start;
  while (pos + 8 <= end) {
    final size = ByteData.sublistView(bytes, pos, pos + 4).getUint32(0);
    names.add(latin1.decode(bytes.sublist(pos + 4, pos + 8)));
    pos += size;
  }
  return names;
}

DebugRecording _recording() {
  const w = 64, h = 112;
  final times = [0, 180, 410, 600, 830, 1000];
  return DebugRecording(
    startedAt: DateTime.utc(2026, 10, 28, 14, 3, 22),
    durationMs: 1200,
    width: w,
    height: h,
    frames: [
      for (final (i, t) in times.indexed)
        Mp4Frame(
          tMs: t,
          jpeg: encodeFrameJpeg(_rgba(w, h, 40 * i, 100, 255 - 40 * i), w, h),
        ),
    ],
    events: const [
      DebugEvent(0, 'recording', {'action': 'start'}),
      DebugEvent(0, 'route', {'location': '/'}),
      DebugEvent(350, 'pointer', {'action': 'down', 'x': 10.0, 'y': 20.0}),
      DebugEvent(420, 'provider', {'provider': 'notesProvider', 'value': 'x'}),
      DebugEvent(1200, 'recording', {'action': 'stop'}),
    ],
  );
}

Uint8List _report() => buildDebugReport(
  _recording(),
  const [DebugProblem(500, 'The note should open')],
  app: const {'version': '0.17.2', 'build': '22'},
  device: const {'platform': 'android'},
);

void main() {
  test('lays out ftyp, mdat and moov with both tracks', () {
    final mp4 = _report();
    expect(_children(mp4, 0, mp4.length), ['ftyp', 'mdat', 'moov']);

    final moov = findBox(mp4, ['moov'])!;
    expect(_children(mp4, moov.$1, moov.$2), ['mvhd', 'trak', 'trak', 'udta']);

    final videoStsd = findBox(mp4, [
      'moov',
      'trak',
      'mdia',
      'minf',
      'stbl',
      'stsd',
    ])!;
    // Version/flags and the entry count come before the sample entry.
    expect(_children(mp4, videoStsd.$1 + 8, videoStsd.$2), ['jpeg']);

    final hdlrs = latin1.decode(mp4.sublist(moov.$1, moov.$2));
    expect(hdlrs, contains('vide'));
    expect(hdlrs, contains('mett'));
    expect(hdlrs, contains(debugEventsMime));
  });

  test('frame durations add up to the recording', () {
    final mp4 = _report();
    final stts = findBox(mp4, [
      'moov',
      'trak',
      'mdia',
      'minf',
      'stbl',
      'stts',
    ])!;
    final view = ByteData.sublistView(mp4, stts.$1, stts.$2);
    final runs = view.getUint32(4);
    var samples = 0;
    var total = 0;
    for (var i = 0; i < runs; i++) {
      final count = view.getUint32(8 + i * 8);
      samples += count;
      total += count * view.getUint32(12 + i * 8);
    }
    expect(samples, 6);
    expect(total, 1200);
  });

  test('the summary comes back out as JSON', () {
    final summary = jsonDecode(readDebugSummary(_report())!) as Map;
    expect(summary['format'], 'anchor-debug/1');
    expect(summary['recording']['frame_count'], 6);
    expect(summary['recording']['duration_ms'], 1200);
    expect(summary['problems'], [
      {
        'type': 'problem',
        't_ms': 500,
        'timestamp': '00:00.5',
        'expectation': 'The note should open',
      },
    ]);
    expect((summary['events'] as List).length, 5);
  });

  test('ffprobe reads the video, the events and the summary', () async {
    final ffprobe = File('/usr/bin/ffprobe');
    if (!ffprobe.existsSync()) {
      markTestSkipped('ffprobe is not installed');
      return;
    }
    final dir = await Directory.systemTemp.createTemp('anchor-debug');
    addTearDown(() => dir.delete(recursive: true));
    final file = File(
      '${dir.path}/${debugReportFilename(_recording().startedAt)}',
    );
    await file.writeAsBytes(_report());
    // Keep a copy when asked, to look at by hand.
    final keep = Platform.environment['DEBUG_MP4_OUT'];
    if (keep != null) await file.copy(keep);

    final result = await Process.run(ffprobe.path, [
      '-v',
      'error',
      '-show_streams',
      '-show_format',
      '-count_frames',
      '-of',
      'json',
      file.path,
    ]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    final probe = jsonDecode(result.stdout as String) as Map;
    final streams = probe['streams'] as List;
    final video = streams.firstWhere((s) => s['codec_type'] == 'video') as Map;
    expect(video['codec_name'], 'mjpeg');
    expect(video['width'], 64);
    expect(video['height'], 112);
    expect(video['nb_read_frames'], '6');
    expect(double.parse(video['duration'] as String), closeTo(1.2, 0.001));
    expect(streams.where((s) => s['codec_type'] == 'data'), hasLength(1));
    final tags = probe['format']['tags'] as Map;
    final summary = jsonDecode(tags[debugSummaryKey] as String) as Map;
    expect(summary['problems'], hasLength(1));
  });
}
