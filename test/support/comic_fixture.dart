import 'dart:io';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:domain_models/domain_models.dart';

import 'ui_test_app.dart';

/// Original image pages, generated locally without network or licensed books.
Future<Book> addComicFixture(UiTestApp app) async {
  final archive = Archive();
  for (var index = 0; index < 5; index++) {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawColor(const ui.Color(0xfff7faf9), ui.BlendMode.src);
    for (var panel = 0; panel < 2; panel++) {
      final top = 20.0 + panel * 440;
      canvas.drawRect(
        ui.Rect.fromLTWH(20, top, 560, 420),
        ui.Paint()
          ..color = panel == 0
              ? const ui.Color(0xff40898d)
              : const ui.Color(0xffb76474),
      );
      canvas.drawRect(
        ui.Rect.fromLTWH(55, top + 55, 490, 130),
        ui.Paint()..color = const ui.Color(0xffffffff),
      );
      final builder = ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: 26))
        ..pushStyle(ui.TextStyle(color: const ui.Color(0xff202020)))
        ..addText(
          'Page ${index + 1}, panel ${panel + 1}.\n'
          'A quiet afternoon.\nThe story continues here.',
        );
      final text = builder.build()
        ..layout(const ui.ParagraphConstraints(width: 440));
      canvas.drawParagraph(text, ui.Offset(75, top + 70));
      text.dispose();
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(600, 900);
    final bytes = (await image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
    archive.addFile(ArchiveFile('page-$index.png', bytes.length, bytes));
    image.dispose();
    picture.dispose();
  }
  final file = File('${app.directory.path}/comic.cbz');
  await file.writeAsBytes(ZipEncoder().encode(archive)!);
  return app.bookRepository.addBook(
    sourceFile: file,
    title: 'Comic Zoom Fixture',
    format: BookFormat.cbz,
  );
}
