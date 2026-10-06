import 'dart:async';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight/highlight.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:shared/shared.dart';

import 'helpers/fake_highlight_repository.dart';

const _selection = TextSelectionContext(
  selectedText: 'Important passage',
  sourceId: 'book-1',
  sourceType: SourceType.book,
);

const _arabicSelection = TextSelectionContext(
  selectedText: 'فقرة مهمة',
  sourceId: 'book-1',
  sourceType: SourceType.book,
);

void main() {
  late FakeHighlightRepository repository;

  setUp(() {
    repository = FakeHighlightRepository();
  });

  Future<void> openSheet(
    WidgetTester tester, {
    TextSelectionContext selection = _selection,
    HighlightColorResolver? resolveColor,
  }) async {
    late BuildContext hostContext;
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: ReadflexSupportedLocales.locales,
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            hostContext = context;
            return const Scaffold();
          },
        ),
      ),
    );
    unawaited(
      showHighlightSheet(
        hostContext,
        highlightRepository: repository,
        selection: selection,
        resolveColor: resolveColor,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('has an explicit Close action that pops the sheet', (
    tester,
  ) async {
    await openSheet(tester);
    final close = find.byTooltip('Close');
    expect(close.hitTestable(), findsOneWidget);
    expect(tester.getSize(close).shortestSide, greaterThanOrEqualTo(48));

    await tester.tap(close);
    await tester.pumpAndSettle();

    expect(find.byType(HighlightSheet), findsNothing);
    expect(repository.highlights, isEmpty);
  });

  testWidgets('header and body are 8dp apart like the other text sheets', (
    tester,
  ) async {
    await openSheet(tester);
    final header = tester.getRect(find.byType(BottomSheetHeader));
    final preview = tester.getRect(find.byType(SelectionPreviewCard));
    expect(preview.top - header.bottom, AppSpacing.sm);
    final sheet = tester.getRect(find.byType(HighlightSheet));
    expect(preview.left - sheet.left, AppSpacing.xl);
    expect(sheet.right - preview.right, AppSpacing.xl);
  });

  testWidgets('preview follows the selected text direction', (tester) async {
    await openSheet(tester, selection: _arabicSelection);
    expect(
      tester
          .widget<SelectionPreviewCard>(find.byType(SelectionPreviewCard))
          .textDirection,
      TextDirection.rtl,
    );
    expect(
      tester.widget<Text>(find.text('فقرة مهمة')).textDirection,
      TextDirection.rtl,
    );

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await openSheet(tester);
    expect(
      tester
          .widget<SelectionPreviewCard>(find.byType(SelectionPreviewCard))
          .textDirection,
      TextDirection.ltr,
    );
  });

  testWidgets('a palette override tints the swatches and the preview', (
    tester,
  ) async {
    const palette = {
      HighlightColor.yellow: Color(0xFF111111),
      HighlightColor.green: Color(0xFF222222),
      HighlightColor.blue: Color(0xFF333333),
      HighlightColor.pink: Color(0xFF444444),
      HighlightColor.purple: Color(0xFF555555),
    };
    await openSheet(tester, resolveColor: (color) => palette[color]!);

    for (final color in HighlightColor.values) {
      final swatch = tester.widget<AppColorSwatchButton>(
        find.byKey(ValueKey('highlightColorSemantics-${color.name}')),
      );
      expect(swatch.color, palette[color]);
    }
    final preview = tester.widget<SelectionPreviewCard>(
      find.byType(SelectionPreviewCard),
    );
    expect(
      preview.backgroundColor,
      palette[HighlightColor.yellow]!.withValues(alpha: 0.3),
    );

    await tester.tap(
      find.byKey(const ValueKey('highlightColorSemantics-blue')),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SelectionPreviewCard>(find.byType(SelectionPreviewCard))
          .backgroundColor,
      palette[HighlightColor.blue]!.withValues(alpha: 0.3),
    );
    // Dark override swatches get the dark-swatch check ink.
    final context = tester.element(find.byType(HighlightSheet));
    expect(
      tester.widget<Icon>(find.byIcon(AppIcons.check)).color,
      context.appColors.onDarkSwatch,
    );
  });

  testWidgets('default palette comes from the app theme', (tester) async {
    await openSheet(tester);
    final context = tester.element(find.byType(HighlightSheet));
    final purple = tester.widget<AppColorSwatchButton>(
      find.byKey(const ValueKey('highlightColorSemantics-purple')),
    );
    expect(purple.color, context.appColors.highlightPurple);
    expect(
      tester.widget<Icon>(find.byIcon(AppIcons.check)).color,
      context.appColors.onLightSwatch,
    );
  });

  testWidgets('save failure announces an inline error above Save', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      repository.shouldThrow = true;
      await openSheet(tester);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final error = find.text('Failed to save highlight');
      expect(error, findsOneWidget);
      final context = tester.element(error);
      expect(
        tester.widget<Text>(error).style!.color,
        Theme.of(context).colorScheme.error,
      );
      expect(
        tester.getSemantics(error),
        matchesSemantics(label: 'Failed to save highlight', isLiveRegion: true),
      );
      expect(
        tester.getBottomLeft(error).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.byType(FilledButton)).dy),
      );
      expect(find.byType(AppStatusMessage), findsNothing);
      // Save stays enabled as the retry.
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('swatches are disabled while saving', (tester) async {
    repository.awaitGate = Completer<void>();
    await openSheet(tester);
    await tester.tap(find.text('Save'));
    await tester.pump();

    for (final swatch in find.byType(AppColorSwatchButton).evaluate()) {
      expect((swatch.widget as AppColorSwatchButton).onPressed, isNull);
    }
    expect(find.byType(ButtonLoadingIndicator), findsOneWidget);

    repository.awaitGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(HighlightSheet), findsNothing);
    expect(repository.highlights, hasLength(1));
  });

  group('note draft guard', () {
    Future<void> typeNote(WidgetTester tester) async {
      await tester.enterText(find.byType(TextField), 'Worth rereading');
      // Guard changes publish after the frame.
      await tester.pump();
      await tester.pump();
    }

    testWidgets('an empty note closes on scrim like any sheet', (
      tester,
    ) async {
      await openSheet(tester);
      await tester.tapAt(const Offset(10, 20));
      await tester.pumpAndSettle();
      expect(find.byType(HighlightSheet), findsNothing);
    });

    testWidgets('scrim with a typed note asks to discard; Keep editing '
        'returns to the form with the note', (tester) async {
      await openSheet(tester);
      await typeNote(tester);
      await tester.tapAt(const Offset(10, 20));
      await tester.pumpAndSettle();
      expect(find.byType(HighlightSheet), findsOneWidget);
      expect(find.text('Discard changes?'), findsOneWidget);
      // Safe default: Keep editing filled, Discard outlined.
      expect(find.widgetWithText(FilledButton, 'Keep editing'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Discard'), findsOneWidget);

      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Worth rereading'), findsOneWidget);
    });

    testWidgets('Close with a typed note asks; Discard closes', (
      tester,
    ) async {
      await openSheet(tester);
      await typeNote(tester);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.byType(HighlightSheet), findsNothing);
      expect(repository.highlights, isEmpty);
    });

    testWidgets('drag-down with a typed note keeps the sheet', (
      tester,
    ) async {
      await openSheet(tester);
      await typeNote(tester);
      await tester.drag(find.text('Worth rereading'), const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(find.byType(HighlightSheet), findsOneWidget);
    });

    testWidgets('system Back with a typed note asks, Back again keeps '
        'editing', (tester) async {
      await openSheet(tester);
      await typeNote(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Worth rereading'), findsOneWidget);
    });

    testWidgets('Save stays reachable at 2x text with the keyboard up', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 380);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await openSheet(tester);
      expect(tester.takeException(), isNull);
      final save = find.widgetWithText(FilledButton, 'Save');
      expect(save.hitTestable(), findsOneWidget);
      expect(tester.getRect(save).bottom, lessThanOrEqualTo(844 - 380));
    });
  });
}
