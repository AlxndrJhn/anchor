import 'dart:convert';
import 'dart:typed_data';

/// One picture of the recording, as a JPEG, shown from [tMs] on.
class Mp4Frame {
  const Mp4Frame({required this.tMs, required this.jpeg});

  final int tMs;
  final Uint8List jpeg;
}

/// One sample of the metadata track: the JSON of what happened at [tMs].
class Mp4MetaSample {
  const Mp4MetaSample({required this.tMs, required this.json});

  final int tMs;
  final String json;
}

/// One coded picture of an H.264 stream: its NAL units, each prefixed
/// with its length in 4 bytes, shown from [tMs] on.
class H264Sample {
  const H264Sample({required this.tMs, required this.data, required this.key});

  final int tMs;
  final Uint8List data;

  /// Decodable on its own: where a player can start.
  final bool key;
}

/// A recording encoded as H.264, the codec browsers play.
class H264Video {
  const H264Video({
    required this.width,
    required this.height,
    required this.sps,
    required this.pps,
    required this.samples,
  });

  final int width;
  final int height;

  /// The sequence and picture parameter sets, without start codes.
  final Uint8List sps;
  final Uint8List pps;
  final List<H264Sample> samples;
}

/// The key the summary document is stored under, in the file's metadata.
/// `ffprobe` shows it as a format tag of that name.
const debugSummaryKey = 'com.anchor.debug';

/// The metadata track's MIME type, in its `mett` sample entry.
const debugEventsMime = 'application/json';

/// Writes an MP4 (ISO-BMFF) file of two tracks:
///
/// * video: [h264] when given (`avc1`, which browsers play), else the
///   [frames] as Motion-JPEG (`jpeg` samples, which they don't). Each
///   sample lasts until the next one, the last until [durationMs];
/// * timed metadata (`meta` handler, `mett` entry of [debugEventsMime]):
///   the [events], each sample a JSON document lasting until the next.
///
/// [summary] goes into `moov/udta/meta` as a QuickTime `mdta` item under
/// [debugSummaryKey], where ffmpeg reads it as a format tag.
///
/// Layout is `ftyp`, `moov`, `mdat`: the index first, so a browser can
/// start playing before it has the whole file. All times are in
/// milliseconds.
Uint8List muxDebugMp4({
  required List<Mp4Frame> frames,
  required int width,
  required int height,
  required int durationMs,
  H264Video? h264,
  List<Mp4MetaSample> events = const [],
  String? summary,
}) {
  if ((h264?.samples ?? frames).isEmpty) {
    throw ArgumentError.value(frames, 'frames', 'needs at least one frame');
  }
  final duration = durationMs < 1 ? 1 : durationMs;
  final metaSamples = _fillMetaTimeline(events);

  final ftyp = _box('ftyp', [
    _fourcc('isom'),
    _u32(0x200),
    _fourcc('isom'),
    _fourcc('iso2'),
    if (h264 != null) _fourcc('avc1'),
    _fourcc('mp41'),
  ]);

  final List<Uint8List> videoPayloads;
  final List<int> videoStarts;
  final Uint8List sampleEntry;
  final int videoWidth;
  final int videoHeight;
  List<int>? syncSamples;
  if (h264 != null) {
    videoPayloads = [for (final s in h264.samples) s.data];
    videoStarts = [for (final s in h264.samples) s.tMs];
    videoWidth = h264.width;
    videoHeight = h264.height;
    sampleEntry = _avc1Entry(h264);
    // Without an stss every sample counts as a key frame.
    if (h264.samples.any((s) => !s.key)) {
      syncSamples = [
        for (final (i, s) in h264.samples.indexed)
          if (s.key) i + 1,
      ];
    }
  } else {
    videoPayloads = [for (final f in frames) f.jpeg];
    videoStarts = [for (final f in frames) f.tMs];
    videoWidth = width;
    videoHeight = height;
    sampleEntry = _jpegEntry(width, height);
  }

  // mdat: every frame, then every event, back to back.
  final metaPayloads = [for (final s in metaSamples) utf8.encode(s.json)];
  var mdatPayload = 0;
  for (final v in videoPayloads) {
    mdatPayload += v.length;
  }
  for (final m in metaPayloads) {
    mdatPayload += m.length;
  }
  final videoDurations = _durations(videoStarts, duration);
  final metaDurations = _durations([
    for (final s in metaSamples) s.tMs,
  ], duration);

  // The offsets don't change the index's size: build it once to measure
  // it, then again with the samples where they end up.
  Uint8List moov(int videoOffset) {
    var metaOffset = videoOffset;
    for (final v in videoPayloads) {
      metaOffset += v.length;
    }
    return _box('moov', [
      _mvhd(duration, nextTrackId: 3),
      _trak(
        trackId: 1,
        duration: duration,
        width: videoWidth,
        height: videoHeight,
        handler: 'vide',
        handlerName: 'Anchor screen',
        mediaHeader: _fullBox('vmhd', 0, 1, [
          _u16(0),
          _u16(0),
          _u16(0),
          _u16(0),
        ]),
        sampleEntry: sampleEntry,
        durations: videoDurations,
        sizes: [for (final v in videoPayloads) v.length],
        chunkOffset: videoOffset,
        syncSamples: syncSamples,
      ),
      if (metaSamples.isNotEmpty)
        _trak(
          trackId: 2,
          duration: duration,
          width: 0,
          height: 0,
          handler: 'meta',
          handlerName: 'Anchor state',
          mediaHeader: _fullBox('nmhd', 0, 0, const []),
          sampleEntry: _mettEntry(),
          durations: metaDurations,
          sizes: [for (final m in metaPayloads) m.length],
          chunkOffset: metaOffset,
          // The events describe the video track.
          reference: _box('tref', [
            _box('cdsc', [_u32(1)]),
          ]),
        ),
      if (summary != null) _udta(summary),
    ]);
  }

  final index = moov(ftyp.length + moov(0).length + 8);
  final out = BytesBuilder(copy: false)
    ..add(ftyp)
    ..add(index)
    ..add(_u32(mdatPayload + 8))
    ..add(_fourcc('mdat'));
  for (final v in videoPayloads) {
    out.add(v);
  }
  for (final m in metaPayloads) {
    out.add(m);
  }
  return out.takeBytes();
}

