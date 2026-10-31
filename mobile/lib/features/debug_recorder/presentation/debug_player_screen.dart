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
import '../../../core/motion/haptics.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/context_extensions.dart';
import '../../../core/theme/system_bars.dart';
import '../../../core/theme/tokens/anchor_tokens.dart';
import '../../../core/update/app_release.dart';
import '../../../core/widgets/anchor_dialog.dart';
import '../../../core/widgets/anchor_sheet.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/cap_height_text.dart';
import '../../../core/widgets/global_rect_of.dart';
import '../../../core/widgets/page_bar.dart';
import '../../../core/widgets/pressable.dart';
import '../../../l10n/l10n.dart';
import '../../notes/presentation/widgets/media_pill.dart';
import '../data/debug_report.dart';
import '../data/debug_video_encoder.dart';
import '../data/mp4_muxer.dart';

/// Where debug reports are filed: the fork this build updates from.
String get debugReportRepository =>
    updateRepository.isEmpty ? 'AlxndrJhn/anchor' : updateRepository;

const _tag = 'DebugRecorder';

/// Red marks for problems, readable on the dark page.
const _problemRed = Color(0xFFFF8F85);

/// Plays back a debug recording, for marking where things went wrong, then
/// files it as a GitHub issue or throws it away. A dark media page, like the
/// picture viewer.
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
    Haptics.selection();
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
    final expectation = await showAnchorSheet<String>(
      context,
      semanticLabel: context.l10n.debugProblemAt(formatVideoTime(at)),
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
      final l10n = context.l10n;
      final ok = await showAnchorDialog(
        context,
        icon: LucideIcons.trash2,
        isDanger: true,
        title: l10n.debugDiscardTitle,
        message: l10n.debugDiscardMessage,
        confirmLabel: l10n.debugDiscard,
      );
      if (!ok) return;
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

  Future<void> _share(BuildContext button) async {
    final l10n = context.l10n;
    final origin = globalRectOf(button);
    setState(() => _busy = true);
    try {
      final bytes = await _buildReport();
      final dir = await getTemporaryDirectory();
      final name = debugReportFilename(_recording.startedAt);
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'video/mp4')],
          sharePositionOrigin: origin,
        ),
      );
    } catch (e, st) {
      AppLogger.instance.error(
        _tag,
        'Sharing the report failed',
        error: e,
        stackTrace: st,
      );
      if (mounted) {
        AppSnackbar.show(
          context,
          l10n.debugShareFailed,
          kind: SnackbarKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Saves the report, then opens a new issue on GitHub that says to
  /// attach it: GitHub doesn't take attachments any other way.
  Future<void> _createIssue() async {
    if (_ticker.isActive) _ticker.stop();
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      final name = debugReportFilename(_recording.startedAt);
      final bytes = await _buildReport();
      final saved = await saveBytesToDevice(
        name: name,
        bytes: bytes,
        dialogTitle: l10n.debugSaveReport,
        mimeType: 'video/mp4',
      );
      if (!mounted || !saved) return;
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
        AppSnackbar.show(
          context,
          l10n.debugGithubFailed,
          kind: SnackbarKind.error,
        );
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
        AppSnackbar.show(
          context,
          l10n.debugBuildFailed,
          kind: SnackbarKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final media = MediaQuery.of(context);
    const ink = AnchorTokens.colorMediaText;
    final recording = _recording;
    return PopScope(
      canPop: _problems.isEmpty && !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy) _discard();
      },
      child: Material(
        color: Colors.black,
        child: Column(
          children: [
            PageBar(
              isTitleCentered: true,
              color: Colors.black,
              systemBars: systemBarsStyle(dark: true),
              leading: BarButton(
                icon: LucideIcons.x,
                label: l10n.debugDiscard,
                color: ink,
                onPressed: _busy ? null : _discard,
              ),
              title: CapHeightText(
                l10n.debugRecordingTitle,
                style: AppTypography.secondary.copyWith(
                  fontWeight: FontWeight.w600,
                  color: ink,
                ),
              ),
              actions: [
                Builder(
                  builder: (button) => BarButton(
                    icon: LucideIcons.share,
                    label: l10n.debugShareFile,
                    color: ink,
                    onPressed: _busy ? null : () => _share(button),
                  ),
                ),
              ],
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AnchorTokens.spaceGutterPhone,
                ),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: recording.width / recording.height,
                    child: ClipRRect(
                      borderRadius: context.appStyle.corners(
                        AnchorTokens.radiusLg,
                      ),
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
            _Timeline(
              position: _position,
              duration: _duration,
              playing: _ticker.isActive,
              problems: _problems,
              onTogglePlay: _togglePlay,
              onSeek: _seek,
            ),
            MediaPill(
              icon: LucideIcons.flag,
              label: l10n.debugProblemHere(formatVideoTime(_position)),
              onPressed: _busy ? null : _markProblem,
            ),
            const SizedBox(height: 8),
            Expanded(
              flex: 2,
              child: _problems.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AnchorTokens.spaceGutterPhone,
                        ),
                        child: Text(
                          l10n.debugProblemsHint,
                          textAlign: TextAlign.center,
                          style: AppTypography.footnote.copyWith(
                            color: AnchorTokens.colorMediaMuted,
                          ),
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AnchorTokens.spaceGutterPhone,
                      ),
                      children: [
                        for (final p in _problems)
                          _ProblemRow(
                            problem: p,
                            onTap: () => _seek(p.tMs.toDouble()),
                            onRemove: () => setState(() => _problems.remove(p)),
                          ),
                      ],
                    ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AnchorTokens.spaceGutterPhone,
                8,
                AnchorTokens.spaceGutterPhone,
                media.padding.bottom + 12,
              ),
              child: _busy
                  ? Semantics(
                      label: l10n.debugBuilding,
                      child: const SizedBox(
                        height: AnchorTokens.sizeControlMedium,
                        child: Center(
                          child: Spinner(
                            size: AnchorTokens.sizeIconLarge,
                            color: ink,
                          ),
                        ),
                      ),
                    )
                  : Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        MediaPill(
                          icon: LucideIcons.trash2,
                          label: l10n.debugDiscard,
                          onPressed: _discard,
                        ),
                        MediaPill(
                          icon: LucideIcons.bug,
                          label: l10n.debugCreateIssue,
                          isProminent: true,
                          onPressed: _createIssue,
                        ),
                      ],
                    ),
            ),
          ],
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

/// A marked problem: what was expected, and when; a tap goes there.
class _ProblemRow extends StatelessWidget {
  const _ProblemRow({
    required this.problem,
    required this.onTap,
    required this.onRemove,
  });

  final DebugProblem problem;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const ink = AnchorTokens.colorMediaText;
    final expectation = problem.expectation.isEmpty
        ? l10n.debugNoExpectation
        : problem.expectation;
    // The remove button is a sibling: a Pressable swallows what's inside.
    return Row(
      children: [
        Expanded(
          child: Pressable(
            style: PressStyle.button,
            onTap: onTap,
            semanticLabel: '$expectation, ${formatVideoTime(problem.tMs)}',
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.flag,
                    size: AnchorTokens.sizeIconMedium,
                    color: _problemRed,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          expectation,
                          style: AppTypography.row.copyWith(color: ink),
                        ),
                        Text(
                          formatVideoTime(problem.tMs),
                          style: AppTypography.footnote.tabular.copyWith(
                            color: AnchorTokens.colorMediaMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        BarButton(
          icon: LucideIcons.trash2,
          label: l10n.commonRemove,
          color: AnchorTokens.colorMediaMuted,
          onPressed: onRemove,
        ),
      ],
    );
  }
}

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
    final l10n = context.l10n;
    const ink = AnchorTokens.colorMediaText;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          BarButton(
            icon: playing ? LucideIcons.pause : LucideIcons.play,
            label: playing ? l10n.debugPause : l10n.debugPlay,
            color: ink,
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
                      // A mark is 3 wide, centred on its moment.
                      double leftOf(int ms) =>
                          _trackInset + width * ms / duration - 1.5;
                      return Stack(
                        children: [
                          for (final p in problems)
                            Positioned(
                              left: leftOf(p.tMs),
                              top: 12,
                              bottom: 12,
                              child: Container(
                                width: 3,
                                decoration: BoxDecoration(
                                  color: _problemRed,
                                  borderRadius: BorderRadius.circular(
                                    AnchorTokens.radiusPill,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: ink,
                    inactiveTrackColor: AnchorTokens.colorMediaControlHover,
                    thumbColor: ink,
                    overlayColor: AnchorTokens.colorMediaControl,
                  ),
                  child: Slider(
                    value: position.toDouble().clamp(0, duration.toDouble()),
                    max: duration.toDouble(),
                    onChanged: onSeek,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${formatVideoTime(position)} / ${formatVideoTime(duration)}',
            style: AppTypography.footnote.tabular.copyWith(
              color: AnchorTokens.colorMediaMuted,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
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

  void _add() {
    Haptics.success();
    Navigator.of(context).pop(_text.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(title: l10n.debugProblemAt(formatVideoTime(widget.at))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AppTextField(
            controller: _text,
            autofocus: true,
            icon: LucideIcons.flag,
            label: l10n.debugExpectation,
            hint: l10n.debugExpectationHint,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _add(),
          ),
        ),
        SheetFooter(
          children: [
            AppButton(
              label: l10n.commonCancel,
              kind: AppButtonKind.secondary,
              onPressed: () => Navigator.of(context).pop(),
            ),
            AppButton(label: l10n.debugAdd, onPressed: _add),
          ],
        ),
      ],
    );
  }
}
