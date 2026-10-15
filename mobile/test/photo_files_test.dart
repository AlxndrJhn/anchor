import 'dart:io';

import 'package:anchor/features/notes/data/photo_files.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('anchor/photos');
  late Directory folder;
  final converted = <String>[];

  setUp(() {
    folder = Directory.systemTemp.createTempSync('photos');
    converted.clear();
  });

  tearDown(() {
    folder.deleteSync(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  void phoneConverts(String? Function(String path) toJpeg) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final path = (call.arguments as Map)['path'] as String;
          converted.add(path);
          return toJpeg(path);
        });
  }

  String photo(String name, List<int> bytes) =>
      (File('${folder.path}/$name')..writeAsBytesSync(bytes)).path;

  test('pictures the server takes are known by their first bytes', () {
    expect(PhotoFiles.mimeOf(const [0xFF, 0xD8, 0xFF, 0xE0]), 'image/jpeg');
    expect(
      PhotoFiles.mimeOf(const [0x89, 0x50, 0x4E, 0x47, 0x0D]),
      'image/png',
    );
    expect(PhotoFiles.mimeOf('GIF89a'.codeUnits), 'image/gif');
    expect(
      PhotoFiles.mimeOf([...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits]),
      'image/webp',
    );
    expect(PhotoFiles.mimeOf([0, 0, 0, 24, ...'ftypheic'.codeUnits]), isNull);
    expect(PhotoFiles.mimeOf(const []), isNull);
  });

  test('a JPEG goes up as it is, whatever its name says', () async {
    phoneConverts((path) => fail('nothing to convert'));
    final path = photo('scaled_IMG_1.heic', const [0xFF, 0xD8, 0xFF, 0xE1]);

    expect(await PhotoFiles.uploadable(path), (path: path, mime: 'image/jpeg'));
  });

  test('a HEIC photo goes up as the JPEG the phone makes of it', () async {
    phoneConverts((path) => path.replaceAll('.heic', '.jpg'));
    final path = photo('IMG_2.heic', [0, 0, 0, 24, ...'ftypheic'.codeUnits]);

    expect(await PhotoFiles.uploadable(path), (
      path: '${folder.path}/IMG_2.jpg',
      mime: 'image/jpeg',
    ));
    expect(converted, [path]);
  });

  test('a photo the phone can not read is refused', () async {
    phoneConverts((path) => throw PlatformException(code: 'unreadable'));
    final path = photo('broken.heic', const [1, 2, 3]);

    expect(await PhotoFiles.uploadable(path), isNull);
    expect(converted, [path]);
  });
}
