import 'dart:convert';

import 'package:anchor/features/notes/domain/live_image.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads a live image as the web app writes it', () {
    final image = LiveImage.tryParse(
      jsonEncode({
        'id': 'l1',
        'source': 'screen',
        'device': 'desk',
        'label': 'Anchor+ on Windows',
        'width': 0.5,
        'crop': {'left': 0.1, 'top': 0.2, 'right': 0.6, 'bottom': 0.9},
      }),
    )!;
    expect(image.id, 'l1');
    expect(image.isScreen, isTrue);
    expect(image.device, 'desk');
    expect(image.label, 'Anchor+ on Windows');
    expect(image.width, 0.5);
    expect(image.crop!.across, closeTo(0.5, 1e-9));
    expect(image.crop!.down, closeTo(0.7, 1e-9));
  });

  test('takes a camera, the full width and the whole video by default', () {
    final image = LiveImage.tryParse(
      jsonEncode({
        'id': 'l1',
        'device': 'desk',
        'width': 1,
        'crop': {'left': 0, 'top': 0, 'right': 1, 'bottom': 1},
      }),
    )!;
    expect(image.isScreen, isFalse);
    expect(image.width, isNull);
    expect(image.crop, isNull);
  });

  test('puts a crop in order and drops one too small to show', () {
    final turned = LiveCrop.tryParse({
      'left': 0.8,
      'top': 0.5,
      'right': 0.2,
      'bottom': 0.1,
    })!;
    expect(
      [turned.left, turned.top, turned.right, turned.bottom],
      [0.2, 0.1, 0.8, 0.5],
    );
    expect(
      LiveCrop.tryParse({'left': 0.5, 'top': 0, 'right': 0.5, 'bottom': 1}),
      isNull,
    );
  });

  test('needs an id and the device that shows it', () {
    expect(LiveImage.tryParse(jsonEncode({'id': 'l1'})), isNull);
    expect(LiveImage.tryParse(jsonEncode({'device': 'd'})), isNull);
    expect(LiveImage.tryParse('{nope'), isNull);
    expect(LiveImage.tryParse(null), isNull);
  });

  test('finds the live images in a note, in the order of its text', () {
    String embed(String id) => jsonEncode({'id': id, 'device': 'desk'});
    final content = jsonEncode({
      'ops': [
        {'insert': 'Watch\n'},
        {
          'insert': {LiveImage.embedType: embed('l1')},
        },
        {
          'insert': {'note-image': '{"id":"a1"}'},
        },
        {
          'insert': {LiveImage.embedType: embed('l2')},
        },
        {
          'insert': {LiveImage.embedType: '{nope'},
        },
        {'insert': '\n'},
      ],
    });
    expect([for (final image in liveImagesOf(content)) image.id], ['l1', 'l2']);
    expect(liveImagesOf(null), isEmpty);
    expect(liveImagesOf('plain text'), isEmpty);
  });
}
