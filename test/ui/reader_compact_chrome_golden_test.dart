import 'package:component_library/component_library.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagecraft/all_formats.dart' show TextColumnPage, TextPagesView;
import 'package:preferences_service/preferences_service.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:reader/src/reader_ui_cubit.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import '../support/ui_test_app.dart';
import '../support/ui_test_driver.dart';
import 'golden_support.dart';

void main() {
  setUpAll(() async {
    await loadUiFonts();
    // Portable geometry; OS captures remain the evidence for system SF glyphs.
    final font = rootBundle.load(
      'packages/component_library/fonts/Geist-Variable.ttf',
    );
    for (final family in ['CupertinoSystemText', 'CupertinoSystemDisplay']) {
      await (FontLoader(family)..addFont(font)).load();
    }
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final rtl in [false, true]) {
      for (final insets in ['none', 'landscape', 'constrained']) {
        final name = '${platform.name}-${rtl ? 'rtl' : 'ltr'}-$insets';
        testWidgets('compact Reader chrome $name', (tester) async {
          debugDefaultTargetPlatformOverride = platform;
          addTearDown(() => debugDefaultTargetPlatformOverride = null);
          tester.view
            ..physicalSize = const Size(568, 320)
            ..devicePixelRatio = 1
            ..padding = switch (insets) {
              'landscape' => FakeViewPadding(
                left: 44,
                right: 44,
                bottom: platform == TargetPlatform.iOS ? 21 : 24,
              ),
              'constrained' => const FakeViewPadding(
                top: 24,
                bottom: 34,
                left: 44,
                right: 44,
              ),
              _ => FakeViewPadding.zero,
            };
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final app = (await tester.runAsync(UiTestApp.create))!;
          addTearDown(app.dispose);
          await app.preferencesService.update(
            (preferences) => preferences.copyWith(
              locale: Locale(rtl ? 'ar' : 'de'),
              themeMode: rtl ? AppThemeMode.dark : AppThemeMode.light,
            ),
          );
          await tester.pumpWidget(
            RepaintBoundary(key: goldenBoundary, child: app.widget),
          );
          await tapUi(
            tester,
            find.byKey(ValueKey('library-grid-${app.book!.id}')),
          );
          await waitForUi(
            tester,
            () => find.byType(TextColumnPage).evaluate().isNotEmpty,
            description: 'compact Reader page',
          );
          await tester.pumpAndSettle();
          final pages = find.byType(TextPagesView);
          final pageState = tester.state(pages);
          final pageBounds = tester.getRect(pages);
          final context = tester.element(pages);
          context.read<ReaderBloc>().add(
            ReaderBookPositionUpdated(
              cfi: 'epubcfi(/6/4!/4/2)',
              progress: .2,
              chapterTitle: rtl ? 'فصل طويل عن الكتب والقراءة والأفكار والقصص' : 'Ein besonders langer Kapitelname über Bücher und Geschichten',
              chapterCurrentPage: 1,
              chapterTotalPages: 16,
            ),
          );
          context.read<ReaderUiCubit>().showChrome();
          await tester.pumpAndSettle();
          final pill = tester.getRect(
            find.byKey(const ValueKey('readerBrightnessChromeIgnorePointer')),
          );
          final dock = tester.getRect(
            find.byKey(const ValueKey('readerChromeDock')),
          );
          final title = tester.getRect(
            find.byKey(const ValueKey('readerTopChromeLine')),
          );
          expect(pill.height, AppSizes.buttonHeight);
          expect(pill.top, greaterThanOrEqualTo(tester.view.padding.top + 4));
          expect(pill.bottom + AppSpacing.sm, lessThanOrEqualTo(dock.top));
          expect(title.overlaps(pill), isFalse);
          for (final target in [
            find.byTooltip(context.l10n.readerIncreaseBrightness),
            find.byKey(const ValueKey('readerBrightnessChromeDragArea')),
            find.byTooltip(context.l10n.readerDecreaseBrightness),
          ]) {
            expect(tester.getSize(target), const Size.square(48));
            expect(target.hitTestable(), findsOneWidget);
            expect(tester.getRect(target).overlaps(dock), isFalse);
          }
          expect(tester.state(pages), same(pageState));
          expect(tester.getRect(pages), pageBounds);
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byKey(goldenBoundary),
            matchesGoldenFile('goldens/compact-reader/$name.png'),
          );
          await unmountUi(tester);
        });
      }
    }
  }
}
