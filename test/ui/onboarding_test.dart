import 'dart:math' as math;

import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex/app/screens/onboarding_highlight_range.dart';
import 'package:readflex/app/screens/onboarding_page_preview.dart';
import 'package:readflex/app/screens/onboarding_screen.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'golden_support.dart';

void main() {
  setUpAll(loadUiFonts);

  ReadflexLocalizations l10nOf(WidgetTester tester) =>
      ReadflexLocalizations.of(tester.element(find.byType(OnboardingScreen)))!;

  Future<void> pumpOnboarding(
    WidgetTester tester, {
    VisualProfile profile = VisualProfile.phone,
    Size? size,
    Locale? locale,
    VoidCallback? onAddBook,
    VoidCallback? onNotNow,
  }) => pumpGoldenSurface(
    tester,
    profile,
    (_) => OnboardingScreen(
      onAddBook: onAddBook ?? () {},
      onNotNow: onNotNow ?? () {},
    ),
    surfaceSize: size,
    locale: locale,
  );

  Finder addBook(ReadflexLocalizations l10n) =>
      find.widgetWithText(FilledButton, l10n.onboardingAddBook);

  Finder notNow(ReadflexLocalizations l10n) =>
      find.widgetWithText(TextButton, l10n.onboardingNotNow);

  final preview = find.byType(OnboardingPagePreview);

  /// The span the preview paints with a highlight background.
  TextSpan highlightedSpan(WidgetTester tester) {
    TextSpan? highlighted;
    for (final paragraph in tester.widgetList<RichText>(
      find.descendant(of: preview, matching: find.byType(RichText)),
    )) {
      paragraph.text.visitChildren((span) {
        if (span is TextSpan && span.style?.backgroundColor != null) {
          highlighted = span;
          return false;
        }
        return true;
      });
    }
    return highlighted ?? (throw StateError('no highlighted span'));
  }

  double tiltOf(WidgetTester tester) {
    final transform = tester
        .widget<Transform>(
          find.descendant(of: preview, matching: find.byType(Transform)).first,
        )
        .transform;
    return math.atan2(transform.entry(1, 0), transform.entry(0, 0));
  }

  testWidgets('one screen replaces the carousel, its dots and Skip', (
    tester,
  ) async {
    await pumpOnboarding(tester);
    final l10n = l10nOf(tester);

    expect(find.byType(PageView), findsNothing);
    expect(find.byType(AnimatedContainer), findsNothing);
    expect(find.byType(TextButton), findsOneWidget, reason: 'only Not now');

    expect(preview, findsOneWidget);
    expect(find.text(l10n.onboardingReadAnythingTitle), findsOneWidget);
    expect(find.text(l10n.onboardingReadAnythingDescription), findsOneWidget);
    expect(addBook(l10n), findsOneWidget);
    expect(notNow(l10n), findsOneWidget);
    expect(
      find.descendant(of: addBook(l10n), matching: find.byIcon(AppIcons.add)),
      findsOneWidget,
    );
    // Preview and body never repeat the same copy.
    for (final copy in [
      l10n.onboardingReadAnythingDescription,
      l10n.onboardingHighlightSaveDescription,
      l10n.onboardingOrganizeLibraryDescription,
    ]) {
      expect(
        find.byWidgetPredicate(
          (widget) => widget is RichText && widget.text.toPlainText() == copy,
        ),
        findsOneWidget,
        reason: copy,
      );
    }
    expect(
      find.descendant(
        of: preview,
        matching: find.text(l10n.onboardingReadAnythingDescription),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Add a book and Not now each call only their own callback', (
    tester,
  ) async {
    var added = 0;
    var dismissed = 0;
    await pumpOnboarding(
      tester,
      onAddBook: () => added++,
      onNotNow: () => dismissed++,
    );
    final l10n = l10nOf(tester);

    await tester.tap(addBook(l10n));
    await tester.pumpAndSettle();
    expect(added, 1);
    expect(dismissed, 0);

    await tester.tap(notNow(l10n));
    await tester.pumpAndSettle();
    expect(added, 1);
    expect(dismissed, 1);
  });

  testWidgets('actions are labeled 48dp buttons with button semantics', (
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
        tester.getSemantics(find.text(l10n.onboardingReadAnythingTitle)),
        matchesSemantics(
          label: l10n.onboardingReadAnythingTitle,
          isHeader: true,
        ),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('preview is a tilted default reader page with a highlight', (
    tester,
  ) async {
    await pumpOnboarding(tester);
    final l10n = l10nOf(tester);
    final page = ReaderThemePreset.paper.data;

    final card = tester.widget<DecoratedBox>(
      find.descendant(of: preview, matching: find.byType(DecoratedBox)).first,
    );
    final decoration = card.decoration as BoxDecoration;
    expect(decoration.color, page.backgroundColor);
    expect(decoration.borderRadius, BorderRadius.circular(AppRadius.lg));
    expect(decoration.boxShadow, AppShadows.popover);
    expect(tiltOf(tester), closeTo(-2 * math.pi / 180, 1e-9));

    // Small uppercase muted chapter label, announced as written.
    final label = l10n.onboardingHighlightSaveTitle;
    final chapter = tester.widget<Text>(find.text(label.toUpperCase()));
    expect(chapter.semanticsLabel, label);
    expect(chapter.style!.color, page.secondaryTextColor);
    expect(chapter.style!.fontFamily, AppTypography.fontFamilySerif);

    // Two serif paragraphs in the page's ink.
    final paragraphs = tester
        .widgetList<RichText>(
          find.descendant(of: preview, matching: find.byType(RichText)),
        )
        .where((t) => t.text.toPlainText() != label.toUpperCase())
        .toList();
    expect(paragraphs.map((t) => t.text.toPlainText()), [
      l10n.onboardingHighlightSaveDescription,
      l10n.onboardingOrganizeLibraryDescription,
    ]);
    for (final paragraph in paragraphs) {
      expect(paragraph.text.style!.fontFamily, AppTypography.fontFamilySerif);
      expect(paragraph.text.style!.color, page.primaryTextColor);
      expect(
        chapter.style!.fontSize,
        lessThan(paragraph.text.style!.fontSize!),
      );
    }

    final highlighted = highlightedSpan(tester);
    expect(highlighted.style!.backgroundColor, page.highlightYellow);
    expect(highlighted.text, 'Select text to create highlights.');
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview keeps the paper page in dark mode', (tester) async {
    await pumpOnboarding(tester, profile: VisualProfile.dark);
    final page = ReaderThemePreset.paper.data;
    final decoration =
        tester
                .widget<DecoratedBox>(
                  find
                      .descendant(
                        of: preview,
                        matching: find.byType(DecoratedBox),
                      )
                      .first,
                )
                .decoration
            as BoxDecoration;
    expect(decoration.color, page.backgroundColor);
    expect(
      highlightedSpan(tester).style!.backgroundColor,
      page.highlightYellow,
    );
  });

  for (final locale in ReadflexSupportedLocales.locales) {
    testWidgets('preview highlights a phrase of the localized copy: $locale', (
      tester,
    ) async {
      await pumpOnboarding(tester, locale: locale);
      final l10n = l10nOf(tester);
      final description = l10n.onboardingHighlightSaveDescription;
      final range = onboardingHighlightRange(description);
      final highlighted = highlightedSpan(tester).text!;

      expect(highlighted, range.textInside(description));
      expect(highlighted.trim(), isNotEmpty);
      expect(description.startsWith(highlighted), isTrue);
      expect(
        highlighted.length,
        lessThan(description.trim().length),
        reason: 'a phrase, not the whole paragraph',
      );
      expect(tester.takeException(), isNull);
    });
  }

  group('onboardingHighlightRange', () {
    String phrase(String text) =>
        onboardingHighlightRange(text).textInside(text);

    test('takes the first sentence when more text follows', () {
      expect(
        phrase(
          'Select text to create highlights. Add notes for deeper '
          'understanding.',
        ),
        'Select text to create highlights.',
      );
      expect(phrase('选择文字创建高亮。添加笔记以加深理解。'), '选择文字创建高亮。');
      expect(
        phrase(
          'हाइलाइट बनाने के लिए टेक्स्ट चुनें। बेहतर समझ के लिए नोट जोड़ें।',
        ),
        'हाइलाइट बनाने के लिए टेक्स्ट चुनें।',
      );
      expect(phrase('Version 3.5 is out. Read it.'), 'Version 3.5 is out.');
    });

    test('falls back to the first clause of a single sentence', () {
      expect(
        phrase('テキストを選択してハイライトを作成し、理解を深めるためにメモを追加できます。'),
        'テキストを選択してハイライトを作成し',
      );
      expect(phrase('Read slowly, then return.'), 'Read slowly');
    });

    test('falls back to the first half of the words', () {
      expect(
        phrase('Сохраняйте выделенные фрагменты текста и добавляйте заметки.'),
        'Сохраняйте выделенные фрагменты текста',
      );
      expect(phrase('Two words'), 'Two');
    });

    test('keeps short or empty text whole and trims outer whitespace', () {
      expect(phrase('Word'), 'Word');
      expect(phrase('Word.'), 'Word.');
      expect(phrase(''), '');
      expect(phrase('   '), '');
      expect(phrase('  Hello there. More  '), 'Hello there.');
      expect(onboardingHighlightRange('  Hello there. More').start, 2);
    });

    test('never splits a surrogate pair', () {
      for (final text in [
        '😀😀 tail words here',
        '😀.😀',
        'Hi 😀. Next',
        '😀、😀😀',
      ]) {
        final range = onboardingHighlightRange(text);
        for (final offset in [range.start, range.end]) {
          if (offset == 0 || offset == text.length) continue;
          final before = text.codeUnitAt(offset - 1);
          expect(
            before >= 0xD800 && before <= 0xDBFF,
            isFalse,
            reason: '$text at $offset',
          );
        }
        expect(
          range.textBefore(text) +
              range.textInside(text) +
              range.textAfter(text),
          text,
        );
      }
    });
  });

  testWidgets('content and actions share the 16dp screen gutter', (
    tester,
  ) async {
    await pumpOnboarding(tester, size: const Size(390, 844));
    final l10n = l10nOf(tester);
    for (final target in [
      addBook(l10n),
      notNow(l10n),
      find.text(l10n.onboardingReadAnythingTitle),
      find.text(l10n.onboardingReadAnythingDescription),
    ]) {
      final rect = tester.getRect(target);
      expect(rect.left, AppSpacing.lg, reason: '$target');
      expect(rect.right, 390 - AppSpacing.lg, reason: '$target');
    }
    // The Transform's own box is the card's untilted layout slot; the
    // painted card is its rotation about the centre.
    final slot = find
        .descendant(of: preview, matching: find.byType(Transform))
        .first;
    final card = tester.getRect(slot);
    final painted = tester.getRect(
      find.descendant(of: preview, matching: find.byType(DecoratedBox)).first,
    );
    expect(card.width, OnboardingPagePreview.maxWidth);
    expect(card.center.dx, closeTo(195, 0.01));
    expect(painted.center.dx, closeTo(card.center.dx, 0.01));
    expect(painted.center.dy, closeTo(card.center.dy, 0.01));
    // The tilted corners stay within the 16dp gutter and below the safe top.
    expect(painted.left, greaterThan(0));
    expect(painted.right, lessThan(390));
    expect(painted.top, greaterThan(0));
    final title = tester.getRect(find.text(l10n.onboardingReadAnythingTitle));
    expect(title.top, greaterThan(painted.bottom));
    expect(
      tester.getRect(addBook(l10n)).bottom,
      lessThan(tester.getRect(notNow(l10n)).top),
    );
    // Narrow phones fill the content width on the gutter.
    await pumpOnboarding(tester, size: const Size(320, 568));
    final narrow = tester.getRect(slot);
    final narrowPainted = tester.getRect(
      find.descendant(of: preview, matching: find.byType(DecoratedBox)).first,
    );
    expect(narrow.left, AppSpacing.lg);
    expect(narrow.right, 320 - AppSpacing.lg);
    expect(narrowPainted.left, greaterThan(0));
    expect(narrowPainted.right, lessThan(320));
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
    final scroll = tester.getRect(find.byType(Scrollable));
    expect(scroll.top, 47);
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
      await tester.drag(scrollable, const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(position.pixels, closeTo(position.maxScrollExtent, 0.1));
      final description = tester.getRect(
        find.text(l10n.onboardingReadAnythingDescription),
      );
      expect(
        description.bottom,
        lessThanOrEqualTo(tester.getRect(scrollable).bottom),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('phone RTL mirrors the tilt and the leading button icon', (
    tester,
  ) async {
    await pumpOnboarding(
      tester,
      size: const Size(390, 844),
      locale: const Locale('ar'),
    );
    final l10n = l10nOf(tester);
    expect(
      Directionality.of(tester.element(preview)),
      TextDirection.rtl,
    );
    expect(tiltOf(tester), closeTo(2 * math.pi / 180, 1e-9));
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
    for (final action in [addBook(l10n), notNow(l10n)]) {
      final rect = tester.getRect(action);
      expect(rect.left, AppSpacing.lg);
      expect(rect.right, 390 - AppSpacing.lg);
    }
    expect(highlightedSpan(tester).text, isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the screen runs no animation, with or without reduced motion', (
    tester,
  ) async {
    // pumpGoldenSurface reduces motion; this host keeps platform motion on.
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        supportedLocales: ReadflexSupportedLocales.locales,
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        home: OnboardingScreen(onAddBook: () {}, onNotNow: () {}),
      ),
    );
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    final tilt = tiltOf(tester);

    await pumpOnboarding(tester);
    expect(tester.hasRunningAnimations, isFalse);
    expect(tiltOf(tester), tilt, reason: 'the tilt is static decoration');
  });

  for (final profile in VisualProfile.values) {
    testWidgets('onboarding ${profile.name}', (tester) async {
      await pumpOnboarding(tester, profile: profile);
      await expectUiGolden(tester, profile, 'onboarding');
      if (profile == VisualProfile.largeText) {
        final scrollable = find.byType(Scrollable);
        final position = tester.state<ScrollableState>(scrollable).position;
        expect(position.maxScrollExtent, greaterThan(0));
        await tester.drag(scrollable, const Offset(0, -2000));
        await tester.pumpAndSettle();
        expect(position.pixels, closeTo(position.maxScrollExtent, 0.1));
        await expectUiGolden(tester, profile, 'onboarding-scrolled');
      }
    }, tags: ['golden']);
  }
}
