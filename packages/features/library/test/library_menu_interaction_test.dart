import 'package:component_library/component_library.dart';
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoPopupSurface;
import 'package:domain_models/domain_models.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/library_bloc.dart';
import 'package:library_feature/src/library_display_sheet.dart';
import 'package:library_feature/src/library_layout_cubit.dart';
import 'package:library_feature/src/library_locale_cubit.dart';
import 'package:library_feature/src/library_page_animation_cubit.dart';
import 'package:library_feature/src/library_theme_cubit.dart';
import 'package:library_feature/src/manage_collection_cubit.dart';
import 'package:library_feature/src/manage_collection_sheet.dart';
import 'package:library_feature/src/select_collection_scope_sheet.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../../component_library/test_support/platform_test_app.dart';
import 'helpers/fake_collection_repository.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final selected in [false, true]) {
      testWidgets('$platform opens and selects collection scopes '
          'with an existing selected row ($selected)', (tester) async {
        final scope = LibraryCollectionScope.favourites(sourceIds: ['book']);
        LibraryCollectionScopeSheetResult? result;
        await tester.pumpWidget(
          PlatformTestApp(
            platform: platform,
            supportedLocales: ReadflexSupportedLocales.locales,
            localizationsDelegates: readflexLocalizationsDelegates,
            home: Builder(
              builder: (context) => Center(
                child: AppButton(
                  onPressed: () async {
                    result = await showLibraryCollectionScopeSheet(
                      context: context,
                      state: LibraryState(
                        collectionScopes: [scope],
                        selectedCollectionScope: selected ? scope : null,
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.byType(CupertinoPopupSurface),
          platform == TargetPlatform.iOS ? findsOneWidget : findsNothing,
        );
        final pill = find.byKey(
          ValueKey(
            selected
                ? 'collectionScopeSelection-favourites-readflex:favourites'
                : 'collectionScopeSelection-library',
          ),
        );
        expect(pill, findsOneWidget);
        final option = find.byKey(
          ValueKey(
            selected
                ? 'collectionScopeRow-library'
                : 'collectionScopeRow-favourites-readflex:favourites',
          ),
        );
        await tester.tap(option);
        await tester.pumpAndSettle();
        expect(
          result,
          selected
              ? isA<LibraryCollectionScopeCleared>()
              : isA<LibraryCollectionScopeSelected>(),
        );
        expect(find.byType(CupertinoPopupSurface), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('$platform Display language steps preserve the modal', (
      tester,
    ) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final preferences = await PreferencesService.create(
        supportedCodes: ReadflexSupportedLocales.codes,
      );
      final layout = LibraryLayoutCubit(preferencesService: preferences);
      final locale = LibraryLocaleCubit(preferencesService: preferences);
      final theme = LibraryThemeCubit(preferencesService: preferences);
      final animation = LibraryPageAnimationCubit(
        preferencesService: preferences,
      );
      addTearDown(preferences.dispose);
      addTearDown(layout.close);
      addTearDown(locale.close);
      addTearDown(theme.close);
      addTearDown(animation.close);
      await tester.pumpWidget(
        _LibraryMenuHost(
          platform: platform,
          onOpen: (context) => showLibraryDisplaySheet(
            context: context,
            layoutCubit: layout,
            localeCubit: locale,
            themeCubit: theme,
            pageAnimationCubit: animation,
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final language = find.byKey(const ValueKey('libraryLanguagePicker'));
      await tester.ensureVisible(language);
      await tester.tap(language);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('libraryLanguageOption-ru')),
      );
      await tester.pumpAndSettle();
      expect(locale.state, const Locale('ru'));
      expect(preferences.current.locale, const Locale('ru'));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(language.hitTestable(), findsOneWidget);
      await tester.tap(find.byTooltip('Close').hitTestable());
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoPopupSurface), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$platform nested collection management protects and saves '
        'its draft without popping the scope picker', (tester) async {
      final collection = LibraryCollection(
        id: 'reading',
        name: 'Reading',
        sourceCount: 1,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final scope = LibraryCollectionScope.manual(
        collection: collection,
        sourceIds: const {'book'},
      );
      final source = LibrarySource.fromBook(
        Book(
          id: 'book',
          title: 'A saved book',
          filePath: 'book.epub',
          format: BookFormat.epub,
          addedAt: DateTime(2026),
        ),
      );
      final repository = FakeCollectionRepository()
        ..seedCollections([collection])
        ..seedCollectionSourceIds({
          'reading': {'book'},
        });
      final cubit = ManageCollectionCubit(collectionRepository: repository);
      addTearDown(cubit.close);
      var changed = 0;
      await tester.pumpWidget(
        _LibraryMenuHost(
          platform: platform,
          onOpen: (context) async {
            await showLibraryCollectionScopeSheet(
              context: context,
              state: LibraryState(collectionScopes: [scope]),
              manageBuilder: (context, scope, onBack, onClose) =>
                  BlocProvider.value(
                    value: cubit,
                    child: ManageCollectionSheet(
                      scope: scope,
                      sources: [source],
                      onCollectionChanged: () => changed++,
                      onFinished: (_) => onBack(),
                      onCloseFlow: onClose,
                    ),
                  ),
            );
          },
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final manage = find.byKey(
        const ValueKey('collectionScopeManage-manual-reading'),
      );
      await tester.tap(manage);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('collectionSourceRemove-book')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close').hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('Keep editing'), findsOneWidget);
      expect(repository.addedSourceIdsByCollection['reading'], {'book'});
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('collectionSourceUndo-book')),
        findsOneWidget,
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(changed, 1);
      expect(repository.addedSourceIdsByCollection['reading'], isEmpty);
      expect(manage.hitTestable(), findsOneWidget);
      await tester.tap(find.byTooltip('Close').hitTestable());
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoPopupSurface), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}

class _LibraryMenuHost extends StatelessWidget {
  const _LibraryMenuHost({required this.platform, required this.onOpen});

  final TargetPlatform platform;
  final Future<void> Function(BuildContext) onOpen;

  @override
  Widget build(BuildContext context) => PlatformTestApp(
    platform: platform,
    supportedLocales: ReadflexSupportedLocales.locales,
    localizationsDelegates: readflexLocalizationsDelegates,
    home: Builder(
      builder: (context) => Center(
        child: AppButton(
          onPressed: () => onOpen(context),
          child: const Text('Open'),
        ),
      ),
    ),
  );
}
