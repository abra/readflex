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
}
