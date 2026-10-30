import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../../../core/logging/app_logger.dart';
import 'mp4_muxer.dart';

const _channel = MethodChannel('anchor/video');
const _tag = 'DebugRecorder';

/// The recording's [frames] as H.264, encoded by the phone, or null where
/// that isn't possible: the report then keeps its Motion-JPEG, which
/// players other than browsers still show.
Future<H264Video?> encodeH264(List<Mp4Frame> frames) async {
  if (!Platform.isAndroid || frames.isEmpty) return null;
  try {
    final raw = await _channel.invokeMapMethod<String, Object?>('encodeH264', {
      'jpegs': [for (final f in frames) f.jpeg],
      'times': [for (final f in frames) f.tMs],
    });
    if (raw == null) return null;
    return h264FromAnnexB(
      width: raw['width'] as int,
      height: raw['height'] as int,
      sps: raw['sps'] as Uint8List,
      pps: raw['pps'] as Uint8List,
      samples: (raw['samples'] as List).cast<Uint8List>(),
      times: (raw['times'] as List).cast<int>(),
      keys: (raw['keys'] as List).cast<bool>(),
    );
  } catch (e) {
    AppLogger.instance.warn(_tag, 'Encoding H.264 failed: $e');
    return null;
  }
}

/// An encoder's output, start codes and all, the way MP4 stores it:
/// parameter sets on their own, each sample's NAL units length-prefixed.
H264Video h264FromAnnexB({
  required int width,
  required int height,
  required Uint8List sps,
  required Uint8List pps,
  required List<Uint8List> samples,
  required List<int> times,
  required List<bool> keys,
}) {
  final out = <H264Sample>[];
  for (var i = 0; i < samples.length; i++) {
    final b = BytesBuilder(copy: false);
    for (final nal in splitAnnexB(samples[i])) {
      // Parameter sets live in the sample entry, delimiters nowhere.
      final type = nal[0] & 0x1F;
      if (type == 7 || type == 8 || type == 9) continue;
      b
        ..add((ByteData(4)..setUint32(0, nal.length)).buffer.asUint8List())
        ..add(nal);
    }
    if (b.isEmpty) continue;
    out.add(H264Sample(tMs: times[i], data: b.takeBytes(), key: keys[i]));
  }
  return H264Video(
    width: width,
    height: height,
    sps: splitAnnexB(sps).first,
    pps: splitAnnexB(pps).first,
    samples: out,
  );
}

/// The NAL units of an Annex-B stream, without their start codes. Bytes
/// with no start code at all are one unit.
List<Uint8List> splitAnnexB(Uint8List bytes) {
  final starts = <int>[]; // where each unit's payload begins
  final ends = <int>[]; // where each start code begins
  for (var i = 0; i + 2 < bytes.length; i++) {
    if (bytes[i] == 0 && bytes[i + 1] == 0 && bytes[i + 2] == 1) {
      ends.add(i > 0 && bytes[i - 1] == 0 ? i - 1 : i);
      starts.add(i + 3);
      i += 2;
    }
  }
  if (starts.isEmpty) return bytes.isEmpty ? const [] : [bytes];
  return [
    for (var n = 0; n < starts.length; n++)
      if ((n + 1 < ends.length ? ends[n + 1] : bytes.length) > starts[n])
        Uint8List.sublistView(
          bytes,
          starts[n],
          n + 1 < ends.length ? ends[n + 1] : bytes.length,
        ),
  ];
}
