import 'dart:ui' show Tristate;

import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:translate/src/translation_language_direction.dart';

void main() {
  for (final locale in ReadflexSupportedLocales.locales) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('language menus fit a narrow phone: $locale at ${scale}x', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final semantics = tester.ensureSemantics();
        try {
          final targets = <String>[];
          await _pumpDirection(
            tester,
            locale: locale,
            scale: scale,
            target: locale.languageCode,
            onTargetChanged: targets.add,
          );

          final context = tester.element(
            find.byType(TranslationLanguageDirection),
          );
          final sourceLabel = context.l10n.translationAutoDetectedSource(
            'English',
          );
          final targetLabel = translationLanguageName(locale.languageCode)!;
          expect(find.text(sourceLabel), findsOneWidget);
          expect(find.text(targetLabel), findsOneWidget);
          expect(
            find.bySemanticsLabel(context.l10n.translationSourceLanguage),
            findsOne,
          );
          expect(
            find.bySemanticsLabel(context.l10n.translationTargetLanguage),
            findsOne,
          );
          for (final key in [_sourceKey, _targetKey]) {
            final rect = tester.getRect(find.byKey(key));
            expect(rect.height, greaterThanOrEqualTo(AppSizes.buttonHeight));
            expect(rect.left, greaterThanOrEqualTo(AppSpacing.xl));
            expect(rect.right, lessThanOrEqualTo(320 - AppSpacing.xl));
          }
          _expectNoTruncatedLabels(tester);

          await tester.tap(find.byKey(_targetKey));
          await tester.pumpAndSettle();
          _expectNoTruncatedLabels(tester);
          expect(
            tester
                .getSemantics(find.widgetWithText(MenuItemButton, targetLabel))
                .getSemanticsData()
                .flagsCollection
                .isSelected,
            Tristate.isTrue,
          );
          final option = find.widgetWithText(MenuItemButton, '日本語');
          await tester.ensureVisible(option);
          await tester.tap(option);
          await tester.pumpAndSettle();
          expect(targets, ['ja']);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      });
    }
  }

  testWidgets(
    'Arabic direction runs from the source on the right to the target',
    (tester) async {
      await _pumpDirection(tester, locale: const Locale('ar'));
      expect(
        tester.getTopRight(find.byKey(_targetKey)).dx,
        lessThan(tester.getTopLeft(find.byKey(_sourceKey)).dx),
      );
      final arrow = find.byKey(const ValueKey('translation-direction-arrow'));
      final transform = tester.widget<Transform>(
        find.ancestor(of: arrow, matching: find.byType(Transform)).first,
      );
      expect(transform.transform.entry(0, 0), -1);
    },
  );

  testWidgets('loading disables language changes including semantic taps', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pumpDirection(tester, enabled: false);
      for (final key in [_sourceKey, _targetKey]) {
        final finder = find.byKey(key);
        expect(tester.widget<TextButton>(finder).onPressed, isNull);
        await tester.tap(finder);
        await tester.pump();
      }
      expect(find.byType(MenuItemButton), findsNothing);
      final context = tester.element(find.byType(TranslationLanguageDirection));
      expect(
        tester.getSemantics(
          find.bySemanticsLabel(context.l10n.translationSourceLanguage),
        ),
        matchesSemantics(
          label: context.l10n.translationSourceLanguage,
          value: context.l10n.translationAutoDetectedSource('English'),
          isButton: true,
          hasEnabledState: true,
          textDirection: TextDirection.ltr,
        ),
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('language controls are unfilled with full size tap targets', (
    tester,
  ) async {
    await _pumpDirection(tester);
    for (final key in [_sourceKey, _targetKey]) {
      final finder = find.byKey(key);
      final button = tester.widget<TextButton>(finder);
      expect(button.style?.backgroundColor?.resolve({}), Colors.transparent);
      expect(tester.getSize(finder).height, AppSizes.buttonHeight);
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'unfilled language labels have readable contrast: $brightness',
      (tester) async {
        await _pumpDirection(tester, brightness: brightness);
        final finder = find.byKey(_sourceKey);
        final theme = Theme.of(tester.element(finder));
        final button = tester.widget<TextButton>(finder);
        final foreground = button.style!.foregroundColor!.resolve({})!;
        final background =
            theme.bottomSheetTheme.backgroundColor ?? theme.colorScheme.surface;
        final luminances = [
          foreground.computeLuminance(),
          background.computeLuminance(),
        ]..sort();
        expect(
          (luminances.last + 0.05) / (luminances.first + 0.05),
          greaterThanOrEqualTo(4.5),
        );
      },
    );
  }

  testWidgets('auto without a detection stays auto and explicit source wins', (
    tester,
  ) async {
    final sources = <String>[];
    await _pumpDirection(
      tester,
      detectedSource: null,
      onSourceChanged: sources.add,
    );
    expect(find.text('Auto'), findsOneWidget);
    await tester.tap(find.byKey(_sourceKey));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'English'));
    await tester.pumpAndSettle();
    expect(sources, ['en']);

    await _pumpDirection(tester, source: 'fr', detectedSource: 'en');
    expect(find.text('Français'), findsOneWidget);
    expect(find.textContaining('Auto'), findsNothing);
  });

  test('language labels support regional detection codes', () {
    expect(translationLanguageName('EN-us'), 'English');
    expect(translationLanguageName('zh_Hans'), '中文（简体）');
    expect(translationLanguageName('ko'), 'KO');
    expect(translationLanguageName(null), isNull);
  });
}

const _sourceKey = ValueKey('translation-source-language');
const _targetKey = ValueKey('translation-target-language');

Future<void> _pumpDirection(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  double scale = 1,
  String source = 'auto',
  String target = 'ru',
  String? detectedSource = 'en',
  bool enabled = true,
  Brightness brightness = Brightness.light,
  ValueChanged<String>? onSourceChanged,
  ValueChanged<String>? onTargetChanged,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
      supportedLocales: ReadflexSupportedLocales.locales,
      theme: brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: TranslationLanguageDirection(
            sourceLanguageCode: source,
            targetLanguageCode: target,
            detectedSourceLanguage: detectedSource,
            enabled: enabled,
            sourceMenu: MenuController(),
            onSourceChanged: onSourceChanged ?? (_) {},
            onTargetChanged: onTargetChanged ?? (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _expectNoTruncatedLabels(WidgetTester tester) {
  for (final element in find.byType(RichText).evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    expect(paragraph.didExceedMaxLines, isFalse);
  }
}
