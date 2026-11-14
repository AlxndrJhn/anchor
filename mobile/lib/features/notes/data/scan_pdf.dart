import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/scan_document.dart';
import 'scan_render.dart';

/// Where a page's picture goes on its PDF page, in points (1/72 inch), from
/// the bottom left as PDF counts.
typedef PdfPlacement = ({
  double pageWidth,
  double pageHeight,
  double x,
  double y,
  double width,
  double height,
});

const _a4 = (595.28, 841.89);
const _letter = (612.0, 792.0);

/// Lays a picture [pixelWidth] by [pixelHeight] out on a page as [settings]
/// ask: turned with the picture, fitted inside the margins and centred; or,
/// for [PdfPaper.fit], on a page its own size at the quality's resolution.
PdfPlacement placePdfPicture(
  int pixelWidth,
  int pixelHeight,
  PdfSettings settings,
) {
  final margin = settings.margin * 72 / 25.4;
  if (settings.paper == PdfPaper.fit) {
    final w = pixelWidth * 72 / settings.quality.dpi;
    final h = pixelHeight * 72 / settings.quality.dpi;
    return (
      pageWidth: w + 2 * margin,
      pageHeight: h + 2 * margin,
      x: margin,
      y: margin,
      width: w,
      height: h,
    );
  }
  final (short, long) = settings.paper == PdfPaper.letter ? _letter : _a4;
  final landscape = pixelWidth > pixelHeight;
  final pageWidth = landscape ? long : short;
  final pageHeight = landscape ? short : long;
  final roomW = pageWidth - 2 * margin, roomH = pageHeight - 2 * margin;
  final scale = math.min(roomW / pixelWidth, roomH / pixelHeight);
  final w = pixelWidth * scale, h = pixelHeight * scale;
  return (
    pageWidth: pageWidth,
    pageHeight: pageHeight,
    x: (pageWidth - w) / 2,
    y: (pageHeight - h) / 2,
    width: w,
    height: h,
  );
}

/// A JPEG to put on a PDF page.
typedef PdfPicture = ({
  Uint8List jpeg,
  int width,
  int height,
  PdfPlacement place,
});

/// A PDF with one page per picture: the smallest file that's still a PDF
/// every reader opens. JPEGs go in as they are (DCTDecode).
Uint8List writePdf(List<PdfPicture> pictures, {String title = ''}) {
  final out = BytesBuilder(copy: false);
  final offsets = <int>[];
  void raw(String s) => out.add(latin1.encode(s));
  String num(double v) => v.toStringAsFixed(2);

  raw('%PDF-1.4\n%\xE2\xE3\xCF\xD3\n');
  // 1: catalog, 2: pages, 3: info; then three objects a page.
  final pageIds = [for (var i = 0; i < pictures.length; i++) 4 + i * 3];
  void object(int id, void Function() body) {
    while (offsets.length < id) {
      offsets.add(0);
    }
    offsets[id - 1] = out.length;
    raw('$id 0 obj\n');
    body();
    raw('\nendobj\n');
  }

  object(1, () => raw('<< /Type /Catalog /Pages 2 0 R >>'));
  object(
    2,
    () => raw(
      '<< /Type /Pages /Kids [${pageIds.map((id) => '$id 0 R').join(' ')}] '
      '/Count ${pictures.length} >>',
    ),
  );
  object(3, () => raw('<< /Title ${_pdfText(title)} /Producer (Anchor+) >>'));
  for (var i = 0; i < pictures.length; i++) {
    final picture = pictures[i];
    final page = pageIds[i], content = page + 1, image = page + 2;
    final place = picture.place;
    final draw =
        'q ${num(place.width)} 0 0 ${num(place.height)} '
        '${num(place.x)} ${num(place.y)} cm /Im0 Do Q';
    object(
      page,
      () => raw(
        '<< /Type /Page /Parent 2 0 R '
        '/MediaBox [0 0 ${num(place.pageWidth)} ${num(place.pageHeight)}] '
        '/Resources << /XObject << /Im0 $image 0 R >> >> '
        '/Contents $content 0 R >>',
      ),
    );
    object(content, () {
      raw('<< /Length ${draw.length} >>\nstream\n$draw\nendstream');
    });
    object(image, () {
      raw(
        '<< /Type /XObject /Subtype /Image /Width ${picture.width} '
        '/Height ${picture.height} /ColorSpace /DeviceRGB '
        '/BitsPerComponent 8 /Filter /DCTDecode '
        '/Length ${picture.jpeg.length} >>\nstream\n',
      );
      out.add(picture.jpeg);
      raw('\nendstream');
    });
  }
  final xref = out.length;
  raw('xref\n0 ${offsets.length + 1}\n0000000000 65535 f \n');
  for (final offset in offsets) {
    raw('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  raw(
    'trailer\n<< /Size ${offsets.length + 1} /Root 1 0 R /Info 3 0 R >>\n'
    'startxref\n$xref\n%%EOF\n',
  );
  return out.toBytes();
}

/// [text] as a PDF string: plain when it's ASCII, UTF-16 otherwise.
String _pdfText(String text) {
  if (text.codeUnits.every((c) => c >= 32 && c < 127)) {
    final escaped = text
        .replaceAll(r'\', r'\\')
        .replaceAll('(', r'\(')
        .replaceAll(')', r'\)');
    return '($escaped)';
  }
  final hex = StringBuffer('<FEFF');
  for (final unit in text.codeUnits) {
    hex.write(unit.toRadixString(16).padLeft(4, '0').toUpperCase());
  }
  hex.write('>');
  return hex.toString();
}

/// Makes the PDF of [scan] from its photos ([photos] maps each page's
/// attachment id to the file), off the UI thread, into the app's cache, and
/// returns its file; named from the title or [fallbackName].
Future<File> makeScanPdf(
  ScanDocument scan,
  Map<String, String> photos, {
  required String fallbackName,
}) async {
  final dir = Directory(p.join((await getTemporaryDirectory()).path, 'scans'));
  await dir.create(recursive: true);
  final out = p.join(dir.path, scan.fileName(fallbackName));
  final pages = scan.pages;
  final settings = scan.pdf;
  final title = scan.title;
  final longSide = settings.quality.longSide;
  final pictures = <PdfPicture>[];
  for (final page in pages) {
    final path = photos[page.id];
    if (path == null) throw StateError('Photo ${page.id} not on the phone');
    final photo = await readPhoto(path, longSide: longSide * 2);
    pictures.add(
      await Isolate.run(() {
        final rendered = renderScanPage(photo, page, maxSide: longSide);
        return (
          jpeg: img.encodeJpg(rendered, quality: settings.quality.jpegQuality),
          width: rendered.width,
          height: rendered.height,
          place: placePdfPicture(rendered.width, rendered.height, settings),
        );
      }),
    );
  }
  await Isolate.run(
    () => File(out).writeAsBytesSync(writePdf(pictures, title: title)),
  );
  return File(out);
}
