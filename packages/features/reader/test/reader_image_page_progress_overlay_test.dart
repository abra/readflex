import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/src/reader_image_page_progress_overlay.dart';

void main() {
  testWidgets(
    'image page progress overlay auto-hides and resets on page change',
    (tester) async {
      await tester.pumpOverlay(currentPage: null, totalPages: null);

      expect(find.byKey(_overlayOpacityKey), findsNothing);

      await tester.pumpOverlay(currentPage: 0, totalPages: 25);

      expect(find.text('1 / 25'), findsOneWidget);
      expect(tester.overlayOpacity.opacity, 1);

      await tester.pump(const Duration(milliseconds: 2999));
      expect(tester.overlayOpacity.opacity, 1);

      await tester.pump(const Duration(milliseconds: 1));
      expect(tester.overlayOpacity.opacity, 0);

      await tester.pumpOverlay(currentPage: 2, totalPages: 25);

      expect(find.text('3 / 25'), findsOneWidget);
      expect(tester.overlayOpacity.opacity, 1);
    },
  );

  testWidgets(
    'image page progress overlay hides while reader chrome is visible',
    (tester) async {
      await tester.pumpOverlay(currentPage: 0, totalPages: 25);

      expect(tester.overlayOpacity.opacity, 1);

      await tester.pumpOverlay(
        currentPage: 0,
        totalPages: 25,
        chromeVisible: true,
      );

      expect(tester.overlayOpacity.opacity, 0);
    },
  );

  _localizedTests();
}

const _overlayOpacityKey = ValueKey('readerImagePageProgressOverlayOpacity');

void _localizedTests() {
  testWidgets('image page progress uses the localized page-of-total label', (
    tester,
  ) async {
    await tester.pumpOverlay(
      currentPage: 0,
      totalPages: 25,
      locale: const Locale('ru'),
    );
    final l10n = tester.element(find.byKey(_overlayOpacityKey)).l10n;
    expect(l10n.localeName, 'ru');
    expect(find.text(l10n.readerPageOfTotal(1, 25)), findsOneWidget);
    expect(find.text(l10n.readerPageOfTotal(25, 25)), findsOneWidget);
  });

  testWidgets('image page progress fades in one frame under reduced motion', (
    tester,
  ) async {
    await tester.pumpOverlay(
      currentPage: 0,
      totalPages: 25,
      disableAnimations: true,
    );
    expect(tester.overlayOpacity.duration, Duration.zero);
    await tester.pumpOverlay(
      currentPage: 0,
      totalPages: 25,
      chromeVisible: true,
      disableAnimations: true,
    );
    expect(await tester.pumpAndSettle(), 1);
    expect(tester.overlayOpacity.opacity, 0);
  });
}

extension on WidgetTester {
  Future<void> pumpOverlay({
    required int? currentPage,
    required int? totalPages,
    BookFormat format = BookFormat.cbz,
    bool chromeVisible = false,
    bool selectionActionsVisible = false,
    bool disableAnimations = false,
    Locale locale = const Locale('en'),
  }) async {
    await pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        supportedLocales: ReadflexSupportedLocales.locales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: disableAnimations),
          child: child!,
        ),
        home: Scaffold(
          body: Stack(
            children: [
              ReaderImagePageProgressOverlay(
                format: format,
                chromeVisible: chromeVisible,
                selectionActionsVisible: selectionActionsVisible,
                currentPage: currentPage,
                totalPages: totalPages,
              ),
            ],
          ),
        ),
      ),
    );
  }

  AnimatedOpacity get overlayOpacity {
    return widget<AnimatedOpacity>(find.byKey(_overlayOpacityKey));
  }
}
