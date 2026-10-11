import 'dart:math' as math;

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex/app/screens/onboarding_app_icon.dart';
import 'package:readflex/app/screens/onboarding_feature_list.dart';
import 'package:readflex/app/screens/onboarding_heading.dart';
import 'package:readflex/app/screens/onboarding_screen.dart';
import 'package:readflex/app/screens/onboarding_selection_sample.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'golden_support.dart';

void main() {
  setUpAll(loadUiFonts);

  ReadflexLocalizations l10nOf(WidgetTester tester) =>
      ReadflexLocalizations.of(tester.element(find.byType(OnboardingScreen)))!;

  /// Pumps onboarding and decodes the app icon, which a widget test only
  /// loads inside [WidgetTester.runAsync].
  Future<void> pumpOnboarding(
    WidgetTester tester, {
    VisualProfile profile = VisualProfile.phone,
    Size? size,
    Locale? locale,
    VoidCallback? onAddBook,
    VoidCallback? onNotNow,
  }) async {
    await pumpGoldenSurface(
      tester,
      profile,
      (_) => OnboardingScreen(
        onAddBook: onAddBook ?? () {},
        onNotNow: onNotNow ?? () {},
      ),
      surfaceSize: size,
      locale: locale,
    );
    await tester.runAsync(
      () => precacheImage(
        const AssetImage(onboardingAppIconAsset),
        tester.element(find.byType(OnboardingScreen)),
      ),
    );
    await tester.pump();
  }

  Finder addBook(ReadflexLocalizations l10n) =>
      find.widgetWithText(FilledButton, l10n.onboardingAddBook);

  Finder notNow(ReadflexLocalizations l10n) =>
      find.widgetWithText(TextButton, l10n.onboardingNotNow);

  final sample = find.byType(OnboardingSelectionSample);
  final menu = find.byKey(const ValueKey('onboardingSelectionMenu'));
  final featureRows = find.byType(OnboardingFeatureRow);

  /// The paper card: the sample's first decorated box.
  final card = find
      .descendant(of: sample, matching: find.byType(DecoratedBox))
      .first;

  double tiltOf(WidgetTester tester) {
    final transform = tester
        .widget<Transform>(
          find.descendant(of: sample, matching: find.byType(Transform)).first,
        )
        .transform;
    return math.atan2(transform.entry(1, 0), transform.entry(0, 0));
  }

  /// The span painted as selected text in the sample sentence.
  TextSpan selectedSpan(WidgetTester tester) {
    TextSpan? selected;
    for (final paragraph in tester.widgetList<RichText>(
      find.descendant(of: sample, matching: find.byType(RichText)),
    )) {
      paragraph.text.visitChildren((span) {
        if (span is TextSpan && span.style?.backgroundColor != null) {
          selected = span;
          return false;
        }
        return true;
      });
    }
    return selected ?? (throw StateError('no selected span'));
  }

  group('welcome', () {
    testWidgets('greets as Readflex with the app icon above the heading', (
      tester,
    ) async {
      await pumpOnboarding(tester);
      final l10n = l10nOf(tester);

      final image = tester.widget<Image>(
        find.descendant(
          of: find.byType(OnboardingAppIcon),
          matching: find.byType(Image),
        ),
      );
      expect((image.image as AssetImage).assetName, onboardingAppIconAsset);
      expect(image.excludeFromSemantics, isTrue);
      expect(
        tester.getSize(find.byType(OnboardingAppIcon)),
        const Size.square(OnboardingAppIcon.size),
      );

      final heading = find.text(l10n.onboardingWelcomeTitle);
      final subtitle = find.text(l10n.onboardingWelcomeSubtitle);
      expect(heading, findsOneWidget);
      expect(subtitle, findsOneWidget);
      expect(l10n.onboardingWelcomeTitle, contains('Readflex'));

      // One screen: no pager, dots or Skip, and only Not now as a text button.
      expect(find.byType(PageView), findsNothing);
      expect(find.byType(TextButton), findsOneWidget);

      // Top to bottom: icon, heading, subtitle, sample, features, actions.
      final order = [
        find.byType(OnboardingAppIcon),
        heading,
        subtitle,
        menu,
        featureRows.first,
        featureRows.last,
        addBook(l10n),
        notNow(l10n),
      ].map((finder) => tester.getRect(finder).top).toList();
      expect(order, orderedEquals([...order]..sort()));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the icon keeps a hairline edge in both themes', (
      tester,
    ) async {
      for (final profile in [VisualProfile.phone, VisualProfile.dark]) {
        await pumpOnboarding(tester, profile: profile);
        final edge = tester.widget<DecoratedBox>(
          find.descendant(
            of: find.byType(OnboardingAppIcon),
            matching: find.byType(DecoratedBox),
          ),
        );
        final colors = Theme.of(
          tester.element(find.byType(OnboardingAppIcon)),
        ).colorScheme;
        final decoration = edge.decoration as BoxDecoration;
        expect(edge.position, DecorationPosition.foreground);
        expect(decoration.border, Border.all(color: colors.outlineVariant));
        expect(
          decoration.borderRadius,
          BorderRadius.circular(OnboardingAppIcon.cornerRadius),
        );
      }
    });
  });

  group('heading', () {
    // The square test font: every glyph is one em wide.
    const style = TextStyle(fontFamily: 'FlutterTest', fontSize: 20);

    double scaleOf(
      String text, {
      required double width,
      TextScaler textScaler = TextScaler.noScaling,
    }) => onboardingHeadingFontScale(
      text: text,
      style: style,
      textScaler: textScaler,
      textDirection: TextDirection.ltr,
      maxWidth: width,
    );

    test('keeps the role size while every word fits', () {
      expect(scaleOf('Hello world', width: 100), 1);
      expect(scaleOf('', width: 10), 1);
      expect(scaleOf('Hello', width: double.infinity), 1);
    });

    test('shrinks just enough for the longest word to fit', () {
      // "Willkommen": 10 glyphs, 200px at 20px; 150px fits it at 15px.
      expect(scaleOf('Willkommen bei Readflex', width: 150), closeTo(.75, .02));
      expect(
        scaleOf('Hello', width: 150, textScaler: const TextScaler.linear(2)),
        closeTo(.75, .02),
      );
    });

    test('never shrinks below the minimum', () {
      expect(
        scaleOf('Supercalifragilistic', width: 100),
        kOnboardingHeadingMinFontScale,
      );
    });

    test('pieces are words, with CJK characters on their own', () {
      expect(onboardingHeadingPieces('Welcome to Readflex'), [
        'Welcome',
        'to',
        'Readflex',
      ]);
      expect(onboardingHeadingPieces('  Добро  пожаловать '), [
        'Добро',
        'пожаловать',
      ]);
      expect(onboardingHeadingPieces('Readflexへようこそ'), [
        'Readflex',
        'へ',
        'よ',
        'う',
        'こ',
        'そ',
      ]);
      expect(onboardingHeadingPieces('欢迎使用 Readflex'), [
        '欢',
        '迎',
        '使',
        '用',
        'Readflex',
      ]);
      expect(
        onboardingHeadingPieces('Readflex में आपका स्वागत है'),
        hasLength(5),
      );
      expect(onboardingHeadingPieces('😀 hi'), ['😀', 'hi']);
      expect(onboardingHeadingPieces(''), isEmpty);
    });

    test('scripts that break between characters never shrink', () {
      expect(scaleOf('欢迎使用阅读器', width: 50), 1);
      expect(scaleOf('Readflexへようこそ', width: 170), 1);
    });

    testWidgets('200% German text shrinks the heading instead of breaking '
        'Willkommen', (tester) async {
      await pumpOnboarding(
        tester,
        profile: VisualProfile.largeText,
        locale: const Locale('de'),
      );
      final l10n = l10nOf(tester);
      final heading = find.text(l10n.onboardingWelcomeTitle);
      final role = Theme.of(tester.element(heading)).textTheme.headlineSmall!;
      final text = tester.widget<Text>(heading);
      expect(text.style!.fontSize, lessThan(role.fontSize!));

      final paragraph = tester.renderObject<RenderParagraph>(heading);
      expect(
        paragraph.getMinIntrinsicWidth(double.infinity),
        lessThanOrEqualTo(paragraph.size.width + 0.5),
      );
    });

    testWidgets('a phone keeps the role size', (tester) async {
      await pumpOnboarding(tester);
      final heading = find.text(l10nOf(tester).onboardingWelcomeTitle);
      final role = Theme.of(tester.element(heading)).textTheme.headlineSmall!;
      expect(tester.widget<Text>(heading).style!.fontSize, role.fontSize);
    });
  });

  group('features', () {
    testWidgets('four rows: files, articles, the real lookup labels, notes', (
      tester,
    ) async {
      await pumpOnboarding(tester);
      final l10n = l10nOf(tester);
      final rows = tester.widgetList<OnboardingFeatureRow>(featureRows);

      expect(rows.map((row) => row.icon), [
        AppIcons.book,
        AppIcons.language,
        AppIcons.translate,
        AppIcons.highlight,
      ]);
      expect(rows.map((row) => row.title), [
        l10n.onboardingFeatureBooksTitle,
        l10n.onboardingFeatureArticlesTitle,
        l10n.onboardingFeatureLookupTitle,
        l10n.onboardingFeatureHighlightsTitle,
      ]);
      expect(rows.map((row) => row.description), [
        l10n.onboardingFeatureBooksDescription,
        l10n.onboardingFeatureArticlesDescription,
        l10n.onboardingFeatureLookupDescription(
          l10n.translationAction,
          l10n.dictionaryAction,
        ),
        l10n.onboardingFeatureHighlightsDescription,
      ]);
      expect(tester.takeException(), isNull);
    });

    test('the highlights copy says five colors because there are five', () {
      expect(HighlightColor.values, hasLength(5));
    });

    testWidgets('each row is an accent glyph on a tonal tile and one item', (
      tester,
    ) async {
      await pumpOnboarding(tester);
      final row = featureRows.first;
      final context = tester.element(row);
      final colors = Theme.of(context).colorScheme;

      final tile = find
          .descendant(of: row, matching: find.byType(DecoratedBox))
          .first;
      expect(
        tester.getSize(tile),
        const Size.square(OnboardingFeatureRow.tileSize),
      );
      final decoration = tester.widget<DecoratedBox>(tile).decoration;
      expect((decoration as BoxDecoration).color, colors.surfaceContainerLow);
      final glyph = tester.widget<Icon>(
        find.descendant(of: row, matching: find.byType(Icon)),
      );
      expect(glyph.size, AppIconSize.sm);
      expect(glyph.color, context.actionForeground);

      final title = tester.widget<OnboardingFeatureRow>(row).title;
      final description = tester.widget<OnboardingFeatureRow>(row).description;
      final semantics = tester.ensureSemantics();
      try {
        expect(
          tester.getSemantics(find.text(title)),
          matchesSemantics(label: '$title\n$description'),
        );
      } finally {
        semantics.dispose();
      }
    });
  });

  group('sample', () {
    testWidgets('a tilted Paper page with the real selection menu', (
      tester,
    ) async {
      await pumpOnboarding(tester);
      final l10n = l10nOf(tester);
      final page = ReaderThemePreset.paper.data;
      final colors = Theme.of(tester.element(sample)).colorScheme;

      final cardDecoration =
          tester.widget<DecoratedBox>(card).decoration as BoxDecoration;
      expect(cardDecoration.color, page.backgroundColor);
      expect(cardDecoration.borderRadius, BorderRadius.circular(AppRadius.lg));
      expect(cardDecoration.boxShadow, AppShadows.popover);
      expect(tiltOf(tester), closeTo(OnboardingSelectionSample.tilt, 1e-9));

      // The menu: app surface, outline hairline, 16dp radius, popover shadow,
      // and the reader's 304dp width over two 52dp rows.
      final menuDecoration =
          tester.widget<DecoratedBox>(menu).decoration as BoxDecoration;
      expect(menuDecoration.color, colors.surface);
      expect(
        menuDecoration.border!.top.color,
        colors.outlineVariant.withValues(alpha: 0.72),
      );
      expect(menuDecoration.borderRadius, BorderRadius.circular(AppRadius.lg));
      expect(menuDecoration.boxShadow, AppShadows.popover);
      expect(
        tester.getSize(menu),
        const Size(
          OnboardingSelectionSample.menuWidth,
          OnboardingSelectionSample.menuRowHeight * 2 + 1,
        ),
      );

      // Five swatches in the reader's order and Paper colors, yellow chosen.
      final swatches = tester.widgetList<AppColorSwatchButton>(
        find.descendant(of: menu, matching: find.byType(AppColorSwatchButton)),
      );
      expect(swatches.map((swatch) => swatch.color), [
        page.highlightYellow,
        page.highlightGreen,
        page.highlightBlue,
        page.highlightPink,
        page.highlightPurple,
      ]);
      expect(swatches.map((swatch) => swatch.selected), [
        true,
        false,
        false,
        false,
        false,
      ]);
      expect(swatches.map((swatch) => swatch.size), everyElement(24));
      expect(
        find.descendant(of: menu, matching: find.byIcon(AppIcons.highlight)),
        findsOneWidget,
      );

      // Then Copy, Translate and Define, start to end, in the app's ink.
      final labels = [
        for (final action in onboardingSelectionMenuActions) action.label(l10n),
      ];
      expect(labels, [
        l10n.commonCopy,
        l10n.translationAction,
        l10n.dictionaryAction,
      ]);
      final starts = labels
          .map((label) => tester.getRect(find.text(label)).center.dx)
          .toList();
      expect(starts, orderedEquals([...starts]..sort()));
      for (final action in onboardingSelectionMenuActions) {
        final icon = tester.widget<Icon>(
          find.descendant(of: menu, matching: find.byIcon(action.icon)),
        );
        expect(icon.color, colors.onSurface);
        final label = tester.widget<Text>(find.text(action.label(l10n)));
        expect(label.style!.color, colors.onSurface);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('the sentence selects its word in the app selection color', (
      tester,
    ) async {
      await pumpOnboarding(tester);
      final l10n = l10nOf(tester);
      final word = l10n.onboardingSelectionSampleWord;
      final page = ReaderThemePreset.paper.data;

      final sentence = tester
          .widget<RichText>(
            find.descendant(
              of: sample,
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is RichText &&
                    widget.text.toPlainText() ==
                        l10n.onboardingSelectionSampleSentence(word),
              ),
            ),
          )
          .text;
      expect(sentence.style!.fontFamily, AppTypography.fontFamilySerif);
      expect(sentence.style!.color, page.primaryTextColor);

      final selected = selectedSpan(tester);
      expect(selected.text, word);
      expect(
        selected.style!.backgroundColor,
        DefaultSelectionStyle.of(tester.element(sample)).selectionColor,
      );
    });

    testWidgets('dark mode keeps the Paper page and themes the menu', (
      tester,
    ) async {
      await pumpOnboarding(tester, profile: VisualProfile.dark);
      final colors = Theme.of(tester.element(sample)).colorScheme;
      expect(colors.brightness, Brightness.dark);

      final cardDecoration =
          tester.widget<DecoratedBox>(card).decoration as BoxDecoration;
      expect(
        cardDecoration.color,
        ReaderThemePreset.paper.data.backgroundColor,
      );
      final menuDecoration =
          tester.widget<DecoratedBox>(menu).decoration as BoxDecoration;
      expect(menuDecoration.color, colors.surface);
      final copy = tester.widget<Text>(
        find.text(l10nOf(tester).commonCopy),
      );
      expect(copy.style!.color, colors.onSurface);
    });

    testWidgets('is one described image that never takes input', (
      tester,
    ) async {
      await pumpOnboarding(tester);
      final l10n = l10nOf(tester);
      expect(
        tester
            .widget<IgnorePointer>(
              find.descendant(of: sample, matching: find.byType(IgnorePointer)),
            )
            .ignoring,
        isTrue,
      );
      expect(menu.hitTestable(), findsNothing);

      final semantics = tester.ensureSemantics();
      try {
        expect(
          tester.getSemantics(sample),
          matchesSemantics(
            label: l10n.onboardingSelectionSampleLabel(
              l10n.commonCopy,
              l10n.translationAction,
              l10n.dictionaryAction,
            ),
            isImage: true,
          ),
        );
        // The copied menu commands are not announced as buttons.
        expect(find.bySemanticsLabel(l10n.translationAction), findsNothing);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('ignores text scaling and scales down whole on 320dp phones', (
      tester,
    ) async {
      await pumpOnboarding(tester, profile: VisualProfile.largeText);
      final l10n = l10nOf(tester);
      final label = find.text(l10n.commonCopy);
      expect(
        MediaQuery.textScalerOf(tester.element(label)),
        TextScaler.noScaling,
      );

      // At 320dp the 336dp card scales down to the gutters, menu and all.
      final menuWidth = tester.getRect(menu).width;
      expect(menuWidth, lessThan(OnboardingSelectionSample.menuWidth));
      final painted = tester.getRect(card);
      expect(painted.left, greaterThan(0));
      expect(painted.right, lessThan(320));
      expect(tester.takeException(), isNull);
    });

    for (final locale in ReadflexSupportedLocales.locales) {
      testWidgets('selects the localized word: $locale', (tester) async {
        await pumpOnboarding(tester, locale: locale);
        final l10n = l10nOf(tester);
        expect(selectedSpan(tester).text, l10n.onboardingSelectionSampleWord);
        for (final action in onboardingSelectionMenuActions) {
          expect(find.text(action.label(l10n)), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('actions', () {
    testWidgets(
      'Add your first book and Not now call only their own callback',
      (tester) async {
        var added = 0;
        var dismissed = 0;
        await pumpOnboarding(
          tester,
          onAddBook: () => added++,
          onNotNow: () => dismissed++,
        );
        final l10n = l10nOf(tester);
        expect(l10n.onboardingAddBook, 'Add your first book');
        expect(
          find.descendant(
            of: addBook(l10n),
            matching: find.byIcon(AppIcons.add),
          ),
          findsOneWidget,
        );

        await tester.tap(addBook(l10n));
        await tester.pumpAndSettle();
        expect(added, 1);
        expect(dismissed, 0);

        await tester.tap(notNow(l10n));
        await tester.pumpAndSettle();
        expect(added, 1);
        expect(dismissed, 1);
      },
    );

    testWidgets('actions are labeled 48dp buttons; the heading is a header', (
      tester,
    ) async {
      await pumpOnboarding(tester);
      final l10n = l10nOf(tester);
      final semantics = tester.ensureSemantics();
      try {
        for (final (button, label) in [
          (addBook(l10n), l10n.onboardingAddBook),
          (notNow(l10n), l10n.onboardingNotNow),
        ]) {
          expect(
            tester.getSize(button).height,
            greaterThanOrEqualTo(AppSizes.buttonHeight),
          );
          expect(
            tester.getSemantics(button),
            matchesSemantics(
              label: label,
              isButton: true,
              hasEnabledState: true,
              isEnabled: true,
              isFocusable: true,
              hasTapAction: true,
              hasFocusAction: true,
            ),
          );
        }
        expect(
          tester.getSemantics(find.text(l10n.onboardingWelcomeTitle)),
          matchesSemantics(label: l10n.onboardingWelcomeTitle, isHeader: true),
        );
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      } finally {
        semantics.dispose();
      }
    });
  });

  group('layout', () {
    testWidgets('phone content and actions share the 16dp gutter', (
      tester,
    ) async {
      await pumpOnboarding(tester, size: const Size(390, 844));
      final l10n = l10nOf(tester);
      for (final target in [
        addBook(l10n),
        notNow(l10n),
        find.text(l10n.onboardingWelcomeTitle),
        featureRows.first,
      ]) {
        final rect = tester.getRect(target);
        expect(rect.left, AppSpacing.lg, reason: '$target');
        expect(rect.right, 390 - AppSpacing.lg, reason: '$target');
      }
      // The card is centered, unscaled, and its tilted corners stay on screen.
      final slot = find
          .descendant(of: sample, matching: find.byType(Transform))
          .first;
      expect(
        tester.getRect(slot).width,
        OnboardingSelectionSample.cardWidth,
      );
      expect(tester.getRect(slot).center.dx, closeTo(195, 0.01));
      final painted = tester.getRect(card);
      expect(painted.left, greaterThan(0));
      expect(painted.right, lessThan(390));
      expect(
        tester.getRect(find.text(l10n.onboardingWelcomeSubtitle)).bottom,
        lessThan(painted.top),
      );
      expect(painted.bottom, lessThan(tester.getRect(featureRows.first).top));
    });

    testWidgets('a tablet keeps one centered column for content and actions', (
      tester,
    ) async {
      await pumpOnboarding(tester, profile: VisualProfile.tabletRtl);
      final l10n = l10nOf(tester);
      final width = VisualProfile.tabletRtl.size.width;
      for (final target in [
        addBook(l10n),
        notNow(l10n),
        featureRows.first,
      ]) {
        final rect = tester.getRect(target);
        expect(rect.width, OnboardingScreen.maxContentWidth, reason: '$target');
        expect(rect.center.dx, closeTo(width / 2, 0.01), reason: '$target');
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('safe areas keep content and actions inside the insets', (
      tester,
    ) async {
      tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      await pumpOnboarding(tester, size: const Size(390, 844));
      final l10n = l10nOf(tester);
      expect(tester.getRect(find.byType(Scrollable)).top, 47);
      expect(tester.getRect(notNow(l10n)).bottom, 844 - 34 - AppSpacing.lg);
      expect(tester.takeException(), isNull);
    });

    for (final locale in ReadflexSupportedLocales.locales) {
      testWidgets('200% text at 320x568 scrolls without overflow: $locale', (
        tester,
      ) async {
        await pumpOnboarding(
          tester,
          profile: VisualProfile.largeText,
          locale: locale,
        );
        final l10n = l10nOf(tester);
        expect(tester.takeException(), isNull);

        // The actions sit outside the scrolling page and stay on screen.
        final scrollable = find.byType(Scrollable);
        for (final action in [addBook(l10n), notNow(l10n)]) {
          expect(
            find.descendant(of: scrollable, matching: action),
            findsNothing,
          );
          expect(action.hitTestable(), findsOneWidget);
          final rect = tester.getRect(action);
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(rect.bottom, lessThanOrEqualTo(568));
        }

        final position = tester.state<ScrollableState>(scrollable).position;
        expect(position.maxScrollExtent, greaterThan(0));
        await tester.drag(scrollable, const Offset(0, -4000));
        await tester.pumpAndSettle();
        expect(position.pixels, closeTo(position.maxScrollExtent, 0.1));
        expect(
          tester.getRect(featureRows.last).bottom,
          lessThanOrEqualTo(tester.getRect(scrollable).bottom),
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('phone RTL mirrors the tilt, rows and the button icon', (
      tester,
    ) async {
      await pumpOnboarding(
        tester,
        size: const Size(390, 844),
        locale: const Locale('ar'),
      );
      final l10n = l10nOf(tester);
      expect(Directionality.of(tester.element(sample)), TextDirection.rtl);
      expect(tiltOf(tester), closeTo(-OnboardingSelectionSample.tilt, 1e-9));

      final icon = tester.getRect(
        find.descendant(of: addBook(l10n), matching: find.byIcon(AppIcons.add)),
      );
      final label = tester.getRect(
        find.descendant(
          of: addBook(l10n),
          matching: find.text(l10n.onboardingAddBook),
        ),
      );
      expect(icon.left, greaterThan(label.right));

      // The tile leads on the right; the copy commands run right to left.
      final row = featureRows.first;
      final tile = tester.getRect(
        find.descendant(of: row, matching: find.byType(DecoratedBox)).first,
      );
      final title = tester.getRect(
        find.text(tester.widget<OnboardingFeatureRow>(row).title),
      );
      expect(tile.left, greaterThan(title.right));
      final copy = tester.getRect(find.text(l10n.commonCopy)).center.dx;
      final define = tester.getRect(find.text(l10n.dictionaryAction)).center.dx;
      expect(copy, greaterThan(define));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'the screen runs no animation, with or without reduced motion',
      (tester) async {
        // pumpGoldenSurface reduces motion; this host keeps platform motion on.
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            supportedLocales: ReadflexSupportedLocales.locales,
            localizationsDelegates:
                ReadflexLocalizations.localizationsDelegates,
            home: OnboardingScreen(onAddBook: () {}, onNotNow: () {}),
          ),
        );
        await tester.pump();
        expect(tester.hasRunningAnimations, isFalse);
        final tilt = tiltOf(tester);

        await pumpOnboarding(tester);
        expect(tester.hasRunningAnimations, isFalse);
        expect(tiltOf(tester), tilt, reason: 'the tilt is static decoration');
      },
    );
  });

  for (final profile in VisualProfile.values) {
    testWidgets('onboarding ${profile.name}', (tester) async {
      await pumpOnboarding(tester, profile: profile);
      await expectUiGolden(tester, profile, 'onboarding');
      if (profile == VisualProfile.largeText) {
        final scrollable = find.byType(Scrollable);
        final position = tester.state<ScrollableState>(scrollable).position;
        expect(position.maxScrollExtent, greaterThan(0));
        await tester.drag(scrollable, const Offset(0, -4000));
        await tester.pumpAndSettle();
        expect(position.pixels, closeTo(position.maxScrollExtent, 0.1));
        await expectUiGolden(tester, profile, 'onboarding-scrolled');
      }
    }, tags: ['golden']);
  }
}
