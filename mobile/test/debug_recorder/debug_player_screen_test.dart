import 'dart:typed_data';

import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/features/debug_recorder/data/debug_report.dart';
import 'package:anchor/features/debug_recorder/data/mp4_muxer.dart';
import 'package:anchor/features/debug_recorder/presentation/debug_player_screen.dart';
import 'package:anchor/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final jpeg = encodeFrameJpeg(Uint8List(8 * 8 * 4), 8, 8);
  final recording = DebugRecording(
    startedAt: DateTime.utc(2026, 10, 28),
    durationMs: 4000,
    width: 8,
    height: 8,
    frames: [
      Mp4Frame(tMs: 0, jpeg: jpeg),
      Mp4Frame(tMs: 2000, jpeg: jpeg),
    ],
    events: const [],
  );

  testWidgets('marks a problem with its expectation at the slider position', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: DebugPlayerScreen(recording: recording),
      ),
    );
    expect(find.text('Problem here (00:00.0)'), findsOneWidget);

    // Halfway along the timeline.
    await tester.tap(find.byType(Slider));
    await tester.pumpAndSettle();
    expect(find.text('Problem here (00:02.0)'), findsOneWidget);

    await tester.tap(find.text('Problem here (00:02.0)'));
    await tester.pumpAndSettle();
    expect(find.text('Problem at 00:02.0'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'The note opens');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('The note opens'), findsOneWidget);
    expect(find.text('00:02.0'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Remove'));
    await tester.pumpAndSettle();
    expect(find.text('The note opens'), findsNothing);
  });
}
