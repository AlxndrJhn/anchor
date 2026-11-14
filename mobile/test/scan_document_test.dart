import 'dart:convert';
import 'dart:typed_data';

import 'package:anchor/features/notes/data/scan_pdf.dart';
import 'package:anchor/features/notes/data/scan_render.dart';
import 'package:anchor/features/notes/domain/scan_document.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  group('ScanDocument', () {
    test('keeps only what differs from the defaults', () {
      const scan = ScanDocument(pages: [ScanPage(id: 'a')]);

      expect(scan.encode(), '{"pages":[{"id":"a"}]}');
    });

    test('round trips every setting', () {
      const scan = ScanDocument(
        title: 'Receipts',
        pages: [
          ScanPage(
            id: 'a',
            corners: [
              Offset(0.1, 0.2),
              Offset(0.9, 0.1),
              Offset(0.8, 0.9),
              Offset(0.2, 0.8),
            ],
            rotate: 90,
            profile: ScanProfile.bw,
            brightness: 10,
            contrast: -20,
            threshold: 30,
            cleanup: 80,
          ),
          ScanPage(id: 'b', profile: ScanProfile.whiteboard),
        ],
        pdf: PdfSettings(
          paper: PdfPaper.letter,
          margin: 10,
          quality: PdfQuality.high,
        ),
      );

      final again = ScanDocument.tryParse(scan.encode())!;

      expect(again.encode(), scan.encode());
      expect(again.title, 'Receipts');
      expect(again.pages[0].corners![2], const Offset(0.8, 0.9));
      expect(again.pages[0].profile, ScanProfile.bw);
      expect(again.pdf.quality, PdfQuality.high);
    });

    test('reads what it can of odd values', () {
      final scan = ScanDocument.tryParse(
        jsonEncode({
          'pages': [
            {
              'id': 'a',
              'rotate': 45,
              'profile': 'sepia',
              'brightness': 500,
              'cleanup': -3,
              'corners': [
                [0, 0],
                [1, 0],
              ],
            },
            {'rotate': 90},
            'nonsense',
          ],
          'pdf': {'size': 'a3', 'margin': 7},
        }),
      )!;

      expect(scan.pages, hasLength(1));
      final page = scan.pages.single;
      expect(page.rotate, 0);
      expect(page.profile, ScanProfile.text);
      expect(page.brightness, 100);
      expect(page.cleanup, 0);
      expect(page.corners, isNull);
      expect(scan.pdf, const PdfSettings());
    });

    test('reads what the web app wrote, and writes it back the same', () {
      // As stored by the web app's scan editor (web/features/notes/scans.ts).
      const web =
          r'{"title":"Kitchen demo scan","pages":[{"id":"85a3f4ab-fe4c-4d37-b658-2f09d0e55a42","corners":[[0.0873,0.2635],[0.9331,0.3093],[0.9152,0.7106],[0.0695,0.6743]],"profile":"whiteboard"},{"id":"b7678dec-0b6d-408a-94a1-73b9a26fec09","corners":[[0.175,0.1563],[0.825,0.2094],[0.8906,0.8719],[0.1031,0.8219]],"profile":"bw"},{"id":"20b6cf35-d27a-43f2-872e-96385ac1b12f","corners":[[0.1406,0.125],[0.8813,0.1813],[0.8469,0.8938],[0.1125,0.8531]]}]}';

      final scan = ScanDocument.tryParse(web)!;

      expect(scan.pages.map((p) => p.profile), [
        ScanProfile.whiteboard,
        ScanProfile.bw,
        ScanProfile.text,
      ]);
      expect(scan.encode(), web);
    });

    test('is null for what is not a scan', () {
      expect(ScanDocument.tryParse('not json'), isNull);
      expect(ScanDocument.tryParse(3), isNull);
    });

    test('names its PDF from the title, safely', () {
      expect(
        const ScanDocument(
          pages: [],
          title: 'Tax / 2026: final',
        ).fileName('Scan'),
        'Tax 2026 final.pdf',
      );
      expect(const ScanDocument(pages: []).fileName('Scan'), 'Scan.pdf');
    });

    test('finds the photos a note’s scans use', () {
      final content = jsonEncode({
        'ops': [
          {'insert': 'Hi\n'},
          {
            'insert': {
              'scan': const ScanDocument(
                pages: [
                  ScanPage(id: 'a'),
                  ScanPage(id: 'b'),
                ],
              ).encode(),
            },
          },
          {'insert': '\n'},
        ],
      });

      expect(scanAttachmentIds(content), {'a', 'b'});
      expect(scanAttachmentIds('{"ops":[{"insert":"x\\n"}]}'), isEmpty);
    });

    test('turning goes round in quarters', () {
      const page = ScanPage(id: 'a', rotate: 270);

      expect(page.turned().rotate, 0);
      expect(page.turned(clockwise: false).rotate, 180);
    });
  });

  group('page looks', () {
    Rgb flat(int w, int h, int Function(int x, int y) value) {
      final bytes = Uint8List(w * h * 3);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final v = value(x, y);
          final i = (y * w + x) * 3;
          bytes[i] = v;
          bytes[i + 1] = v;
          bytes[i + 2] = v;
        }
      }
      return Rgb(w, h, bytes);
    }

    // Paper lit from the left: 230 fading to 150, with dark text rows.
    int shadedPage(int x, int y) {
      final paper = (230 - x * 80 / 199).round();
      return y % 20 < 3 && x % 7 < 5 ? paper ~/ 4 : paper;
    }

    test('black and white leaves only black and white', () {
      final rgb = flat(200, 100, shadedPage);
      applyScanLook(rgb, const ScanPage(id: 'a', profile: ScanProfile.bw));

      expect(rgb.bytes.toSet(), {0, 255});
      // The shaded paper is white, and the text black.
      expect(rgb.bytes[(50 * 200 + 190) * 3], 255);
      expect(rgb.bytes[(0 * 200 + 190) * 3], 0);
    });

    test('a higher threshold makes more of the page black', () {
      int black(int threshold) {
        final rgb = flat(200, 100, shadedPage);
        applyScanLook(
          rgb,
          ScanPage(
            id: 'a',
            profile: ScanProfile.bw,
            threshold: threshold,
            cleanup: 0,
          ),
        );
        return rgb.bytes.where((v) => v == 0).length;
      }

      expect(black(60), greaterThan(black(-60)));
    });

    test('text evens the shaded paper out to near white', () {
      final rgb = flat(200, 100, shadedPage);
      applyScanLook(rgb, const ScanPage(id: 'a', cleanup: 100));

      // Far right was 150; now as light as the left.
      expect(rgb.bytes[(50 * 200 + 190) * 3], greaterThan(240));
      expect(rgb.bytes[(50 * 200 + 10) * 3], greaterThan(240));
    });

    test('full colour with nothing changed keeps the picture', () {
      final rgb = flat(40, 30, (x, y) => (x * 6 + y) % 256);
      final before = Uint8List.fromList(rgb.bytes);
      applyScanLook(rgb, const ScanPage(id: 'a', profile: ScanProfile.color));

      expect(rgb.bytes, before);
    });

    test('a turned page swaps its sides', () {
      final photo = img.Image(width: 60, height: 40);
      final page = renderScanPage(
        photo,
        const ScanPage(id: 'a', rotate: 90, profile: ScanProfile.color),
      );

      expect((page.width, page.height), (40, 60));
    });
  });

  group('PDF', () {
    test('an upright picture fills A4 inside its margins', () {
      final place = placePdfPicture(1000, 2000, const PdfSettings(margin: 10));

      expect(place.pageWidth, closeTo(595.28, 0.01));
      expect(place.pageHeight, closeTo(841.89, 0.01));
      expect(place.height, closeTo(841.89 - 2 * 28.35, 0.1));
      expect(place.x, closeTo((595.28 - place.width) / 2, 0.01));
    });

    test('a wide picture gets a landscape page', () {
      final place = placePdfPicture(
        3000,
        2000,
        const PdfSettings(paper: PdfPaper.letter),
      );

      expect((place.pageWidth, place.pageHeight), (792.0, 612.0));
      expect(place.height, closeTo(528, 0.1));
    });

    test('fit makes the page the picture’s size', () {
      final place = placePdfPicture(
        1500,
        3000,
        const PdfSettings(paper: PdfPaper.fit),
      );

      expect(place.pageWidth, closeTo(720, 0.01));
      expect(place.pageHeight, closeTo(1440, 0.01));
    });

    test('writes a PDF with a page for each picture', () {
      final jpeg = img.encodeJpg(img.Image(width: 10, height: 20));
      final pdf = writePdf([
        for (var i = 0; i < 3; i++)
          (
            jpeg: jpeg,
            width: 10,
            height: 20,
            place: placePdfPicture(10, 20, const PdfSettings()),
          ),
      ], title: 'Änderung');
      final text = latin1.decode(pdf);

      expect(text, startsWith('%PDF-1.4'));
      expect(text, contains('/Count 3'));
      expect(RegExp('/Type /Page ').allMatches(text), hasLength(3));
      expect(text.trimRight(), endsWith('%%EOF'));
      // The cross-reference table points at each object.
      final xref = int.parse(
        RegExp(r'startxref\n(\d+)').firstMatch(text)!.group(1)!,
      );
      expect(text.substring(xref), startsWith('xref'));
      for (final m in RegExp(r'(\d{10}) 00000 n').allMatches(text)) {
        final at = int.parse(m.group(1)!);
        expect(text.substring(at), matches(RegExp(r'^\d+ 0 obj')));
      }
    });
  });
}
