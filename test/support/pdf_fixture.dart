import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:domain_models/domain_models.dart';

import 'ui_test_app.dart';

/// A generated PDF in the managed library, without network or licensed books.
Future<Book> addPdfFixture(UiTestApp app, {int pages = 6}) async {
  final file = File('${app.directory.path}/pages.pdf');
  await file.writeAsBytes(pdfFixtureBytes(pages: pages));
  return app.bookRepository.addBook(
    sourceFile: file,
    title: 'PDF Fixture',
    format: BookFormat.pdf,
  );
}

/// A4 pages in points. Each page has a title, body lines inside 72 pt
/// margins and a blue figure; page 1 links to page 3; the last page holds
/// only a short centred title. Mirrors `makePdf` in the reader browser tests.
List<int> pdfFixtureBytes({int pages = 6}) {
  final objects = <String?>[];
  int add(String? body) {
    objects.add(body);
    return objects.length;
  }

  final catalog = add(null);
  final pagesRef = add(null);
  final font = add('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>');
  final pageRefs = <int>[];
  final contents = <int>[];
  for (var index = 0; index < pages; index++) {
    final sparse = index == pages - 1 && pages > 1;
    final lines = sparse
        ? ['BT /F1 18 Tf 250 430 Td (The End) Tj ET']
        : [
            '0 0 1 rg 72 120 451 120 re f 0 g',
            'BT /F1 18 Tf 72 760 Td (Page ${index + 1} title) Tj ET',
            'BT /F1 11 Tf 14 TL 72 720 Td',
            for (var line = 0; line < 30; line++)
              '(Line ${line + 1} of page ${index + 1}: readable body text '
                  'that spans the column width.) Tj T*',
            'ET',
          ];
    final stream = lines.join('\n');
    contents.add(
      add('<< /Length ${stream.length} >>\nstream\n$stream\nendstream'),
    );
    pageRefs.add(add(null));
  }
  final link = add(null);
  objects[catalog - 1] = '<< /Type /Catalog /Pages $pagesRef 0 R >>';
  objects[pagesRef - 1] =
      '<< /Type /Pages /Count $pages '
      '/Kids [${pageRefs.map((ref) => '$ref 0 R').join(' ')}] >>';
  for (var index = 0; index < pages; index++) {
    final annots = index == 0 && pages > 2 ? ' /Annots [$link 0 R]' : '';
    objects[pageRefs[index] - 1] =
        '<< /Type /Page /Parent $pagesRef 0 R /MediaBox [0 0 595 842] '
        '/Resources << /Font << /F1 $font 0 R >> >> '
        '/Contents ${contents[index]} 0 R$annots >>';
  }
  objects[link - 1] = pages > 2
      ? '<< /Type /Annot /Subtype /Link /Rect [72 755 260 780] '
            '/Border [0 0 0] /Dest [${pageRefs[2]} 0 R /XYZ 0 842 0] >>'
      : '<< >>';

  final pdf = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[];
  for (var index = 0; index < objects.length; index++) {
    offsets.add(pdf.length);
    pdf.write('${index + 1} 0 obj\n${objects[index]}\nendobj\n');
  }
  final xref = pdf.length;
  pdf.write('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n');
  for (final offset in offsets) {
    pdf.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  pdf.write(
    'trailer\n<< /Size ${objects.length + 1} /Root $catalog 0 R >>\n'
    'startxref\n$xref\n%%EOF\n',
  );
  return latin1.encode(pdf.toString());
}

/// A page preview like the reader's PDF thumbnails: white A4 paper with a
/// title bar and body lines, at the 240 px width the reader sends. Lines vary
/// with [index] so neighbouring tiles are told apart.
Future<Uint8List> pdfPageThumbnailFixture(int index) async {
  const size = ui.Size(240, 340);
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawColor(const ui.Color(0xffffffff), ui.BlendMode.src);
  final ink = ui.Paint()..color = const ui.Color(0xff3a3a3a);
  canvas.drawRect(const ui.Rect.fromLTWH(30, 34, 120, 10), ink);
  final body = ui.Paint()..color = const ui.Color(0xff8a8a8a);
  for (var line = 0; line < 26; line++) {
    final width = 180.0 - ((line * 7 + index * 13) % 5) * 12;
    canvas.drawRect(ui.Rect.fromLTWH(30, 62 + line * 9.5, width, 3.5), body);
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.toInt(), size.height.toInt());
  final bytes = (await image.toByteData(
    format: ui.ImageByteFormat.png,
  ))!.buffer.asUint8List();
  image.dispose();
  picture.dispose();
  return bytes;
}
