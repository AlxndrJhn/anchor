import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/motion/haptics.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/system_bars.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../../../core/widgets/cap_height_text.dart';
import '../../../../core/widgets/page_bar.dart';
import '../../../../l10n/l10n.dart';
import '../../data/scan_previews.dart';
import '../../domain/scan_document.dart';
import 'media_pill.dart';
import 'page_scan_screen.dart';

/// What came of changing one scanned page.
typedef ScanPageEdit = ({ScanPage page, bool lookForAll});

/// Changes one scanned page: its corners, which way up it is, its colour
/// profile and the sliders, seeing the page as it will come out.
class ScanPageScreen extends StatefulWidget {
  const ScanPageScreen({
    super.key,
    required this.photo,
    required this.page,
    required this.number,
    required this.count,
  });

  /// The page's photo on the phone.
  final String photo;
  final ScanPage page;

  /// Which page it is, from 1, of [count].
  final int number;
  final int count;

  static Future<ScanPageEdit?> open(
    BuildContext context, {
    required String photo,
    required ScanPage page,
    required int number,
    required int count,
  }) => Navigator.of(context, rootNavigator: true).push<ScanPageEdit>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ScanPageScreen(
        photo: photo,
        page: page,
        number: number,
        count: count,
      ),
    ),
  );

  @override
  State<ScanPageScreen> createState() => _ScanPageScreenState();
}

class _ScanPageScreenState extends State<ScanPageScreen> {
  late ScanPage _page = widget.page;

  /// The sliders while they're dragged: the page is only made again once
  /// they're let go.
  late ScanPage _shown = widget.page;
  bool _lookForAll = false;
  String? _preview;
  bool _isRendering = false;
  int _render = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_rerender());
  }

  Future<void> _rerender() async {
    final ticket = ++_render;
    setState(() => _isRendering = true);
    try {
      final path = await scanPreview(widget.photo, _page, maxSide: 1200);
      if (!mounted || ticket != _render) return;
      setState(() {
        _preview = path;
        _isRendering = false;
      });
    } catch (_) {
      if (mounted && ticket == _render) setState(() => _isRendering = false);
    }
  }

  void _set(ScanPage page) {
    setState(() {
      _page = page;
      _shown = page;
    });
    unawaited(_rerender());
  }

  Future<void> _frame() async {
    final corners = await PageScanScreen.open(
      context,
      widget.photo,
      corners: _page.corners,
    );
    if (corners == null || !mounted) return;
    _set(_page.copyWith(corners: () => corners));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const ink = AnchorTokens.colorMediaText;
    final preview = _preview;
    return Material(
      color: Colors.black,
      child: Column(
        children: [
          PageBar(
            isTitleCentered: true,
            color: Colors.black,
            systemBars: systemBarsStyle(dark: true),
            leading: BarButton(
              icon: LucideIcons.x,
              label: l10n.commonCancel,
              color: ink,
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: CapHeightText(
              widget.count > 1
                  ? l10n.scanPageNumber(widget.number, widget.count)
                  : l10n.scanPage,
              style: AppTypography.secondary.copyWith(
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
            actions: [
              BarButton(
                key: const ValueKey('scan-page-done'),
                icon: LucideIcons.check,
                label: l10n.commonDone,
                color: ink,
                onPressed: () {
                  Haptics.success();
                  Navigator.of(
                    context,
                  ).pop<ScanPageEdit>((page: _page, lookForAll: _lookForAll));
                },
              ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (preview != null)
                    Positioned.fill(
                      child: Image.file(
                        File(preview),
                        key: const ValueKey('scan-page-preview'),
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),
                    ),
                  if (_isRendering)
                    const CircularProgressIndicator(
                      color: AnchorTokens.colorMediaMuted,
                    ),
                ],
              ),
            ),
          ),
          _Controls(
            page: _shown,
            count: widget.count,
            lookForAll: _lookForAll,
            onFrame: _frame,
            onTurn: (clockwise) => _set(_page.turned(clockwise: clockwise)),
            onProfile: (profile) => _set(_page.copyWith(profile: profile)),
            onSliding: (page) => setState(() => _shown = page),
            onSlid: _set,
            onLookForAll: () => setState(() => _lookForAll = !_lookForAll),
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.page,
    required this.count,
    required this.lookForAll,
    required this.onFrame,
    required this.onTurn,
    required this.onProfile,
    required this.onSliding,
    required this.onSlid,
    required this.onLookForAll,
  });

  final ScanPage page;
  final int count;
  final bool lookForAll;
  final VoidCallback onFrame;
  final ValueChanged<bool> onTurn;
  final ValueChanged<ScanProfile> onProfile;
  final ValueChanged<ScanPage> onSliding;
  final ValueChanged<ScanPage> onSlid;
  final VoidCallback onLookForAll;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sliders = <(String, String, int, ScanPage Function(int))>[
      (
        'brightness',
        l10n.scanBrightness,
        page.brightness,
        (v) => page.copyWith(brightness: v),
      ),
      (
        'contrast',
        l10n.scanContrast,
        page.contrast,
        (v) => page.copyWith(contrast: v),
      ),
      if (page.profile != ScanProfile.color)
        (
          'cleanup',
          l10n.scanCleanup,
          page.cleanup,
          (v) => page.copyWith(cleanup: v),
        ),
      if (page.profile == ScanProfile.bw)
        (
          'threshold',
          l10n.scanThreshold,
          page.threshold,
          (v) => page.copyWith(threshold: v),
        ),
    ];
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AnchorTokens.spaceGutterPhone,
        0,
        AnchorTokens.spaceGutterPhone,
        MediaQuery.paddingOf(context).bottom + context.density.space12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              MediaPill(
                key: const ValueKey('scan-page-corners'),
                icon: LucideIcons.scan,
                label: l10n.scanCorners,
                onPressed: onFrame,
              ),
              MediaPill(
                icon: LucideIcons.rotateCcw,
                label: l10n.scanTurnLeft,
                onPressed: () => onTurn(false),
              ),
              MediaPill(
                key: const ValueKey('scan-page-turn-right'),
                icon: LucideIcons.rotateCw,
                label: l10n.scanTurnRight,
                onPressed: () => onTurn(true),
              ),
            ],
          ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final profile in ScanProfile.values)
                MediaPill(
                  key: ValueKey('scan-profile-${profile.code}'),
                  icon: scanProfileIcon(profile),
                  label: scanProfileLabel(profile, l10n),
                  isProminent: profile == page.profile,
                  onPressed: () {
                    Haptics.selection();
                    onProfile(profile);
                  },
                ),
            ],
          ),
          for (final (key, label, value, change) in sliders)
            _LevelSlider(
              key: ValueKey('scan-slider-$key'),
              label: label,
              value: value,
              min: key == 'cleanup' ? 0 : -100,
              onChanged: (v) => onSliding(change(v)),
              onChangeEnd: (v) => onSlid(change(v)),
            ),
          if (count > 1)
            MediaPill(
              key: const ValueKey('scan-look-for-all'),
              icon: lookForAll ? LucideIcons.squareCheck : LucideIcons.square,
              label: l10n.scanLookForAll,
              isProminent: lookForAll,
              onPressed: onLookForAll,
            ),
        ],
      ),
    );
  }
}

