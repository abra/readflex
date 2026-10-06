import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/library_bloc.dart';
import 'package:library_feature/src/library_header.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

void main() {
  for (final locale in [
    const Locale('en'),
    const Locale('ru'),
    const Locale('ar'),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('favourites badge fits content: $locale/$scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final semantics = tester.ensureSemantics();
        final controller = TextEditingController();
        final focus = FocusNode();
        addTearDown(controller.dispose);
        addTearDown(focus.dispose);
        var opened = 0;
        var cleared = 0;
        try {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light(),
              locale: locale,
              localizationsDelegates:
                  ReadflexLocalizations.localizationsDelegates,
              supportedLocales: ReadflexSupportedLocales.locales,
              home: Scaffold(
                body: LibraryHeader(
                  state: LibraryState(
                    selectedCollectionScope:
                        LibraryCollectionScope.favourites(),
                  ),
                  isOffline: false,
                  searchController: controller,
                  searchFocusNode: focus,
                  onSearchChanged: (_) {},
                  onFilterChanged: (_) {},
                  onCollectionScopePressed: () => opened++,
                  onCollectionScopeCleared: () => cleared++,
                ),
              ),
            ),
          );
          final context = tester.element(find.byType(LibraryHeader));
          final strings = ReadflexLocalizations.of(context)!;
          final label = find.text(
            locale.languageCode == 'en' ? 'Favs' : strings.libraryFavourites,
          );
          expect(label, findsOneWidget);
          final collection = find.bySemanticsLabel(
            strings.libraryCollectionsTitle,
          );
          expect(
            tester.getSemantics(collection).value,
            strings.libraryFavourites,
          );
          expect(tester.getSize(collection).width, greaterThanOrEqualTo(48));
          expect(tester.getSize(collection).height, 48);
          final clear = find.byTooltip(strings.libraryClearCollectionFilter);
          final clearBounds = tester.getRect(clear);
          final labelBounds = tester.getRect(label);
          expect(clearBounds.size, const Size(48, 48));
          final fill = tester.getRect(
            find.byKey(const ValueKey('library-collection-fill')),
          );
          expect(fill.overlaps(clearBounds), isTrue);
          expect(fill.height, AppSizes.chipHeight);
          final title = find.text(strings.libraryTitle);
          expect(tester.getSize(title).width, greaterThan(80));
          expect(
            locale.languageCode == 'ar'
                ? labelBounds.left - clearBounds.right
                : clearBounds.left - labelBounds.right,
            closeTo(AppSpacing.sm, .01),
          );
          await tester.tap(find.byTooltip(strings.libraryFavourites));
          expect(opened, 1);
          await tester.tap(clear);
          expect(cleared, 1);
          expect(opened, 1);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      });
    }
  }

  for (final theme in [AppTheme.light(), AppTheme.dark()]) {
    testWidgets('item count contrast: ${theme.brightness}', (tester) async {
      final controller = TextEditingController();
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: LibraryHeader(
              state: LibraryState(),
              isOffline: false,
              searchController: controller,
              searchFocusNode: focus,
              onSearchChanged: (_) {},
              onFilterChanged: (_) {},
              onCollectionScopePressed: () {},
              onCollectionScopeCleared: () {},
            ),
          ),
        ),
      );
      final counter = find.text('0');
      final badge = tester.widget<Container>(
        find.ancestor(of: counter, matching: find.byType(Container)).first,
      );
      final background = Color.alphaBlend(
        (badge.decoration! as BoxDecoration).color!,
        theme.scaffoldBackgroundColor,
      );
      final foreground = Color.alphaBlend(
        tester.widget<Text>(counter).style!.color!,
        background,
      );
      final a = foreground.computeLuminance();
      final b = background.computeLuminance();
      expect(
        a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05),
        greaterThanOrEqualTo(4.5),
      );
    });
  }

  testWidgets('collection and clear have separate labeled 48px targets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    try {
      final controller = TextEditingController();
      final focusNode = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);
      var opened = 0;
      var cleared = 0;

      Future<void> pumpHeader(LibraryCollectionScope? scope) =>
          tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light(),
              localizationsDelegates:
                  ReadflexLocalizations.localizationsDelegates,
              supportedLocales: ReadflexSupportedLocales.locales,
              home: Scaffold(
                body: LibraryHeader(
                  state: LibraryState(selectedCollectionScope: scope),
                  isOffline: false,
                  searchController: controller,
                  searchFocusNode: focusNode,
                  onSearchChanged: (_) {},
                  onFilterChanged: (_) {},
                  onCollectionScopePressed: () => opened++,
                  onCollectionScopeCleared: () => cleared++,
                ),
              ),
            ),
          );

      await pumpHeader(null);
      final collection = find.bySemanticsLabel('Collections');
      expect(tester.getSize(collection), const Size(48, 48));
      expect(
        tester.getSize(find.byKey(const ValueKey('library-collection-fill'))),
        const Size.square(AppSizes.chipHeight),
      );
      await tester.tapAt(tester.getTopLeft(collection) + const Offset(1, 1));
      expect(opened, 1);

      await pumpHeader(LibraryCollectionScope.favourites());
      final clear = find.byTooltip('Clear collection filter');
      expect(tester.getSize(clear), const Size(48, 48));
      await tester.tapAt(tester.getBottomRight(clear) - const Offset(1, 1));
      await tester.pumpAndSettle();
      expect(cleared, 1);
      expect(opened, 1, reason: 'Clear must not also open the collection menu');
      expect(tester.getSemantics(clear).tooltip, 'Clear collection filter');
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  Future<void> pumpHeader(
    WidgetTester tester, {
    LibraryCollectionScope? scope,
    ThemeData? theme,
  }) async {
    final controller = TextEditingController();
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.light(),
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        supportedLocales: ReadflexSupportedLocales.locales,
        home: Scaffold(
          body: LibraryHeader(
            state: LibraryState(selectedCollectionScope: scope),
            isOffline: false,
            searchController: controller,
            searchFocusNode: focus,
            onSearchChanged: (_) {},
            onFilterChanged: (_) {},
            onCollectionScopePressed: () {},
            onCollectionScopeCleared: () {},
          ),
        ),
      ),
    );
  }

  testWidgets('clear collection action is the shared plain icon button', (
    tester,
  ) async {
    await pumpHeader(tester, scope: LibraryCollectionScope.favourites());
    final strings = tester.element(find.byType(LibraryHeader)).l10n;
    final clear = find.byTooltip(strings.libraryClearCollectionFilter);
    final button = find.ancestor(
      of: clear,
      matching: find.byType(AppPlainIconButton),
    );
    expect(button, findsOneWidget);
    expect(tester.getSize(button), const Size(48, 48));
    final plain = tester.widget<AppPlainIconButton>(button);
    expect(plain.icon, AppIcons.close);
    expect(plain.iconSize, AppIconSize.xs);
    expect(plain.color, tester.element(button).colors.onPrimary);
    final style = tester
        .widget<IconButton>(
          find.descendant(of: button, matching: find.byType(IconButton)),
        )
        .style!;
    expect(style.shape!.resolve({}), const CircleBorder());
  });

  for (final theme in [AppTheme.light(), AppTheme.dark()]) {
    testWidgets('muted header glyphs use onSurfaceVariant: '
        '${theme.brightness}', (tester) async {
      await pumpHeader(tester, theme: theme);
      final colors = theme.colorScheme;
      expect(
        tester.widget<Icon>(find.byIcon(AppIcons.collection)).color,
        colors.onSurfaceVariant,
      );
      expect(
        tester
            .widget<AppPlainIconButton>(
              find.byKey(const ValueKey('libraryHeaderDisplayButton')),
            )
            .color,
        colors.onSurfaceVariant,
      );
    });
  }

  for (final locale in [const Locale('en'), const Locale('ar')]) {
    testWidgets('Display glyph ends on the 16dp gutter with the search field '
        '($locale)', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = TextEditingController();
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: locale,
          localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
          supportedLocales: ReadflexSupportedLocales.locales,
          home: Scaffold(
            body: LibraryHeader(
              state: LibraryState(),
              isOffline: true,
              searchController: controller,
              searchFocusNode: focus,
              onSearchChanged: (_) {},
              onFilterChanged: (_) {},
              onCollectionScopePressed: () {},
              onCollectionScopeCleared: () {},
            ),
          ),
        ),
      );
      final rtl = locale.languageCode == 'ar';
      final button = find.byKey(const ValueKey('libraryHeaderDisplayButton'));
      final target = tester.getRect(button);
      final glyph = tester.getRect(
        find.descendant(
          of: button,
          matching: find.byIcon(AppIcons.moreVertical),
        ),
      );
      final search = tester.getRect(find.byType(SearchField));
      final strings = tester.element(find.byType(LibraryHeader)).l10n;
      final title = tester.getRect(find.text(strings.libraryTitle));
      final badge = tester.getRect(find.text('0'));
      final offline = tester.getRect(find.byIcon(AppIcons.offline));

      expect(target.size, const Size.square(48));
      expect(search.left, AppSpacing.lg);
      expect(search.right, 390 - AppSpacing.lg);
      if (rtl) {
        expect(glyph.left, closeTo(AppSpacing.lg, .01));
        expect(
          target.left,
          closeTo(AppSpacing.lg - AppSizes.iconActionOutset, .01),
        );
        expect(title.right, closeTo(390 - AppSpacing.lg, .01));
        expect(offline.right, lessThan(title.left - AppSpacing.sm + .01));
      } else {
        expect(glyph.right, closeTo(390 - AppSpacing.lg, .01));
        expect(
          target.right,
          closeTo(390 - AppSpacing.lg + AppSizes.iconActionOutset, .01),
        );
        expect(title.left, closeTo(AppSpacing.lg, .01));
        expect(offline.left, greaterThan(title.right + AppSpacing.sm - .01));
      }
      // The count badge keeps its 8dp gap to the target.
      final badgeBox = tester.getRect(
        find
            .ancestor(of: find.text('0'), matching: find.byType(Container))
            .first,
      );
      expect(
        rtl ? badgeBox.left - target.right : target.left - badgeBox.right,
        closeTo(AppSpacing.sm, .01),
      );
      expect(badge.height, greaterThan(0));
      expect(tester.takeException(), isNull);
    });
  }

  for (final selected in [false, true]) {
    testWidgets('collection badge ink is bounded to the 32dp body inside a '
        '48dp target (selected=$selected)', (tester) async {
      await pumpHeader(
        tester,
        scope: selected ? LibraryCollectionScope.favourites() : null,
      );
      final strings = tester.element(find.byType(LibraryHeader)).l10n;
      final semantics = tester.ensureSemantics();
      try {
        final target = find.bySemanticsLabel(strings.libraryCollectionsTitle);
        expect(tester.getSize(target).height, AppSizes.chipTapTarget);
        expect(
          tester.getSize(target).width,
          greaterThanOrEqualTo(AppSizes.chipTapTarget),
        );
        final ink = find.descendant(of: target, matching: find.byType(InkWell));
        final inkRect = tester.getRect(ink);
        final fill = tester.getRect(
          find.byKey(const ValueKey('library-collection-fill')),
        );
        expect(inkRect.height, AppSizes.chipHeight);
        expect(inkRect.top, fill.top);
        expect(inkRect.bottom, fill.bottom);
        if (!selected) {
          expect(inkRect, fill);
        } else {
          expect(inkRect.left, fill.left);
          final label = tester.widget<Text>(find.text('Favs'));
          final labelSmall = Theme.of(
            tester.element(find.text('Favs')),
          ).textTheme.labelSmall!;
          expect(label.style!.fontSize, labelSmall.fontSize);
          expect(label.style!.fontWeight, FontWeight.w500);
        }
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      } finally {
        semantics.dispose();
      }
    });
  }
}
