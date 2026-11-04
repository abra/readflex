import 'dart:io';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:library_feature/src/library_continue_reading_card.dart';
import 'package:native_text_selection/native_text_selection.dart';
import 'package:pagecraft/all_formats.dart';
import 'package:reader/src/reader_selection_cubit.dart';
import 'package:reader/src/reader_ui_cubit.dart';

import '../packages/pagecraft/test/fixtures/pdf/unembedded_cyrillic_fixture.dart';
import '../test/support/device_screenshots.dart';
import '../test/support/ui_test_app.dart';
import '../test/support/ui_test_driver.dart';

/// Real plugin activation and app integration. OS handle dragging and magnifier
/// pixels are verified separately by the native gesture harnesses.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native PDF controls preserve the Reader menu and source range', (
    tester,
  ) async {
    final available = await tester.runAsync(
      () => NativeSelectionPlatform.isAvailable,
    );
    expect(available, isTrue, reason: 'Run on supported iOS/Android hosts');
    final app = await UiTestApp.create(withBook: false);
    addTearDown(app.dispose);
    await app.preferencesService.update(
      (preferences) => preferences.copyWith(readerSelectionTipDismissed: true),
    );
    final file = File('${app.directory.path}/native-selection.pdf');
    await file.writeAsBytes(unembeddedCyrillicFixtureBytes());
    final book = await app.bookRepository.addBook(
      sourceFile: file,
      title: 'Native selection fixture',
      format: BookFormat.pdf,
    );
    tester.platformDispatcher.defaultRouteNameTestValue = '/';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    await tester.pumpWidget(app.widget);
    await tapUi(
      tester,
      find.byWidgetPredicate(
        (widget) =>
            (widget is LibraryContinueReadingCard &&
                widget.source.id == book.id) ||
            widget.key == ValueKey('library-grid-${book.id}') ||
            widget.key == ValueKey('library-row-${book.id}'),
      ),
    );
    await waitForFixedPage(tester);
    final pages = find.byType(FixedPagesView);
    tester.element(pages).read<ReaderUiCubit>().hideChrome();
    await waitForUi(
      tester,
      () => find
          .byType(PdfTextOverlay)
          .evaluate()
          .any(
            (element) =>
                (element.widget as PdfTextOverlay).layer?.isEmpty == false,
          ),
      description: 'PDF source text',
    );
    final element = find
        .byType(PdfTextOverlay)
        .evaluate()
        .firstWhere(
          (element) =>
              (element.widget as PdfTextOverlay).layer?.isEmpty == false,
        );
    final overlay = element.widget as PdfTextOverlay;
    final layer = overlay.layer!;
    final first = layer.wordAt(0)!;
    final glyph = layer.boxesOf(first).first;
    final scale = overlay.imageRect.width / overlay.pageWidth;
    final render = element.renderObject! as RenderBox;
    final point = render.localToGlobal(
      overlay.imageRect.topLeft +
          Offset(
                (glyph.left + glyph.right) / 2,
                (glyph.top + glyph.bottom) / 2,
              ) *
              scale,
    );
    await tester.longPressAt(point);
    final selections = tester.element(pages).read<ReaderSelectionCubit>();
    final flutterHandle = find.byKey(
      ValueKey('pdf-selection-end-handle-${overlay.page}'),
    );
    await waitForUi(
      tester,
      () =>
          selections.state.hasSelection &&
          flutterHandle.evaluate().isEmpty &&
          find.byTooltip('Highlight').hitTestable().evaluate().isNotEmpty,
      description: 'native ready and Reader action popup',
    );
    expect(overlay.selection.range, first);
    expect(selections.state.selectedText, layer.textOf(first));
    expect(pdfTextAnchorFromCfi(selections.state.cfiRange!)?.range, first);
    await tester.pump(const Duration(milliseconds: 300));
    await takeDeviceScreenshot(binding, 'native-pdf-custom-menu');

    final surface = tester.widget<NativeSelectionSurface>(
      find.descendant(
        of: find.byWidgetPredicate(
          (widget) => widget is PdfTextOverlay && widget.page == overlay.page,
        ),
        matching: find.byType(NativeSelectionSurface),
      ),
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is UiKitView || widget is PlatformViewLink,
      ),
      findsOneWidget,
    );
    expect(surface.snapshot!.showMenu, isFalse);
    final second = layer.wordAt(first.end + 1)!;
    final extended = PdfTextRange(first.start, second.end);
    // Exercise the same document boundary used by native callbacks. The native
    // harness separately verifies that actual OS gestures emit these ranges.
    surface.onAdjusting!(true);
    surface.onSelectionChanged(
      TextSelection(baseOffset: extended.start, extentOffset: extended.end),
    );
    await tester.pump();
    expect(selections.state.isAdjusting, isTrue);
    expect(find.byTooltip('Highlight').hitTestable(), findsNothing);
    surface.onAdjusting!(false);
    await tester.pumpAndSettle();
    expect(selections.state.selectedText, layer.textOf(extended));
    expect(pdfTextAnchorFromCfi(selections.state.cfiRange!)?.range, extended);
    expect(find.byTooltip('Highlight').hitTestable(), findsOneWidget);
    surface.onSelectionChanged(null);
    await tester.pumpAndSettle();
    expect(selections.state.hasSelection, isFalse);
    expect(overlay.selection.isActive, isFalse);
    expect(tester.takeException(), isNull);
    (binding.reportData ??= {})['nativeSelection'] = {
      'sourceText': layer.text,
      'originalRange': [first.start, first.end],
      'extendedRange': [extended.start, extended.end],
      'customMenu': true,
    };
    await unmountUi(tester);
  });

  testWidgets(
    'read-only text keeps its Flutter Copy menu with native handles',
    (
      tester,
    ) async {
      const text = 'Native selection preserves 👩‍🔬 and العربية.';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: AppTextSelectionHost(
                  child: SelectableText(text, style: TextStyle(fontSize: 20)),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final editable = tester.state<EditableTextState>(
        find.byType(EditableText),
      );
      await tester.longPressAt(
        tester.getTopLeft(find.byType(SelectableText)) + const Offset(10, 12),
      );
      await waitForUi(
        tester,
        () =>
            editable.renderEditable.selectionColor == Colors.transparent &&
            find.text('Copy').hitTestable().evaluate().isNotEmpty,
        description: 'native handles and existing Flutter Copy toolbar',
      );
      final selected = editable.widget.controller.selection;
      expect(selected.isCollapsed, isFalse);
      final surfaces = find.byType(NativeSelectionSurface);
      expect(
        tester.widget<NativeSelectionSurface>(surfaces).snapshot!.showMenu,
        isFalse,
      );
      await tester.pump(const Duration(milliseconds: 300));
      await takeDeviceScreenshot(binding, 'native-readonly-custom-menu');
      await tester.runAsync(
        () => Clipboard.setData(
          const ClipboardData(text: 'native-selection-sentinel'),
        ),
      );
      await tester.tap(find.text('Copy').hitTestable());
      await tester.pumpAndSettle();
      final copied = await tester.runAsync(
        () => Clipboard.getData('text/plain'),
      );
      expect(copied?.text, text.substring(selected.start, selected.end));
      expect(tester.takeException(), isNull);
      await unmountUi(tester);
    },
  );
}
