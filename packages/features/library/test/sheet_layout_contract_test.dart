import 'dart:math' as math;

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/library_bloc.dart';
import 'package:library_feature/src/library_floating_actions_location.dart';
import 'package:library_feature/src/library_layout.dart';
import 'package:library_feature/src/library_selection_bar.dart';
import 'package:library_feature/src/library_selection_cubit.dart';
import 'package:library_feature/src/manage_collection_cubit.dart';
import 'package:library_feature/src/manage_collection_sheet.dart';
import 'package:library_feature/src/select_collection_scope_sheet.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'helpers/fake_collection_repository.dart';

void main() {
  for (final bottom in [0.0, 24.0, 34.0]) {
    for (final keyboard in [0.0, 280.0]) {
      for (final nested in [false, true]) {
        testWidgets(
          'manage footer bottom=$bottom keyboard=$keyboard nested=$nested',
          (tester) async {
            _viewport(tester, bottom: bottom, keyboard: keyboard);
            final repository = FakeCollectionRepository();
            final cubit = ManageCollectionCubit(
              collectionRepository: repository,
            );
            addTearDown(cubit.close);
            final collection = LibraryCollection(
              id: 'reading',
              name: 'Reading',
              sourceCount: 0,
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
            );
            final scope = LibraryCollectionScope.manual(
              collection: collection,
              sourceIds: const {},
            );
            await tester.pumpWidget(
              _app(
                Builder(
                  builder: (context) => TextButton(
                    onPressed: () {
                      if (nested) {
                        showLibraryCollectionScopeSheet(
                          context: context,
                          state: LibraryState(collectionScopes: [scope]),
                          manageBuilder: (_, scope, back, close) =>
                              BlocProvider.value(
                                value: cubit,
                                child: ManageCollectionSheet(
                                  scope: scope,
                                  sources: const [],
                                  onCollectionChanged: () {},
                                  onFinished: (_) => back(),
                                  onCloseFlow: close,
                                ),
                              ),
                        );
                      } else {
                        showManageCollectionSheet(
                          context: context,
                          cubit: cubit,
                          scope: scope,
                          sources: const [],
                          onCollectionChanged: () {},
                        );
                      }
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            );
            await tester.tap(find.text('Open'));
            await tester.pumpAndSettle();
            if (nested) {
              await tester.tap(
                find.byKey(
                  const ValueKey('collectionScopeManage-manual-reading'),
                ),
              );
              await tester.pumpAndSettle();
            }
            final save = tester.getRect(
              find.widgetWithText(FilledButton, 'Save'),
            );
            final expected =
                AppSpacing.lg +
                math.max(AppSpacing.lg, keyboard > 0 ? 0 : bottom);
            expect(844 - keyboard - save.bottom, closeTo(expected, .1));
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  for (final locale in ['en', 'ar']) {
    for (final bottom in [0.0, 24.0, 34.0]) {
      for (final keyboard in [0.0, 280.0]) {
        testWidgets(
          'floating bulk actions keep gutters and safe anchor '
          '($locale, bottom=$bottom, keyboard=$keyboard)',
          (tester) async {
            _viewport(tester, bottom: bottom, keyboard: keyboard);
            final cubit = LibrarySelectionCubit()..toggle('book');
            addTearDown(cubit.close);
            await tester.pumpWidget(
              MaterialApp(
                theme: AppTheme.light(),
                locale: Locale(locale),
                supportedLocales: ReadflexSupportedLocales.locales,
                localizationsDelegates: readflexLocalizationsDelegates,
                home: BlocProvider.value(
                  value: cubit,
                  child: AppScaffold(
                    floatingActionButtonLocation:
                        LibraryFloatingActionsLocation(
                          bottomViewPadding: bottom,
                        ),
                    floatingActionButton: Padding(
                      padding: const EdgeInsets.only(
                        bottom: kLibraryFloatingActionsLift,
                      ),
                      child: LibrarySelectionBar(
                        onAddToCollection: () {},
                        onDelete: () {},
                      ),
                    ),
                  ),
                ),
              ),
            );
            final cancel = find.byKey(
              const ValueKey('libraryCancelSelectionFab'),
            );
            final close = tester.getRect(cancel);
            final capsule = tester.getRect(
              find.byKey(const ValueKey('librarySelectionCapsule')),
            );
            final rtl = locale == 'ar';
            expect(
              rtl ? 390 - close.right : close.left,
              closeTo(AppSpacing.lg, .1),
            );
            expect(
              rtl ? capsule.left : 390 - capsule.right,
              closeTo(AppSpacing.lg, .1),
            );
            expect(
              rtl ? close.left - capsule.right : capsule.left - close.right,
              greaterThanOrEqualTo(AppSpacing.md),
            );
            expect(close.bottom, closeTo(capsule.bottom, .1));
            final expectedBottom =
                844 -
                math.max(bottom, keyboard) -
                AppSpacing.lg -
                kLibraryFloatingActionsLift;
            expect(close.bottom, closeTo(expectedBottom, .1));
            final action = find.byKey(
              const ValueKey('libraryDeleteSelectedButton'),
            );
            expect(tester.getSize(action), const Size(48, 48));
            final button = tester.widget<AppIconButton>(action);
            final colors = tester.element(action).colors;
            expect(
              button.backgroundColor,
              colors.error,
            );
            expect(button.foregroundColor, colors.onError);
            expect(button.shape, isA<CircleBorder>());
            final add = find.byKey(
              const ValueKey('libraryAddToCollectionButton'),
            );
            expect(tester.getSize(add).width, greaterThanOrEqualTo(48));
            expect(tester.getSize(add).height, greaterThanOrEqualTo(48));
            for (final control in [cancel, add, action]) {
              expect(control.hitTestable(), findsOneWidget);
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}

Widget _app(Widget child, {String locale = 'en'}) => MaterialApp(
  theme: AppTheme.light(),
  locale: Locale(locale),
  supportedLocales: ReadflexSupportedLocales.locales,
  localizationsDelegates: readflexLocalizationsDelegates,
  home: Scaffold(body: child),
);

void _viewport(WidgetTester tester, {double bottom = 0, double keyboard = 0}) {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1
    ..viewPadding = FakeViewPadding(bottom: bottom)
    ..padding = FakeViewPadding(bottom: keyboard > 0 ? 0 : bottom)
    ..viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.reset);
}