/// Events at the same millisecond share a sample (a JSON array), and an
/// empty array covers the time before the first one: a metadata track has
/// no gaps.
List<Mp4MetaSample> _fillMetaTimeline(List<Mp4MetaSample> events) {
  if (events.isEmpty) return const [];
  final sorted = [...events]..sort((a, b) => a.tMs.compareTo(b.tMs));
  final out = <Mp4MetaSample>[];
  if (sorted.first.tMs > 0) out.add(const Mp4MetaSample(tMs: 0, json: '[]'));
  var i = 0;
  while (i < sorted.length) {
    final t = sorted[i].tMs < 0 ? 0 : sorted[i].tMs;
    final group = <String>[];
    while (i < sorted.length && (sorted[i].tMs < 0 ? 0 : sorted[i].tMs) == t) {
      group.add(sorted[i].json);
      i++;
    }
    out.add(Mp4MetaSample(tMs: t, json: '[${group.join(',')}]'));
  }
  return out;
}

/// How long each sample lasts: until the next one starts, the last one
/// until [total]. The first one starts at 0 whenever it was taken.
List<int> _durations(List<int> starts, int total) {
  final out = <int>[];
  for (var i = 0; i < starts.length; i++) {
    final start = i == 0 ? 0 : starts[i];
    final end = i + 1 < starts.length ? starts[i + 1] : total;
    out.add(end - start < 1 ? 1 : end - start);
  }
  return out;
}

