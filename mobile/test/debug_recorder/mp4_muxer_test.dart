import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:anchor/features/debug_recorder/data/debug_report.dart';
import 'package:anchor/features/debug_recorder/data/debug_video_encoder.dart';
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

Uint8List _report({H264Video? h264}) => buildDebugReport(
  _recording(),
  const [DebugProblem(500, 'The note should open')],
  app: const {'version': '0.17.2', 'build': '22'},
  device: const {'platform': 'android'},
  h264: h264,
);

Uint8List _annexB(List<List<int>> nals) => Uint8List.fromList([
  for (final n in nals) ...[0, 0, 0, 1, ...n],
]);

/// A stand-in stream: the bytes only need to look like H.264 to the muxer.
H264Video _fakeH264() => h264FromAnnexB(
  width: 64,
  height: 112,
  sps: _annexB([
    [0x67, 0x42, 0xC0, 0x1E, 0xAA],
  ]),
  pps: _annexB([
    [0x68, 0xCE, 0x3C, 0x80],
  ]),
  samples: [
    _annexB([
      [0x09, 0xF0],
      [0x67, 0x42, 0xC0, 0x1E, 0xAA],
      [0x68, 0xCE, 0x3C, 0x80],
      [0x65, 1, 2, 3],
    ]),
    _annexB([
      [0x41, 4, 5],
    ]),
    _annexB([
      [0x41, 6],
    ]),
  ],
  times: const [0, 400, 800],
  keys: const [true, false, false],
);

/// [name] (ffprobe, ffmpeg) when it's installed, else null.
Future<String?> _tool(String name) async {
  try {
    final r = await Process.run(name, ['-version']);
    return r.exitCode == 0 ? name : null;
  } on ProcessException {
    return null;
  }
}

/// A real H.264 stream of [count] frames of ffmpeg's test pattern, cut
/// into access units the way MediaCodec hands them out.
Future<H264Video> _ffmpegH264(String ffmpeg, Directory dir, int count) async {
  final out = '${dir.path}/test.h264';
  final r = await Process.run(ffmpeg, [
    ...['-v', 'error', '-f', 'lavfi', '-i', 'testsrc=size=64x112:rate=5'],
    ...['-frames:v', '$count', '-pix_fmt', 'yuv420p', '-c:v', 'libx264'],
    ...['-profile:v', 'baseline', '-g', '5', '-x264-params', 'aud=1'],
    ...['-f', 'h264', out],
  ]);
  expect(r.exitCode, 0, reason: '${r.stderr}');
  Uint8List? sps, pps;
  final units = <List<Uint8List>>[];
  for (final nal in splitAnnexB(await File(out).readAsBytes())) {
    final type = nal[0] & 0x1F;
    if (type == 7) sps ??= nal;
    if (type == 8) pps ??= nal;
    if (type == 9) units.add([]);
    units.last.add(nal);
  }
  return h264FromAnnexB(
    width: 64,
    height: 112,
    sps: _annexB([sps!]),
    pps: _annexB([pps!]),
    samples: [for (final u in units) _annexB(u)],
    times: [for (var i = 0; i < units.length; i++) i * 200],
    keys: [for (final u in units) u.any((n) => n[0] & 0x1F == 5)],
  );
}

void main() {
  test('lays out ftyp, moov and mdat with both tracks', () {
    final mp4 = _report();
    expect(_children(mp4, 0, mp4.length), ['ftyp', 'moov', 'mdat']);

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

  test('the index points at the samples', () {
    final mp4 = _report();
    final stco = findBox(mp4, [
      'moov',
      'trak',
      'mdia',
      'minf',
      'stbl',
      'stco',
    ])!;
    final offset = ByteData.sublistView(mp4, stco.$1, stco.$2).getUint32(8);
    expect(offset, findBox(mp4, ['mdat'])!.$1);
    // The first frame's JPEG starts there.
    expect(mp4.sublist(offset, offset + 2), [0xFF, 0xD8]);
  });

  test('an H.264 video gets an avc1 entry and its key frames', () {
    final mp4 = _report(h264: _fakeH264());
    final stbl = findBox(mp4, ['moov', 'trak', 'mdia', 'minf', 'stbl'])!;
    expect(_children(mp4, stbl.$1, stbl.$2), [
      'stsd',
      'stts',
      'stss',
      'stsc',
      'stsz',
      'stco',
    ]);
    final stsd = findBox(mp4, ['stsd'], start: stbl.$1, end: stbl.$2)!;
    expect(_children(mp4, stsd.$1 + 8, stsd.$2), ['avc1']);
    // The sample entry's 78 fixed bytes come before its avcC.
    final avc1 = findBox(mp4, ['avc1'], start: stsd.$1 + 8, end: stsd.$2)!;
    final avcC = findBox(mp4, ['avcC'], start: avc1.$1 + 78, end: avc1.$2)!;
    expect(mp4.sublist(avcC.$1, avcC.$1 + 4), [1, 0x42, 0xC0, 0x1E]);

    final stss = findBox(mp4, ['stss'], start: stbl.$1, end: stbl.$2)!;
    final view = ByteData.sublistView(mp4, stss.$1, stss.$2);
    expect(view.getUint32(4), 1);
    expect(view.getUint32(8), 1);

    final stco = findBox(mp4, ['stco'], start: stbl.$1, end: stbl.$2)!;
    final offset = ByteData.sublistView(mp4, stco.$1, stco.$2).getUint32(8);
    // Parameter sets and the delimiter are gone; the IDR slice remains.
    expect(mp4.sublist(offset, offset + 8), [0, 0, 0, 4, 0x65, 1, 2, 3]);

    final summary = jsonDecode(readDebugSummary(mp4)!) as Map;
    expect(summary['recording']['video_codec'], 'h264');
    expect(summary['recording']['frame_count'], 3);
  });

  test('splits Annex-B on three- and four-byte start codes', () {
    final nals = splitAnnexB(
      Uint8List.fromList([0, 0, 0, 1, 0x67, 1, 0, 0, 1, 0x68, 2, 3]),
    );
    expect(nals, [
      [0x67, 1],
      [0x68, 2, 3],
    ]);
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
    final ffprobe = await _tool('ffprobe');
    if (ffprobe == null) {
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

    final result = await Process.run(ffprobe, [
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

  test('ffmpeg decodes every H.264 frame', () async {
    final ffmpeg = await _tool('ffmpeg');
    final ffprobe = await _tool('ffprobe');
    if (ffmpeg == null || ffprobe == null) {
      markTestSkipped('ffmpeg is not installed');
      return;
    }
    final dir = await Directory.systemTemp.createTemp('anchor-debug');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/h264.mp4');
    await file.writeAsBytes(_report(h264: await _ffmpegH264(ffmpeg, dir, 6)));
    final keep = Platform.environment['DEBUG_H264_MP4_OUT'];
    if (keep != null) await file.copy(keep);

    final result = await Process.run(ffprobe, [
      '-v',
      'error',
      '-show_streams',
      '-count_frames',
      '-of',
      'json',
      file.path,
    ]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect('${result.stderr}'.trim(), isEmpty);
    final probe = jsonDecode(result.stdout as String) as Map;
    final streams = probe['streams'] as List;
    final video = streams.firstWhere((s) => s['codec_type'] == 'video') as Map;
    expect(video['codec_name'], 'h264');
    expect(video['nb_read_frames'], '6');
    expect(double.parse(video['duration'] as String), closeTo(1.2, 0.001));
  });
}
