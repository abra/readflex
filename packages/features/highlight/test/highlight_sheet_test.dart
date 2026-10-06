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
  progress: 0.42,
  chapterTitle: 'Chapter 4',
);

void main() {
  late FakeHighlightRepository repository;

  setUp(() {
    repository = FakeHighlightRepository();
  });

  Widget buildSubject({Locale locale = const Locale('en')}) => MaterialApp(
    locale: locale,
    supportedLocales: ReadflexSupportedLocales.locales,
    localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
    theme: AppTheme.light(),
    home: Scaffold(
      body: SingleChildScrollView(
        child: HighlightSheet(
          highlightRepository: repository,
          selection: _selection,
        ),
      ),
    ),
  );

  testWidgets('renders title and selected text', (tester) async {
    await tester.pumpWidget(buildSubject());

    expect(find.text('Highlight'), findsOneWidget);
    expect(find.text('Important passage'), findsOneWidget);
  });

  testWidgets('Russian copy and semantics fit a narrow highlight sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    try {
      repository.shouldThrow = true;

      await tester.pumpWidget(buildSubject(locale: const Locale('ru')));
      await tester.pumpAndSettle();

      expect(find.text('Выделение'), findsOneWidget);
      expect(find.text('Important passage'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Желтый цвет выделения')),
        matchesSemantics(
          label: 'Желтый цвет выделения',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          onTapHint: 'Выбрать цвет выделения',
        ),
      );

      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();

      expect(find.text('Не удалось сохранить выделение'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('renders one shared swatch button per color with 48dp targets', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    final swatches = find.byType(AppColorSwatchButton);
    expect(swatches, findsNWidgets(HighlightColor.values.length));
    for (final swatch in swatches.evaluate()) {
      expect(tester.getSize(find.byWidget(swatch.widget)), const Size(48, 48));
    }
    final context = tester.element(find.byType(HighlightSheet));
    final yellow = tester.widget<AppColorSwatchButton>(
      find.byKey(const ValueKey('highlightColorSemantics-yellow')),
    );
    expect(yellow.color, context.appColors.highlightYellow);
    expect(yellow.selected, isTrue);
    expect(yellow.tooltip, 'Yellow');
  });

  testWidgets('color picker exposes labels and selected state to semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(buildSubject());

    expect(
      tester.getSemantics(find.bySemanticsLabel('Yellow highlight color')),
      matchesSemantics(
        label: 'Yellow highlight color',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
        onTapHint: 'Select highlight color',
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Blue highlight color')),
      matchesSemantics(
        label: 'Blue highlight color',
        isButton: true,
        hasSelectedState: true,
        isSelected: false,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
        onTapHint: 'Select highlight color',
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('highlightColorSemantics-blue')),
    );
    await tester.pump();

    expect(
      tester.getSemantics(find.bySemanticsLabel('Blue highlight color')),
      matchesSemantics(
        label: 'Blue highlight color',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
        onTapHint: 'Select highlight color',
      ),
    );

    semantics.dispose();
  });

  testWidgets('renders note field', (tester) async {
    await tester.pumpWidget(buildSubject());

    expect(find.text('Add a note (optional)'), findsOneWidget);
  });

  testWidgets('save button is enabled by default', (tester) async {
    await tester.pumpWidget(buildSubject());

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('shows error message on save failure', (tester) async {
    repository.shouldThrow = true;
    await tester.pumpWidget(buildSubject());

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text('Failed to save highlight'), findsOneWidget);
  });

  testWidgets('successful save adds highlight to repository', (tester) async {
    await tester.pumpWidget(buildSubject());

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(repository.highlights, hasLength(1));
    expect(repository.highlights.first.text, 'Important passage');
    expect(repository.highlights.first.sourceId, 'book-1');
    expect(repository.highlights.first.progress, 0.42);
    expect(repository.highlights.first.chapterTitle, 'Chapter 4');
  });

  testWidgets('note is passed to repository on save', (tester) async {
    await tester.pumpWidget(buildSubject());

    await tester.enterText(find.byType(TextField), 'My note');
    await tester.pump();

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(repository.highlights.first.note, 'My note');
  });
}