Uint8List _trak({
  required int trackId,
  required int duration,
  required int width,
  required int height,
  required String handler,
  required String handlerName,
  required Uint8List mediaHeader,
  required Uint8List sampleEntry,
  required List<int> durations,
  required List<int> sizes,
  required int chunkOffset,
  Uint8List? reference,
  List<int>? syncSamples,
}) {
  final mediaDuration = durations.fold<int>(0, (a, b) => a + b);
  return _box('trak', [
    _tkhd(trackId, duration, width, height, isVideo: handler == 'vide'),
    ?reference,
    _box('mdia', [
      _fullBox('mdhd', 0, 0, [
        _u32(0),
        _u32(0),
        _u32(1000),
        _u32(mediaDuration),
        _u16(0x55C4), // "und"
        _u16(0),
      ]),
      _fullBox('hdlr', 0, 0, [
        _u32(0),
        _fourcc(handler),
        _u32(0),
        _u32(0),
        _u32(0),
        _cString(handlerName),
      ]),
      _box('minf', [
        mediaHeader,
        _box('dinf', [
          _fullBox('dref', 0, 0, [
            _u32(1),
            _fullBox('url ', 0, 1, const []), // samples are in this file
          ]),
        ]),
        _box('stbl', [
          _fullBox('stsd', 0, 0, [_u32(1), sampleEntry]),
          _stts(durations),
          if (syncSamples != null)
            _fullBox('stss', 0, 0, [
              _u32(syncSamples.length),
              for (final s in syncSamples) _u32(s),
            ]),
          _fullBox('stsc', 0, 0, [
            _u32(1),
            _u32(1), // first chunk
            _u32(sizes.length), // all samples in one chunk
            _u32(1), // sample description
          ]),
          _fullBox('stsz', 0, 0, [
            _u32(0),
            _u32(sizes.length),
            for (final s in sizes) _u32(s),
          ]),
          _fullBox('stco', 0, 0, [_u32(1), _u32(chunkOffset)]),
        ]),
      ]),
    ]),
  ]);
}

/// Sample durations, run-length encoded.
Uint8List _stts(List<int> durations) {
  final runs = <List<int>>[];
  for (final d in durations) {
    if (runs.isNotEmpty && runs.last[1] == d) {
      runs.last[0]++;
    } else {
      runs.add([1, d]);
    }
  }
  return _fullBox('stts', 0, 0, [
    _u32(runs.length),
    for (final r in runs) ...[_u32(r[0]), _u32(r[1])],
  ]);
}

Uint8List _mvhd(int duration, {required int nextTrackId}) =>
    _fullBox('mvhd', 0, 0, [
      _u32(0),
      _u32(0),
      _u32(1000),
      _u32(duration),
      _u32(0x00010000), // rate 1.0
      _u16(0x0100), // volume 1.0
      Uint8List(10),
      _matrix(),
      Uint8List(24),
      _u32(nextTrackId),
    ]);

Uint8List _tkhd(
  int trackId,
  int duration,
  int width,
  int height, {
  required bool isVideo,
}) => _fullBox('tkhd', 0, isVideo ? 3 : 1, [
  _u32(0),
  _u32(0),
  _u32(trackId),
  _u32(0),
  _u32(duration),
  Uint8List(8),
  _u16(0), // layer
  _u16(0), // alternate group
  _u16(0), // volume
  _u16(0),
  _matrix(),
  _u32(width << 16),
  _u32(height << 16),
]);

Uint8List _jpegEntry(int width, int height) => _box('jpeg', [
  Uint8List(6),
  _u16(1), // data reference index
  Uint8List(16),
  _u16(width),
  _u16(height),
  _u32(0x00480000), // 72 dpi
  _u32(0x00480000),
  _u32(0),
  _u16(1), // frames per sample
  _pascal32('Photo - JPEG'),
  _u16(0x18), // depth
  _u16(0xFFFF), // no colour table
]);

Uint8List _avc1Entry(H264Video video) => _box('avc1', [
  Uint8List(6),
  _u16(1), // data reference index
  Uint8List(16),
  _u16(video.width),
  _u16(video.height),
  _u32(0x00480000), // 72 dpi
  _u32(0x00480000),
  _u32(0),
  _u16(1), // frames per sample
  _pascal32(''),
  _u16(0x18), // depth
  _u16(0xFFFF), // no colour table
  _box('avcC', [
    [1, video.sps[1], video.sps[2], video.sps[3]], // version, profile, level
    [0xFF], // 4-byte NAL lengths
    [0xE1], // one SPS
    _u16(video.sps.length),
    video.sps,
    [1], // one PPS
    _u16(video.pps.length),
    video.pps,
  ]),
]);

