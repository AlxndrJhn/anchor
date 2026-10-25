import 'dart:io';

import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/features/notes/domain/note_attachment.dart';
import 'package:anchor/features/notes/presentation/widgets/audio_card.dart';
import 'package:anchor/features/notes/presentation/widgets/note_surface.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the download button saves the recording where the person '
      'picks', (tester) async {
    final dir = Directory.systemTemp.createTempSync('audio_card_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/memo.m4a')..writeAsBytesSync([1, 2, 3]);
    final picker = FilePickerPlatform.instance;
    final saveScreen = _SaveScreen();
    FilePickerPlatform.instance = saveScreen;
    addTearDown(() => FilePickerPlatform.instance = picker);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: AudioCard(
                  attachment: NoteAttachment(
                    id: 'a1',
                    noteId: 'n1',
                    type: AttachmentType.audio,
                    originalFilename: 'memo.m4a',
                    mimeType: 'audio/mp4',
                    fileSize: 3,
                    localPath: file.path,
                  ),
                  appearance: NoteAppearance.of(context, null),
                  onDelete: null,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.runAsync(() async {
      await tester.tap(find.bySemanticsLabel('Save memo'));
      for (var i = 0; i < 10 && saveScreen.saved == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(saveScreen.saved, 'memo.m4a');
    expect(saveScreen.bytes, [1, 2, 3]);
    expect(find.text('Saved memo.m4a'), findsOneWidget);
    await tester.pump(const Duration(seconds: 7));
    await tester.pump(const Duration(seconds: 1));
  });
}

class _SaveScreen extends FilePickerPlatform {
  String? saved;
  Uint8List? bytes;

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    saved = fileName;
    this.bytes = bytes;
    return Uri.file('/picked/$fileName');
  }
}
