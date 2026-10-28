import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/logging/app_logger.dart';
import 'debug_report.dart';
import 'mp4_muxer.dart';

enum DebugRecorderStatus { idle, recording, reviewing }

/// Debug mode: films the app and notes what happens in it, for at most
/// [maxDuration]. One for the app; everything that reports state checks
/// [isRecording] first, so it costs nothing the rest of the time.
class DebugRecorder extends ChangeNotifier {
  DebugRecorder._();
  static final DebugRecorder instance = DebugRecorder._();

  static const maxDuration = Duration(seconds: 15);
  static const _frameInterval = Duration(milliseconds: 200); // 5 fps
  static const _longSide = 960.0;
  static const _maxEncoding = 3;
  static const _maxValueChars = 300;
  static const _tag = 'DebugRecorder';

  DebugRecorderStatus _status = DebugRecorderStatus.idle;
  DebugRecorderStatus get status => _status;
  bool get isRecording => _status == DebugRecorderStatus.recording;

  final _stopwatch = Stopwatch();
  DateTime _startedAt = DateTime.now();
  final _events = <DebugEvent>[];
  final _frames = <Mp4Frame>[];
  final _encoding = <Future<void>>{};
  Timer? _frameTimer;
  Timer? _limitTimer;
  StreamSubscription<LogEntry>? _logs;
  bool _capturing = false;
  int _width = 0;
  int _height = 0;

  /// Milliseconds since recording started.
  int get elapsedMs => _stopwatch.elapsedMilliseconds;

  /// Starts filming what [boundary] paints. Ends by itself after
  /// [maxDuration], handing the recording to [onFinished].
  void start({
    required RenderRepaintBoundary? Function() boundary,
    required void Function(DebugRecording recording) onFinished,
  }) {
    if (_status != DebugRecorderStatus.idle) return;
    _status = DebugRecorderStatus.recording;
    _events.clear();
    _frames.clear();
    _width = 0;
    _height = 0;
    _startedAt = DateTime.now();
    _stopwatch
      ..reset()
      ..start();
    record('recording', {'action': 'start'});
    _logs = AppLogger.instance.stream.listen(
      (e) => record('log', {
        'level': e.level.name,
        'tag': e.tag,
        'message': truncateValue(e.message),
        if (e.error != null) 'error': truncateValue('${e.error}'),
      }),
    );
    _captureFrame(boundary);
    _frameTimer = Timer.periodic(
      _frameInterval,
      (_) => _captureFrame(boundary),
    );
    _limitTimer = Timer(maxDuration, () => stop(onFinished));
    notifyListeners();
  }

  /// Stops filming; [onFinished] gets the recording once its last frames
  /// are encoded.
  Future<void> stop(void Function(DebugRecording recording) onFinished) async {
    if (!isRecording) return;
    record('recording', {'action': 'stop'});
    _stopwatch.stop();
    _frameTimer?.cancel();
    _limitTimer?.cancel();
    _status = DebugRecorderStatus.reviewing;
    notifyListeners();
    await _logs?.cancel();
    _logs = null;
    await Future.wait(_encoding.toList());
    if (_frames.isEmpty) {
      AppLogger.instance.warn(_tag, 'Recording has no frames');
      finishReview();
      return;
    }
    _frames.sort((a, b) => a.tMs.compareTo(b.tMs));
    onFinished(
      DebugRecording(
        startedAt: _startedAt,
        durationMs: _stopwatch.elapsedMilliseconds,
        frames: List.of(_frames),
        width: _width,
        height: _height,
        events: List.of(_events),
      ),
    );
  }

  /// The recording was filed or thrown away: debug mode can start again.
  void finishReview() {
    _status = DebugRecorderStatus.idle;
    _frames.clear();
    _events.clear();
    notifyListeners();
  }

  /// Notes an event, while recording.
  void record(String type, Map<String, Object?> data) {
    if (!isRecording) return;
    _events.add(DebugEvent(_stopwatch.elapsedMilliseconds, type, data));
  }

  /// [value], cut short for the report.
  static String truncateValue(String value) => value.length <= _maxValueChars
      ? value
      : '${value.substring(0, _maxValueChars)}…';

  // Static, so the isolate's closure holds nothing but the pixels.
  static Future<Uint8List> _encode(Uint8List rgba, int width, int height) =>
      Isolate.run(() => encodeFrameJpeg(rgba, width, height));

  Future<void> _captureFrame(RenderRepaintBoundary? Function() find) async {
    // Skip a beat rather than pile up work while encoding is behind.
    if (_capturing || _encoding.length >= _maxEncoding) return;
    _capturing = true;
    try {
      // Capture between frames, when the boundary has been painted.
      await SchedulerBinding.instance.endOfFrame;
      final boundary = find();
      if (!isRecording || boundary == null || !boundary.attached) return;
      final size = boundary.size;
      if (size.isEmpty) return;
      final t = _stopwatch.elapsedMilliseconds;
      final ratio = math.min(
        _longSide / math.max(size.width, size.height),
        ui.PlatformDispatcher.instance.implicitView?.devicePixelRatio ?? 1,
      );
      final image = await boundary.toImage(pixelRatio: ratio);
      final width = image.width;
      final height = image.height;
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      if (data == null) return;
      // Keep the first frame's size: a turned phone mustn't change it.
      if (_width == 0) {
        _width = width;
        _height = height;
      } else if (width != _width || height != _height) {
        return;
      }
      final rgba = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      late final Future<void> job;
      job = _encode(rgba, width, height)
          .then((jpeg) => _frames.add(Mp4Frame(tMs: t, jpeg: jpeg)))
          .catchError((Object e) {
            AppLogger.instance.warn(_tag, 'Encoding a frame failed: $e');
          })
          .whenComplete(() => _encoding.remove(job));
      _encoding.add(job);
    } catch (e) {
      AppLogger.instance.warn(_tag, 'Capturing a frame failed: $e');
    } finally {
      _capturing = false;
    }
  }
}