Uint8List _mettEntry() => _box('mett', [
  Uint8List(6),
  _u16(1),
  _cString(''), // content encoding: none
  _cString(debugEventsMime),
]);

/// The summary as a QuickTime metadata item, the way ffmpeg writes
/// `-movflags use_metadata_tags`.
Uint8List _udta(String summary) => _box('udta', [
  _fullBox('meta', 0, 0, [
    _fullBox('hdlr', 0, 0, [
      _u32(0),
      _fourcc('mdta'),
      _u32(0),
      _u32(0),
      _u32(0),
      Uint8List(1),
    ]),
    _fullBox('keys', 0, 0, [
      _u32(1),
      _box('mdta', [utf8.encode(debugSummaryKey)]),
    ]),
    _box('ilst', [
      _boxOfType(_u32(1), [
        _box('data', [_u32(1), _u32(0), utf8.encode(summary)]), // 1 = UTF-8
      ]),
    ]),
  ]),
]);

/// Reads the summary [muxDebugMp4] stored, or null when there's none.
String? readDebugSummary(Uint8List mp4) {
  final moov = findBox(mp4, ['moov']);
  if (moov == null) return null;
  final meta = findBox(mp4, ['udta', 'meta'], start: moov.$1, end: moov.$2);
  if (meta == null) return null;
  // `meta` is a full box: skip its version and flags.
  final data = findBox(
    mp4,
    ['ilst', '', 'data'],
    start: meta.$1 + 4,
    end: meta.$2,
  );
  if (data == null) return null;
  return utf8.decode(mp4.sublist(data.$1 + 8, data.$2));
}

/// The payload range (start, end) of the box at [path] below [start]..[end];
/// an empty name in [path] matches any box.
(int, int)? findBox(
  Uint8List bytes,
  List<String> path, {
  int start = 0,
  int? end,
}) {
  var from = start;
  var to = end ?? bytes.length;
  for (final name in path) {
    (int, int)? found;
    var pos = from;
    while (pos + 8 <= to) {
      final view = ByteData.sublistView(bytes, pos, pos + 8);
      final size = view.getUint32(0);
      final type = ascii.decode(
        bytes.sublist(pos + 4, pos + 8),
        allowInvalid: true,
      );
      if (size < 8 || pos + size > to) break;
      if (name.isEmpty || type == name) {
        found = (pos + 8, pos + size);
        break;
      }
      pos += size;
    }
    if (found == null) return null;
    (from, to) = found;
  }
  return (from, to);
}

Uint8List _matrix() {
  final m = ByteData(36)
    ..setUint32(0, 0x00010000)
    ..setUint32(16, 0x00010000)
    ..setUint32(32, 0x40000000);
  return m.buffer.asUint8List();
}

Uint8List _box(String type, List<List<int>> parts) =>
    _boxOfType(_fourcc(type), parts);

Uint8List _boxOfType(List<int> type, List<List<int>> parts) {
  var size = 8;
  for (final p in parts) {
    size += p.length;
  }
  final b = BytesBuilder(copy: false)
    ..add(_u32(size))
    ..add(type);
  for (final p in parts) {
    b.add(p);
  }
  return b.takeBytes();
}

Uint8List _fullBox(
  String type,
  int version,
  int flags,
  List<List<int>> parts,
) => _box(type, [_u32((version << 24) | flags), ...parts]);

Uint8List _u32(int v) => (ByteData(4)..setUint32(0, v)).buffer.asUint8List();

Uint8List _u16(int v) => (ByteData(2)..setUint16(0, v)).buffer.asUint8List();

Uint8List _fourcc(String s) => Uint8List.fromList(ascii.encode(s));

Uint8List _cString(String s) => Uint8List.fromList([...utf8.encode(s), 0]);

/// A 32-byte Pascal string, as a sample entry's compressor name.
Uint8List _pascal32(String s) {
  final bytes = ascii.encode(s);
  return Uint8List(32)
    ..[0] = bytes.length
    ..setRange(1, 1 + bytes.length, bytes);
}
