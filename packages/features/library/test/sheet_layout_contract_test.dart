import 'dart:math' as math;

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/library_bloc.dart';
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
    testWidgets('bulk actions share screen gutters and safe footer ($locale)', (
      tester,
    ) async {
      _viewport(tester);
      final cubit = LibrarySelectionCubit()..toggle('book');
      addTearDown(cubit.close);
      await tester.pumpWidget(
        _app(
          BlocProvider.value(
            value: cubit,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: LibrarySelectionBar(
                onAddToCollection: () {},
                onDelete: () {},
              ),
            ),
          ),
          locale: locale,
        ),
      );
      final close = tester.getRect(find.byIcon(AppIcons.close));
      final trash = tester.getRect(find.byIcon(AppIcons.delete));
      final rtl = locale == 'ar';
      expect(rtl ? 390 - close.right : close.left, AppSpacing.lg);
      expect(rtl ? trash.left : 390 - trash.right, AppSpacing.lg);
      final action = find.widgetWithIcon(AppPlainIconButton, AppIcons.delete);
      expect(tester.getSize(action), const Size(48, 48));
      expect(
        tester.widget<AppPlainIconButton>(action).color,
        tester.element(action).colors.error,
      );
      expect(
        find.descendant(
          of: find.byType(FilledButton),
          matching: find.byType(AppButtonLabel),
        ),
        findsOneWidget,
      );
      expect(
        844 - tester.getBottomLeft(find.byType(FilledButton)).dy,
        AppSpacing.lg * 2,
      );
      expect(
        844 - tester.getBottomLeft(action).dy,
        greaterThanOrEqualTo(AppSpacing.lg * 2),
        reason: 'Icons remain centered beside a taller localized command',
      );
      expect(tester.takeException(), isNull);
    });
  }
}

Widget _app(Widget child, {String locale = 'en'}) => MaterialApp(
  theme: AppTheme.light(),
  locale: Locale(locale),
  supportedLocales: ReadflexSupportedLocales.locales,
  localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
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
