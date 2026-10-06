import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/library_bloc.dart';
import 'package:library_feature/src/library_body.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

void main() {
  final book = LibrarySource.fromBook(
    Book(
      id: 'b-1',
      title: 'First',
      filePath: '/b1.epub',
      format: BookFormat.epub,
      addedAt: DateTime(2026),
    ),
  );

  Future<ReadflexLocalizations> pumpBody(
    WidgetTester tester,
    LibraryState state,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        supportedLocales: ReadflexSupportedLocales.locales,
        home: Scaffold(
          body: LibraryBody(
            state: state,
            scrollController: controller,
            onSourcePressed: (_) {},
            onSourceLongPressed: (_) {},
            onConfirmSwipeDelete: (_) async => false,
            onRefresh: () async {},
            onResetFilters: () {},
          ),
        ),
      ),
    );
    return tester.element(find.byType(LibraryBody)).l10n;
  }

  testWidgets('empty library state applies the 16dp gutter once', (
    tester,
  ) async {
    final strings = await pumpBody(tester, LibraryState());
    expect(find.byType(EmptyState), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byType(EmptyState),
        matching: find.byType(Padding),
      ),
      findsNothing,
    );
    // Large text wraps the subtitle so it spans the padded width.
    final subtitle = tester.getRect(find.text(strings.libraryEmptySubtitle));
    expect(subtitle.left, AppSpacing.lg);
    expect(subtitle.right, 320 - AppSpacing.lg);
    expect(
      tester.getSize(find.byType(ConstrainedBox).first).height,
      greaterThanOrEqualTo(568 * 0.6),
    );
  });

  testWidgets('filtered-out state applies the 16dp gutter once', (
    tester,
  ) async {
    final strings = await pumpBody(
      tester,
      LibraryState(sources: [book], searchQuery: 'nothing matches'),
    );
    expect(find.byType(EmptyState), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byType(EmptyState),
        matching: find.byType(Padding),
      ),
      findsNothing,
    );
    final subtitle = tester.getRect(
      find.text(strings.libraryNoResultsSubtitle),
    );
    expect(subtitle.left, AppSpacing.lg);
    expect(subtitle.right, 320 - AppSpacing.lg);
    expect(
      find.widgetWithText(TextButton, strings.libraryResetFilters),
      findsOneWidget,
    );
  });
}
