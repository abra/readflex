import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/library_bloc.dart';
import 'package:library_feature/src/library_header.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

void main() {
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
