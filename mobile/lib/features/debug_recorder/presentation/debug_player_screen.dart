import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/files/save_to_device.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/theme/context_extensions.dart';
import '../../../core/theme/tokens/app_icon_sizes.dart';
import '../../../core/theme/tokens/app_opacity.dart';
import '../../../core/theme/tokens/app_radius.dart';
import '../../../core/update/app_release.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../data/debug_report.dart';
import '../data/debug_video_encoder.dart';
import '../data/mp4_muxer.dart';

/// Where debug reports are filed: the fork this build updates from.
String get debugReportRepository =>
    updateRepository.isEmpty ? 'AlxndrJhn/anchor' : updateRepository;

const _tag = 'DebugRecorder';

/// Plays back a debug recording, for marking where things went wrong, then
/// files it as a GitHub issue or throws it away.
class DebugPlayerScreen extends StatefulWidget {
  const DebugPlayerScreen({super.key, required this.recording});

  final DebugRecording recording;

  @override
  State<DebugPlayerScreen> createState() => _DebugPlayerScreenState();
}

class _DebugPlayerScreenState extends State<DebugPlayerScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  final _problems = <DebugProblem>[];
  int _position = 0;
  int _playedFrom = 0;
  bool _busy = false;

  DebugRecording get _recording => widget.recording;
  int get _duration => _recording.durationMs < 1 ? 1 : _recording.durationMs;

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final position = _playedFrom + elapsed.inMilliseconds;
    setState(() => _position = position.clamp(0, _duration));
    if (position >= _duration) _ticker.stop();
  }

  void _togglePlay() {
    if (_ticker.isActive) {
      _ticker.stop();
    } else {
      _playedFrom = _position >= _duration ? 0 : _position;
      _ticker.start();
    }
    setState(() {});
  }

  void _seek(double ms) {
    if (_ticker.isActive) _ticker.stop();
    setState(() => _position = ms.round());
  }

  /// The frame on screen at [ms]: the last one taken by then.
  Uint8List _frameAt(int ms) {
    final frames = _recording.frames;
    var lo = 0;
    var hi = frames.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if (frames[mid].tMs <= ms) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return frames[lo].jpeg;
  }

  Future<void> _markProblem() async {
    if (_ticker.isActive) _ticker.stop();
    final at = _position;
    final expectation = await AppBottomSheet.show<String>(
      context,
      builder: (_) => _ExpectationSheet(at: at),
    );
    if (expectation == null || !mounted) return;
    setState(() {
      _problems
        ..add(DebugProblem(at, expectation))
        ..sort((a, b) => a.tMs.compareTo(b.tMs));
    });
  }

  Future<void> _discard() async {
    if (_problems.isNotEmpty) {
      final ok = await ConfirmDialog.show(
        context: context,
        icon: LucideIcons.trash2,
        iconColor: Theme.of(context).colorScheme.error,
        title: 'Discard recording?',
        message: 'The recording and the problems you marked will be lost.',
        confirmText: 'Discard',
        confirmColor: Theme.of(context).colorScheme.error,
      );
      if (ok != true) return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  /// The report file, built off the UI isolate.
  Future<Uint8List> _buildReport() async {
    final media = MediaQuery.of(context);
    final info = await PackageInfo.fromPlatform();
    final app = <String, Object?>{
      'name': info.appName,
      'package': info.packageName,
      'version': info.version,
      'build': info.buildNumber,
      'fork_build': installedBuild,
      'repository': debugReportRepository,
    };
    final device = <String, Object?>{
      'platform': Platform.operatingSystem,
      'os_version': Platform.operatingSystemVersion,
      'locale': Platform.localeName,
      'screen_width': media.size.width,
      'screen_height': media.size.height,
      'pixel_ratio': media.devicePixelRatio,
    };
    final h264 = await encodeH264(_recording.frames);
    return _buildInIsolate(_recording, List.of(_problems), app, device, h264);
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final bytes = await _buildReport();
      final dir = await getTemporaryDirectory();
      final name = debugReportFilename(_recording.startedAt);
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path, mimeType: 'video/mp4')]),
      );
    } catch (e, st) {
      AppLogger.instance.error(
        _tag,
        'Sharing the report failed',
        error: e,
        stackTrace: st,
      );
      if (mounted) {
        AppSnackbar.showError(context, message: 'Couldn’t share the report');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Saves the report, then opens a new issue on GitHub that says to
  /// attach it: GitHub doesn't take attachments any other way.
  Future<void> _createIssue() async {
    if (_ticker.isActive) _ticker.stop();
    setState(() => _busy = true);
    try {
      final name = debugReportFilename(_recording.startedAt);
      final bytes = await _buildReport();
      final saved = await saveToDevice(filename: name, bytes: bytes, tag: _tag);
      if (!mounted) return;
      switch (saved) {
        case SaveCancelled():
          return;
        case SaveFailed():
          AppSnackbar.showError(context, message: 'Couldn’t save $name');
          return;
        case SavedTo(:final path):
          AppSnackbar.showSuccess(context, message: 'Saved to $path');
        case SavedWithPicker():
          AppSnackbar.showSuccess(context, message: 'Saved $name');
      }
      final info = await PackageInfo.fromPlatform();
      final url = debugIssueUrl(
        repo: debugReportRepository,
        startedAt: _recording.startedAt,
        problems: _problems,
        filename: name,
        appVersion:
            '${info.version}+${info.buildNumber}'
            '${installedBuild > 0 ? ' (fork build $installedBuild)' : ''}',
      );
      final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!mounted) return;
      if (!opened) {
        AppSnackbar.showError(context, message: 'Couldn’t open GitHub');
        return;
      }
      Navigator.of(context).pop();
    } catch (e, st) {
      AppLogger.instance.error(
        _tag,
        'Filing the report failed',
        error: e,
        stackTrace: st,
      );
      if (mounted) {
        AppSnackbar.showError(context, message: 'Couldn’t build the report');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dims = context.dims;
    final recording = _recording;
    return PopScope(
      canPop: _problems.isEmpty && !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy) _discard();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Discard',
            icon: const Icon(LucideIcons.x),
            onPressed: _busy ? null : _discard,
          ),
          title: const Text('Debug recording'),
          actions: [
            IconButton(
              tooltip: 'Share file',
              icon: const Icon(LucideIcons.share2),
              onPressed: _busy ? null : _share,
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: dims.pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: recording.width / recording.height,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: AppRadius.mdBorder,
                          border: Border.all(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: AppOpacity.border,
                            ),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: AppRadius.mdBorder,
                          child: Image.memory(
                            _frameAt(_position),
                            gaplessPlayback: true,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: dims.sm),
                _Timeline(
                  position: _position,
                  duration: _duration,
                  playing: _ticker.isActive,
                  problems: _problems,
                  onTogglePlay: _togglePlay,
                  onSeek: _seek,
                ),
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : _markProblem,
                  icon: const Icon(LucideIcons.flag, size: AppIconSizes.sm),
                  label: Text('Problem here (${formatVideoTime(_position)})'),
                ),
                SizedBox(height: dims.xs),
                Expanded(
                  flex: 2,
                  child: _problems.isEmpty
                      ? Center(
                          child: Text(
                            'Move to where it went wrong and tap '
                            '“Problem here”.\nThe video and the app’s state '
                            'can show your notes: check before sharing.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView(
                          children: [
                            for (final p in _problems)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                leading: Icon(
                                  LucideIcons.flag,
                                  size: AppIconSizes.md,
                                  color: theme.colorScheme.error,
                                ),
                                title: Text(
                                  p.expectation.isEmpty
                                      ? '(no expectation)'
                                      : p.expectation,
                                ),
                                subtitle: Text(formatVideoTime(p.tMs)),
                                onTap: () => _seek(p.tMs.toDouble()),
                                trailing: IconButton(
                                  tooltip: 'Remove',
                                  icon: const Icon(
                                    LucideIcons.trash2,
                                    size: AppIconSizes.md,
                                  ),
                                  onPressed: () =>
                                      setState(() => _problems.remove(p)),
                                ),
                              ),
                          ],
                        ),
                ),
                SizedBox(height: dims.xs),
                if (_busy) ...[
                  const LinearProgressIndicator(),
                  SizedBox(height: dims.xs),
                ],
                SheetActionButtons(
                  cancelText: 'Discard',
                  onCancel: _busy ? null : _discard,
                  confirmText: 'Create issue',
                  onConfirm: _busy ? null : _createIssue,
                ),
                SizedBox(height: dims.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Top level, so the isolate gets only the recording's data.
Future<Uint8List> _buildInIsolate(
  DebugRecording recording,
  List<DebugProblem> problems,
  Map<String, Object?> app,
  Map<String, Object?> device,
  H264Video? h264,
) => Isolate.run(
  () => buildDebugReport(
    recording,
    problems,
    app: app,
    device: device,
    h264: h264,
  ),
);

/// Play/pause, the time, and a slider with a mark at every problem.
class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.position,
    required this.duration,
    required this.playing,
    required this.problems,
    required this.onTogglePlay,
    required this.onSeek,
  });

  final int position;
  final int duration;
  final bool playing;
  final List<DebugProblem> problems;
  final VoidCallback onTogglePlay;
  final ValueChanged<double> onSeek;

  // Slider's own track inset, so marks line up with its thumb.
  static const _trackInset = 24.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        IconButton(
          tooltip: playing ? 'Pause' : 'Play',
          icon: Icon(playing ? LucideIcons.pause : LucideIcons.play),
          onPressed: onTogglePlay,
        ),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth - 2 * _trackInset;
                    return Stack(
                      children: [
                        for (final p in problems)
                          Positioned(
                            left: _trackInset + width * p.tMs / duration - 1.5,
                            top: 6,
                            bottom: 6,
                            child: Container(
                              width: 3,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.error,
                                borderRadius: AppRadius.handleBorder,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              Slider(
                value: position.toDouble().clamp(0, duration.toDouble()),
                max: duration.toDouble(),
                onChanged: onSeek,
              ),
            ],
          ),
        ),
        Text(
          '${formatVideoTime(position)} / ${formatVideoTime(duration)}',
          style: theme.textTheme.bodySmall?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Asks what should have happened at [at]; pops with the answer.
class _ExpectationSheet extends StatefulWidget {
  const _ExpectationSheet({required this.at});

  final int at;

  @override
  State<_ExpectationSheet> createState() => _ExpectationSheetState();
}

class _ExpectationSheetState extends State<_ExpectationSheet> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    return AppBottomSheet(
      icon: LucideIcons.flag,
      iconColor: Theme.of(context).colorScheme.error,
      title: 'Problem at ${formatVideoTime(widget.at)}',
      avoidKeyboard: true,
      contentPadding: EdgeInsets.fromLTRB(
        dims.pagePadding,
        0,
        dims.pagePadding,
        dims.pagePadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _text,
            autofocus: true,
            minLines: 2,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Expectation',
              hintText: 'What should have happened?',
            ),
          ),
          SizedBox(height: dims.md),
          SheetActionButtons(
            confirmText: 'Add',
            onConfirm: () => Navigator.pop(context, _text.text.trim()),
          ),
        ],
      ),
    );
  }
}
