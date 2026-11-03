import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'comic_zoom_test.dart' as comics;
import 'library_controls_test.dart' as library_controls;
import 'mobi_native_test.dart' as mobi;
import 'native_article_test.dart' as article;
import 'native_import_test.dart' as imports;
import 'pdf_reader_test.dart' as pdf;
import 'reader_flows_test.dart' as reader;
import 'reader_note_sheet_test.dart' as notes;
import 'toast_test.dart' as toasts;
import 'tablet_extra_flows_test.dart' as extra;

/// Native tablet regression batch. Each suite keeps its own fixture lifecycle;
/// the device supplies its real viewport instead of a synthetic test surface.
void main() => runNativeRegression();

void runNativeRegression({bool requireTablet = true}) {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final deviceKind = requireTablet ? 'tablet' : 'phone';

  Map<String, Object> viewport() {
    final view = binding.platformDispatcher.views.first;
    final size = view.physicalSize / view.devicePixelRatio;
    return {
      'width': size.width,
      'height': size.height,
      'devicePixelRatio': view.devicePixelRatio,
      'physicalWidth': view.physicalSize.width,
      'physicalHeight': view.physicalSize.height,
      'orientation': size.width > size.height ? 'landscape' : 'portrait',
    };
  }

  testWidgets('the native device exposes a $deviceKind viewport', (
    tester,
  ) async {
    expect(
      Platform.isAndroid || Platform.isIOS,
      isTrue,
      reason: 'Run this batch on a native iOS or Android $deviceKind.',
    );
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(size.shortestSide, greaterThanOrEqualTo(requireTablet ? 600 : 320));
    if (!requireTablet) expect(size.shortestSide, lessThan(600));
    binding.reportData = {
      ...?binding.reportData,
      '${deviceKind}InitialViewport': viewport(),
    };
  });

  group('Library', library_controls.main);
  group('Reader', reader.main);
  group('Article', article.main);
  group('Import', imports.main);
  group('Comic', comics.main);
  group('PDF', pdf.main);
  group('MOBI native', mobi.main);
  group('Notes', notes.main);
  group('Toasts', toasts.main);
  if (!requireTablet) {
    group('RTL and Practice', () => extra.runExtraFlows(requireTablet: false));
  }

  tearDownAll(() {
    binding.reportData = {
      ...?binding.reportData,
      'platform': Platform.operatingSystem,
      'operatingSystemVersion': Platform.operatingSystemVersion,
      '${deviceKind}FinalViewport': viewport(),
      'completedAt': DateTime.now().toUtc().toIso8601String(),
      'tests': binding.results.map(
        (name, result) => MapEntry(name, result.toString()),
      ),
    };
  });
}
