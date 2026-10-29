import 'dart:convert';
import 'dart:io';

import 'package:domain_models/domain_models.dart';

import 'ui_test_app.dart';

/// A generated PDF in the managed library, without network or licensed books.
Future<Book> addPdfFixture(
  UiTestApp app, {
  int pages = 6,
  List<(String, int)> outline = const [],
}) async {
  final file = File('${app.directory.path}/pages.pdf');
  await file.writeAsBytes(pdfFixtureBytes(pages: pages, outline: outline));
  return app.bookRepository.addBook(
    sourceFile: file,
    title: 'PDF Fixture',
    format: BookFormat.pdf,
  );
}

/// A4 pages in points. Each page has a title, body lines inside 72 pt
/// margins and a blue figure; page 1 links to page 3; the last page holds
/// only a short centred title. [outline] lists chapter titles with the
/// zero-based page each opens.
List<int> pdfFixtureBytes({
  int pages = 6,
  List<(String, int)> outline = const [],
}) {
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
  final outlineRoot = outline.isEmpty ? null : add(null);
  final outlineItems = [for (final _ in outline) add(null)];
  objects[catalog - 1] = outlineRoot == null
      ? '<< /Type /Catalog /Pages $pagesRef 0 R >>'
      : '<< /Type /Catalog /Pages $pagesRef 0 R /Outlines $outlineRoot 0 R '
            '/PageMode /UseOutlines >>';
  if (outlineRoot != null) {
    objects[outlineRoot - 1] =
        '<< /Type /Outlines /First ${outlineItems.first} 0 R '
        '/Last ${outlineItems.last} 0 R /Count ${outline.length} >>';
    for (var i = 0; i < outline.length; i++) {
      final (title, page) = outline[i];
      final prev = i > 0 ? ' /Prev ${outlineItems[i - 1]} 0 R' : '';
      final next = i < outline.length - 1
          ? ' /Next ${outlineItems[i + 1]} 0 R'
          : '';
      objects[outlineItems[i] - 1] =
          '<< /Title ($title) /Parent $outlineRoot 0 R$prev$next '
          '/Dest [${pageRefs[page]} 0 R /XYZ 0 842 0] >>';
    }
  }
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
