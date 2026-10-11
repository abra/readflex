import 'dart:math' as math;

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:reader/src/reader_search_cubit.dart';
import 'package:reader/src/reader_selection_cubit.dart';
import 'package:reader/src/reader_selection_tip.dart';
import 'package:reader/src/reader_selection_tip_cubit.dart';
import 'package:reader/src/reader_ui_cubit.dart';
import 'package:reader_webview/reader_webview.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:toast_service/toast_service.dart';

import 'helpers/fake_book_repository.dart';
import 'helpers/fake_highlight_repository.dart';

void main() {
  late PreferencesService preferences;
  late ReaderSelectionTipCubit cubit;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    preferences = await PreferencesService.create(supportedCodes: const ['en']);
    cubit = ReaderSelectionTipCubit(preferencesService: preferences);
  });
  tearDown(() async {
    await cubit.close();
    await preferences.dispose();
  });

  final card = find.byType(ReaderSelectionTipCard);

  ReadflexLocalizations l10nOf(WidgetTester tester, Finder finder) =>
      ReadflexLocalizations.of(tester.element(finder))!;

  /// Hosts [child] in a phone-sized app with [cubit] provided.
  Future<void> pumpHost(
    WidgetTester tester,
    Widget child, {
    ThemeData? theme,
    Size size = const Size(390, 844),
    bool reduceMotion = true,
    double textScale = 1,
    EdgeInsets padding = EdgeInsets.zero,
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.light(),
        locale: locale,
        supportedLocales: ReadflexSupportedLocales.locales,
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduceMotion,
            textScaler: TextScaler.linear(textScale),
            padding: padding,
          ),
          child: app!,
        ),
        home: BlocProvider.value(
          value: cubit,
          child: Scaffold(body: Stack(children: [child])),
        ),
      ),
    );
  }

  Widget overlay() => const Positioned(
    left: 0,
    right: 0,
    bottom: 0,
    child: ReaderSelectionTipOverlay(),
  );

  group('ReaderSelectionTipCard', () {
    Future<void> pumpCard(
      WidgetTester tester, {
      ThemeData? theme,
      double textScale = 1,
      Size size = const Size(390, 844),
      Locale locale = const Locale('en'),
      VoidCallback? onDismiss,
    }) => pumpHost(
      tester,
      Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ReaderSelectionTipCard(onDismiss: onDismiss ?? () {}),
        ),
      ),
      theme: theme,
      textScale: textScale,
      size: size,
      locale: locale,
    );

    testWidgets('teaches the gesture with the menu labels and Got it', (
      tester,
    ) async {
      var dismissed = 0;
      await pumpCard(tester, onDismiss: () => dismissed++);
      final l10n = l10nOf(tester, card);

      expect(find.text(l10n.readerSelectionTipTitle), findsOneWidget);
      expect(
        find.text(
          l10n.readerSelectionTipBody(
            l10n.highlightAction,
            l10n.commonCopy,
            l10n.translationAction,
            l10n.dictionaryAction,
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.byIcon(AppIcons.translate)),
        findsOneWidget,
      );

      await tester.tap(find.text(l10n.readerSelectionTipDismiss));
      expect(dismissed, 1);
    });

    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      testWidgets('an inverse plate with readable inks: ${theme.brightness}', (
        tester,
      ) async {
        await pumpCard(tester, theme: theme);
        final colors = theme.colorScheme;
        final l10n = l10nOf(tester, card);
        final plate = tester.widget<Material>(
          find.descendant(of: card, matching: find.byType(Material)).first,
        );
        expect(plate.color, colors.inverseSurface);
        expect(plate.borderRadius, BorderRadius.circular(AppRadius.lg));

        final title = tester.widget<Text>(
          find.text(l10n.readerSelectionTipTitle),
        );
        expect(title.style!.color, colors.onInverseSurface);

        final accent = ReaderSelectionTipCard.actionColor(colors);
        final detail = Color.alphaBlend(
          colors.onInverseSurface.withValues(
            alpha: ReaderSelectionTipCard.detailAlpha,
          ),
          colors.inverseSurface,
        );
        expect(_contrast(accent, colors.inverseSurface), greaterThan(4.5));
        expect(_contrast(detail, colors.inverseSurface), greaterThan(4.5));
        expect(
          tester
              .widget<Icon>(
                find.descendant(of: card, matching: find.byType(Icon)),
              )
              .color,
          accent,
        );
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      });
    }

    testWidgets('announces itself and offers Got it as a 48dp button', (
      tester,
    ) async {
      await pumpCard(tester);
      final l10n = l10nOf(tester, card);
      final semantics = tester.ensureSemantics();
      try {
        final body = l10n.readerSelectionTipBody(
          l10n.highlightAction,
          l10n.commonCopy,
          l10n.translationAction,
          l10n.dictionaryAction,
        );
        expect(
          tester.getSemantics(find.text(l10n.readerSelectionTipTitle)),
          matchesSemantics(
            label: '${l10n.readerSelectionTipTitle}\n$body',
            isLiveRegion: true,
          ),
        );
        final dismiss = find.widgetWithText(
          TextButton,
          l10n.readerSelectionTipDismiss,
        );
        expect(
          tester.getSize(dismiss).height,
          greaterThanOrEqualTo(AppSizes.buttonHeight),
        );
        expect(
          tester.getSemantics(dismiss),
          matchesSemantics(
            label: l10n.readerSelectionTipDismiss,
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            isFocusable: true,
            hasTapAction: true,
            hasFocusAction: true,
          ),
        );
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('Got it sits beside the text, and below it at large text', (
      tester,
    ) async {
      await pumpCard(tester);
      final l10n = l10nOf(tester, card);
      final title = find.text(l10n.readerSelectionTipTitle);
      final dismiss = find.text(l10n.readerSelectionTipDismiss);
      expect(
        tester.getRect(dismiss).left,
        greaterThan(tester.getRect(title).right),
      );

      await pumpCard(
        tester,
        textScale: ReaderSelectionTipCard.stackedTextScale,
      );
      expect(
        tester.getRect(dismiss).top,
        greaterThan(tester.getRect(title).bottom),
      );
      expect(
        tester
            .getRect(
              find.widgetWithText(
                TextButton,
                l10n.readerSelectionTipDismiss,
              ),
            )
            .right,
        tester.getRect(card).right - AppSpacing.xs,
        reason: 'aligned to the end',
      );
    });

    testWidgets('RTL leads with the glyph on the right, Got it on the left', (
      tester,
    ) async {
      await pumpCard(tester, locale: const Locale('ar'));
      final l10n = l10nOf(tester, card);
      final glyph = tester.getRect(
        find.descendant(of: card, matching: find.byType(Icon)),
      );
      final dismiss = tester.getRect(
        find.text(l10n.readerSelectionTipDismiss),
      );
      expect(glyph.left, greaterThan(dismiss.right));
    });
  });

  group('ReaderSelectionTipOverlay', () {
    testWidgets('shows nothing until the tip is due', (tester) async {
      await pumpHost(tester, overlay());
      expect(card, findsNothing);
      expect(find.byType(ToastAvoidArea), findsNothing);
    });

    testWidgets('sits above the safe area inside a ToastAvoidArea', (
      tester,
    ) async {
      await pumpHost(
        tester,
        overlay(),
        padding: const EdgeInsets.only(bottom: 34),
      );
      cubit.showIfDue();
      await tester.pump();

      expect(
        find.ancestor(of: card, matching: find.byType(ToastAvoidArea)),
        findsOneWidget,
      );
      final rect = tester.getRect(card);
      expect(rect.left, AppSpacing.lg);
      expect(rect.right, 390 - AppSpacing.lg);
      expect(rect.bottom, 844 - 34 - AppSpacing.lg);
    });

    testWidgets('a tablet keeps the tip at a readable width', (tester) async {
      await pumpHost(tester, overlay(), size: const Size(1024, 768));
      cubit.showIfDue();
      await tester.pump();

      final rect = tester.getRect(card);
      expect(rect.width, ReaderSelectionTipOverlay.maxWidth);
      expect(rect.center.dx, closeTo(512, 0.01));
    });

    testWidgets('fades in and out with motion', (tester) async {
      await pumpHost(tester, overlay(), reduceMotion: false);
      cubit.showIfDue();
      await tester.pump();
      await tester.pump(AppMotion.short ~/ 2);
      final fade = tester.widget<FadeTransition>(
        find.ancestor(of: card, matching: find.byType(FadeTransition)).first,
      );
      expect(fade.opacity.value, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(fade.opacity.value, 1);

      cubit.hideForSession();
      await tester.pump();
      await tester.pump();
      expect(card, findsOneWidget, reason: 'still fading out');
      await tester.pumpAndSettle();
      expect(card, findsNothing);
    });

    testWidgets('appears at once under reduced motion', (tester) async {
      await pumpHost(tester, overlay());
      cubit.showIfDue();
      await tester.pump();
      await tester.pump();

      final fade = tester.widget<FadeTransition>(
        find.ancestor(of: card, matching: find.byType(FadeTransition)).first,
      );
      expect(fade.opacity.value, 1);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('Got it ends the tip for good', (tester) async {
      await pumpHost(tester, overlay());
      cubit.showIfDue();
      await tester.pump();

      await tester.tap(
        find.text(l10nOf(tester, card).readerSelectionTipDismiss),
      );
      await tester.pumpAndSettle();

      expect(card, findsNothing);
      expect(cubit.state, ReaderSelectionTipPhase.done);
      expect(preferences.current.readerSelectionTipDismissed, isTrue);
    });

    testWidgets('taps beside the plate reach the page below', (tester) async {
      var pageTaps = 0;
      await pumpHost(
        tester,
        Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => pageTaps++,
              ),
            ),
            overlay(),
          ],
        ),
      );
      cubit.showIfDue();
      await tester.pump();

      final rect = tester.getRect(card);
      await tester.tapAt(Offset(rect.center.dx, rect.top - 4));
      await tester.tapAt(Offset(rect.left - 8, rect.center.dy));
      expect(pageTaps, 2);
    });
  });

  group('large text', () {
    for (final locale in ReadflexSupportedLocales.locales) {
      testWidgets('200% text on a 320dp phone stays within its height limit: '
          '$locale', (tester) async {
        await pumpHost(
          tester,
          overlay(),
          textScale: 2,
          size: const Size(320, 568),
          locale: locale,
        );
        cubit.showIfDue();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final rect = tester.getRect(card);
        expect(
          rect.height,
          lessThanOrEqualTo(568 * ReaderSelectionTipOverlay.maxHeightFraction),
        );
        expect(rect.right, lessThanOrEqualTo(320));
        final l10n = l10nOf(tester, card);
        expect(
          find.text(l10n.readerSelectionTipDismiss).hitTestable(),
          findsOneWidget,
          reason: 'Got it stays reachable',
        );
      });
    }
  });

  group('ReaderSelectionTipScope', () {
    Future<void> pumpScope(
      WidgetTester tester, {
      bool textPageVisible = false,
      bool controlsVisible = false,
      bool hasSelection = false,
    }) => pumpHost(
      tester,
      ReaderSelectionTipScope(
        textPageVisible: textPageVisible,
        controlsVisible: controlsVisible,
        hasSelection: hasSelection,
        child: const SizedBox.shrink(),
      ),
    );

    testWidgets('a bare text page shows the tip', (tester) async {
      await pumpScope(tester);
      expect(cubit.state, ReaderSelectionTipPhase.waiting);

      await pumpScope(tester, textPageVisible: true);
      expect(cubit.state, ReaderSelectionTipPhase.visible);
    });

    testWidgets('controls hide a visible tip for the session', (tester) async {
      await pumpScope(tester, textPageVisible: true);
      await pumpScope(tester, controlsVisible: true);
      await tester.pump();

      expect(cubit.state, ReaderSelectionTipPhase.done);
      expect(preferences.current.readerSelectionTipDismissed, isFalse);
    });

    testWidgets('controls before the tip appears keep it due', (tester) async {
      await pumpScope(tester, controlsVisible: true);
      expect(cubit.state, ReaderSelectionTipPhase.waiting);

      await pumpScope(tester, textPageVisible: true);
      expect(cubit.state, ReaderSelectionTipPhase.visible);
    });

    testWidgets('a selection ends the tip for good', (tester) async {
      await pumpScope(tester, textPageVisible: true);
      await pumpScope(tester, hasSelection: true);
      await tester.pump();

      expect(cubit.state, ReaderSelectionTipPhase.done);
      expect(preferences.current.readerSelectionTipDismissed, isTrue);
    });
  });

  group('ReaderSelectionTipDriver', () {
    final epub = Book(
      id: 'book-1',
      title: 'Test Book',
      filePath: '/books/test.epub',
      format: BookFormat.epub,
      addedAt: DateTime(2024, 1, 1),
    );

    late ReaderBloc bloc;
    late ReaderUiCubit ui;
    late ReaderSearchCubit search;
    late ReaderSelectionCubit selection;

    setUp(() {
      bloc = ReaderBloc(
        bookRepository: FakeBookRepository(),
        highlightRepository: FakeHighlightRepository(),
      );
      ui = ReaderUiCubit();
      search = ReaderSearchCubit();
      selection = ReaderSelectionCubit();
    });
    tearDown(() async {
      await bloc.close();
      await ui.close();
      await search.close();
      await selection.close();
    });

    void emitReady(Book book, {ReaderDocumentFeatures? features}) {
      bloc.emit(
        ReaderState(
          status: ReaderStatus.ready,
          title: book.title,
          document: ReaderDocument.fromBook(book),
          sourceType: SourceType.book,
          documentFeatures: features,
        ),
      );
    }

    Future<void> pumpDriver(WidgetTester tester, {bool webViewReady = true}) =>
        pumpHost(
          tester,
          MultiBlocProvider(
            providers: [
              BlocProvider.value(value: bloc),
              BlocProvider.value(value: ui),
              BlocProvider.value(value: search),
              BlocProvider.value(value: selection),
            ],
            child: Stack(
              children: [ReaderSelectionTipDriver(webViewReady: webViewReady)],
            ),
          ),
        );

    testWidgets('shows on a loaded book page and hides with the chrome', (
      tester,
    ) async {
      emitReady(epub);
      await pumpDriver(tester, webViewReady: false);
      await tester.pump();
      expect(card, findsNothing, reason: 'the WebView has not painted yet');

      await pumpDriver(tester);
      await tester.pump();
      expect(card, findsOneWidget);

      ui.showChrome();
      await tester.pumpAndSettle();
      expect(card, findsNothing);
      expect(cubit.state, ReaderSelectionTipPhase.done);
      expect(preferences.current.readerSelectionTipDismissed, isFalse);

      ui.hideChrome();
      await tester.pumpAndSettle();
      expect(card, findsNothing, reason: 'once per session');
    });

    testWidgets('a selection ends the tip for good', (tester) async {
      emitReady(epub);
      await pumpDriver(tester);
      await tester.pump();
      expect(card, findsOneWidget);

      selection.select(text: 'weightless');
      await tester.pumpAndSettle();
      expect(card, findsNothing);
      expect(preferences.current.readerSelectionTipDismissed, isTrue);
    });

    testWidgets('comics never show the tip', (tester) async {
      emitReady(
        epub.copyWith(filePath: '/books/comic.cbz', format: BookFormat.cbz),
      );
      await pumpDriver(tester);
      await tester.pump();
      expect(card, findsNothing);
      expect(cubit.state, ReaderSelectionTipPhase.waiting);
    });

    testWidgets('a PDF shows it once its text layer is known', (tester) async {
      final pdf = epub.copyWith(
        filePath: '/books/scan.pdf',
        format: BookFormat.pdf,
      );
      emitReady(pdf);
      await pumpDriver(tester);
      await tester.pump();
      expect(card, findsNothing);

      emitReady(
        pdf,
        features: const ReaderDocumentFeatures(
          format: 'pdf',
          hasSearchableText: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(card, findsOneWidget);
    });
  });
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}
