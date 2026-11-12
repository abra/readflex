import 'package:component_library/component_library.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/library_bloc.dart';
import 'package:library_feature/src/library_body.dart';
import 'package:library_feature/src/library_floating_actions.dart';
import 'package:library_feature/src/library_import_entry.dart';
import 'package:material_ui/material_ui.dart' show RefreshIndicator;
import 'package:readflex_localizations/readflex_localizations.dart';

import '../../../component_library/test_support/platform_test_app.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform search retains its editor while the keyboard opens',
      (
        tester,
      ) async {
        tester.view
          ..physicalSize = const Size(390, 844)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final active = ValueNotifier(false);
        final controller = TextEditingController();
        final focus = FocusNode();
        addTearDown(active.dispose);
        addTearDown(controller.dispose);
        addTearDown(focus.dispose);
        await tester.pumpWidget(
          PlatformTestApp(
            platform: platform,
            supportedLocales: ReadflexSupportedLocales.locales,
            localizationsDelegates: readflexLocalizationsDelegates,
            home: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Align(
                alignment: AlignmentDirectional.bottomEnd,
                child: ValueListenableBuilder<bool>(
                  valueListenable: active,
                  builder: (context, searching, _) => LibraryFloatingActions(
                    scope: null,
                    searchActive: searching,
                    searchController: controller,
                    searchFocusNode: focus,
                    onCollectionsPressed: () {},
                    onAddPressed: () {},
                    onSearchChanged: (_) {},
                    onSearchClosed: () {
                      focus.unfocus();
                      active.value = false;
                    },
                    onSearchPressed: () {
                      active.value = true;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        focus.requestFocus();
                      });
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('librarySearchButton')));
        await tester.pumpAndSettle();
        final editor = tester.element(find.byType(EditableText));
        final field = find.byKey(const ValueKey('librarySearchField'));
        await tester.enterText(field, 'A search that stays focused');
        tester.view.viewInsets = const FakeViewPadding(bottom: 320);
        await tester.pumpAndSettle();
        expect(focus.hasFocus, isTrue);
        expect(tester.testTextInput.hasAnyClients, isTrue);
        expect(tester.element(find.byType(EditableText)), same(editor));
        expect(controller.text, 'A search that stays focused');
        await tester.tap(
          find.byKey(const ValueKey('librarySearchCloseButton')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(EditableText), findsNothing);
        expect(focus.hasFocus, isFalse);
        expect(
          find.byKey(const ValueKey('librarySearchButton')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    for (final locale in [const Locale('de'), const Locale('ar')]) {
      testWidgets('$platform empty Library remains usable at 200% $locale', (
        tester,
      ) async {
        tester.view
          ..physicalSize = const Size(320, 568)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        final entries = <LibraryImportEntry>[];
        await tester.pumpWidget(
          PlatformTestApp(
            platform: platform,
            locale: locale,
            supportedLocales: ReadflexSupportedLocales.locales,
            localizationsDelegates: readflexLocalizationsDelegates,
            textScale: 2,
            home: LibraryBody(
              state: LibraryState(),
              scrollController: scroll,
              onSourcePressed: (_) {},
              onSourceLongPressed: (_) {},
              onConfirmSwipeDelete: (_) async => false,
              onImportPressed: entries.add,
              onRefresh: () async {},
              onClearSearch: () {},
              onShowWholeLibrary: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(CupertinoSliverRefreshControl, skipOffstage: false),
          platform == TargetPlatform.iOS ? findsOneWidget : findsNothing,
        );
        expect(
          find.byType(RefreshIndicator),
          platform == TargetPlatform.android ? findsOneWidget : findsNothing,
        );
        for (final (key, entry) in [
          ('libraryEmptyUploadFile', LibraryImportEntry.file),
          ('libraryEmptySaveArticle', LibraryImportEntry.article),
        ]) {
          final button = find.byKey(ValueKey(key));
          await tester.ensureVisible(button);
          await tester.pumpAndSettle();
          expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
          await tester.tap(button);
          expect(entries.last, entry);
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('$platform uses the native pull-to-refresh interaction', (
      tester,
    ) async {
      var refreshes = 0;
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        PlatformTestApp(
          platform: platform,
          supportedLocales: ReadflexSupportedLocales.locales,
          localizationsDelegates: readflexLocalizationsDelegates,
          home: LibraryBody(
            state: LibraryState(),
            scrollController: scroll,
            onSourcePressed: (_) {},
            onSourceLongPressed: (_) {},
            onConfirmSwipeDelete: (_) async => false,
            onImportPressed: null,
            onRefresh: () async => refreshes++,
            onClearSearch: () {},
            onShowWholeLibrary: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final upload = tester.widget<AppButton>(
        find.byKey(const ValueKey('libraryEmptyUploadFile')),
      );
      expect(upload.onPressed, isNull);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 350));
      await tester.pumpAndSettle();
      expect(refreshes, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