class _LevelSlider extends StatelessWidget {
  const _LevelSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final String label;
  final int value;
  final int min;
  final ValueChanged<int> onChanged;
  final ValueChanged<int> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    const ink = AnchorTokens.colorMediaText;
    return Row(
      children: [
        SizedBox(
          width: 96, // off-scale: room for the longest slider name
          child: Text(
            label,
            style: AppTypography.secondary.copyWith(color: ink),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: context.anchor.accentStrong,
              thumbColor: ink,
              inactiveTrackColor: AnchorTokens.colorMediaControl,
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: Slider(
              value: value.toDouble(),
              min: min.toDouble(),
              max: 100,
              label: '$value',
              semanticFormatterCallback: (v) => '$label ${v.round()}',
              onChanged: (v) => onChanged(v.round()),
              onChangeEnd: (v) => onChangeEnd(v.round()),
            ),
          ),
        ),
        SizedBox(
          width: 32,
          child: Text(
            '$value',
            textAlign: TextAlign.end,
            style: AppTypography.secondary.copyWith(
              color: AnchorTokens.colorMediaMuted,
            ),
          ),
        ),
      ],
    );
  }
}

IconData scanProfileIcon(ScanProfile profile) => switch (profile) {
  ScanProfile.bw => LucideIcons.contrast,
  ScanProfile.whiteboard => LucideIcons.presentation,
  ScanProfile.text => LucideIcons.fileText,
  ScanProfile.color => LucideIcons.palette,
};

String scanProfileLabel(ScanProfile profile, AppLocalizations l10n) =>
    switch (profile) {
      ScanProfile.bw => l10n.scanProfileBw,
      ScanProfile.whiteboard => l10n.scanProfileWhiteboard,
      ScanProfile.text => l10n.scanProfileText,
      ScanProfile.color => l10n.scanProfileColor,
    };
