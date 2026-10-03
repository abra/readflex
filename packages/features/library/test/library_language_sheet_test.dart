import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/library_language_sheet.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

void main() {
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.single;
    view.physicalSize = const Size(600, 1000);
    view.devicePixelRatio = 1;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  });

  Widget subject({
    Locale selected = const Locale('en'),
    required ValueChanged<Locale> onSelected,
  }) => MaterialApp(
    theme: AppTheme.light(),
    locale: const Locale('en'),
    supportedLocales: ReadflexSupportedLocales.locales,
    localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
    home: Scaffold(
      body: Align(
        alignment: Alignment.bottomCenter,
        child: LibraryLanguageSheet(
          selectedLocale: selected,
          onSelected: onSelected,
          onClose: () {},
        ),
      ),
    ),
  );

  testWidgets(
    'every language has selectable semantics and the right callback',
    (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        Locale? result;
        await tester.pumpWidget(subject(onSelected: (value) => result = value));
        await tester.pumpAndSettle();
        for (final language in ReadflexSupportedLocales.languages) {
          final option = find.byKey(
            ValueKey('libraryLanguageOption-${language.code}'),
          );
          expect(
            tester.getSemantics(option),
            isSemantics(
              label: language.name,
              isButton: true,
              hasSelectedState: true,
              isSelected: language.code == 'en',
              isInMutuallyExclusiveGroup: true,
              hasTapAction: true,
            ),
          );
          await tester.tap(option);
          expect(result, Locale(language.code));
        }
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('checkmark does not change option geometry', (tester) async {
    await tester.pumpWidget(subject(onSelected: (_) {}));
    await tester.pumpAndSettle();
    List<Rect> geometry() => [
      for (final language in ReadflexSupportedLocales.languages)
        tester.getRect(
          find.byKey(ValueKey('libraryLanguageOption-${language.code}')),
        ),
    ];
    final before = geometry();
    await tester.pumpWidget(
      subject(selected: const Locale('ru'), onSelected: (_) {}),
    );
    await tester.pumpAndSettle();
    expect(geometry(), before);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('libraryLanguageOption-ru')),
        matching: find.byIcon(AppIcons.check),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('resizing switches columns without losing languages', (
    tester,
  ) async {
    await tester.pumpWidget(subject(onSelected: (_) {}));
    await tester.pumpAndSettle();
    final first = find.byKey(const ValueKey('libraryLanguageOption-en'));
    final second = find.byKey(const ValueKey('libraryLanguageOption-zh'));
    expect(tester.getTopLeft(first).dy, tester.getTopLeft(second).dy);
    tester.view.physicalSize = const Size(320, 568);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(second).dy,
      greaterThan(tester.getBottomLeft(first).dy),
    );
    for (final language in ReadflexSupportedLocales.languages) {
      final option = find.byKey(
        ValueKey('libraryLanguageOption-${language.code}'),
      );
      await tester.ensureVisible(option);
      await tester.pumpAndSettle();
      expect(option.hitTestable(), findsOneWidget);
      expect(
        tester.getSize(option).height,
        greaterThanOrEqualTo(AppSizes.buttonHeight),
      );
    }
    expect(tester.takeException(), isNull);
  });
}
