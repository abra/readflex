import 'dart:ui' show Tristate;

import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:translate/src/translation_language_direction.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Geist')..addFont(
          rootBundle.load(
            'packages/component_library/fonts/Geist-Variable.ttf',
          ),
        ))
        .load();
  });
  testWidgets('language menu uses two columns and keeps auto source-only', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpDirection(tester);
    await tester.tap(find.byKey(_sourceKey));
    await tester.pumpAndSettle();
    final english = find.widgetWithText(MenuItemButton, 'English');
    final chinese = find.widgetWithText(MenuItemButton, '中文（简体）');
    expect(tester.getTopLeft(english).dy, tester.getTopLeft(chinese).dy);
    expect(
      tester.getTopLeft(english).dx,
      lessThan(tester.getTopLeft(chinese).dx),
    );
    expect(find.widgetWithText(MenuItemButton, 'Auto'), findsOneWidget);
    expect(tester.getSize(english).height, greaterThanOrEqualTo(48));
    await tester.tap(english);
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNothing);
    await tester.tap(find.byKey(_targetKey));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(MenuItemButton, 'Auto'), findsNothing);
  });

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
          const sourceLabel = 'English';
          final targetLabel = translationLanguageName(locale.languageCode)!;
          expect(
            find.descendant(
              of: find.byKey(_sourceKey),
              matching: find.text(sourceLabel),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: find.byKey(_targetKey),
              matching: find.text(targetLabel),
            ),
            findsOneWidget,
          );
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
    final theme = Theme.of(tester.element(find.byKey(_sourceKey)));
    expect(theme.textButtonTheme.style?.backgroundColor, isNull);
    for (final key in [_sourceKey, _targetKey]) {
      final finder = find.byKey(key);
      final button = tester.widget<TextButton>(finder);
      expect(button.style?.backgroundColor, isNull);
      expect(tester.getSize(finder).height, AppSizes.buttonHeight);
    }
  });

  testWidgets('pickers take shape and colours from the text-button theme', (
    tester,
  ) async {
    await _pumpDirection(tester);
    final context = tester.element(find.byKey(_sourceKey));
    final themeStyle = Theme.of(context).textButtonTheme.style!;
    expect(
      themeStyle.shape!.resolve({}),
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
    );
    for (final key in [_sourceKey, _targetKey]) {
      final style = tester.widget<TextButton>(find.byKey(key)).style!;
      expect(style.shape, isNull);
      expect(style.backgroundColor, isNull);
      expect(style.foregroundColor, isNull);
      expect(style.side, isNull);
      expect(style.textStyle!.resolve({}), context.text.bodySmall);
      expect(
        style.minimumSize!.resolve({}),
        const Size(0, AppSizes.buttonHeight),
      );
    }
  });

  for (final locale in [const Locale('en'), const Locale('ar')]) {
    final rtl = locale.languageCode == 'ar';
    testWidgets('source label starts on the content edge and the target '
        'keeps symmetric ink: $locale', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pumpDirection(tester, locale: locale);
      // The host pads by the sheet gutter, like `headerBottom`.
      final host = tester.getRect(find.byType(TranslationLanguageDirection));
      final source = find.byKey(_sourceKey);
      final target = find.byKey(_targetKey);
      final sourceLabel = tester.getRect(
        find.descendant(of: source, matching: find.byType(Text)),
      );
      final targetButton = tester.getRect(target);
      final targetLabel = tester.getRect(
        find.descendant(of: target, matching: find.byType(Text)),
      );
      final targetChevron = tester.getRect(
        find.descendant(of: target, matching: find.byType(Icon)),
      );
      // The measured width rounds up to whole pixels; the centred target
      // picker splits that remainder, so its ink is symmetric within 0.5dp.
      const rounding = 0.5;
      if (rtl) {
        expect(host.right, 390 - AppSpacing.xl);
        expect(sourceLabel.right, host.right);
        expect(
          targetButton.right - targetLabel.right,
          closeTo(AppSpacing.xxs, rounding),
        );
        expect(
          targetChevron.left - targetButton.left,
          closeTo(AppSpacing.xxs, rounding),
        );
      } else {
        expect(host.left, AppSpacing.xl);
        expect(sourceLabel.left, host.left);
        expect(
          targetLabel.left - targetButton.left,
          closeTo(AppSpacing.xxs, rounding),
        );
        expect(
          targetButton.right - targetChevron.right,
          closeTo(AppSpacing.xxs, rounding),
        );
      }
      expect(
        tester.getSize(source).height,
        greaterThanOrEqualTo(AppSizes.buttonHeight),
      );
      _expectNoTruncatedLabels(tester);
      expect(tester.takeException(), isNull);
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      'unfilled language labels have readable contrast: $brightness',
      (tester) async {
        await _pumpDirection(tester, brightness: brightness);
        final finder = find.byKey(_sourceKey);
        final theme = Theme.of(tester.element(finder));
        final foreground = theme.textButtonTheme.style!.foregroundColor!
            .resolve({})!;
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
        // Full width inside the sheet gutter, like the `headerBottom` slot.
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: SizedBox(
            width: double.infinity,
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
