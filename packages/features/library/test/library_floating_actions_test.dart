import 'dart:io';

import 'package:component_library/component_library.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/library_bloc.dart';
import 'package:library_feature/src/library_floating_actions.dart';
import 'package:library_feature/src/library_floating_actions_location.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

final _capsule = find.byKey(const ValueKey('libraryFloatingActions'));
final _collections = find.byKey(const ValueKey('libraryCollectionsButton'));
final _search = find.byKey(const ValueKey('librarySearchButton'));
final _add = find.byKey(const ValueKey('libraryAddButton'));
final _field = find.byKey(const ValueKey('librarySearchField'));
final _close = find.byKey(const ValueKey('librarySearchCloseButton'));
final _clear = find.byKey(const ValueKey('librarySearchClearButton'));

double _layerOpacity(WidgetTester tester, String key) {
  final layer = find.byKey(ValueKey(key));
  if (layer.evaluate().isEmpty) return 0;
  return tester
      .widget<FadeTransition>(
        find.descendant(of: layer, matching: find.byType(FadeTransition)).first,
      )
      .opacity
      .value;
}

class _Harness {
  final active = ValueNotifier(false);
  final reducedMotion = ValueNotifier(false);
  final controller = TextEditingController();
  final focus = FocusNode();
  var additions = 0;
  var collections = 0;
  var closed = 0;
  var query = '';
  var horizontalViewPadding = 0.0;

  void open() => active.value = true;
  void close() {
    closed++;
    controller.clear();
    focus.unfocus();
    query = '';
    active.value = false;
  }

  void dispose() {
    active.dispose();
    reducedMotion.dispose();
    controller.dispose();
    focus.dispose();
  }
}

class _TestApp extends StatelessWidget {
  const _TestApp({
    required this.harness,
    required this.locale,
    required this.scale,
  });

  final _Harness harness;
  final Locale locale;
  final double scale;

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: AppTheme.light(),
    locale: locale,
    supportedLocales: ReadflexSupportedLocales.locales,
    localizationsDelegates: readflexLocalizationsDelegates,
    builder: (context, child) => ValueListenableBuilder<bool>(
      valueListenable: harness.reducedMotion,
      builder: (context, reduced, _) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: reduced,
        ),
        child: child!,
      ),
    ),
    home: Scaffold(
      floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
      floatingActionButtonLocation: const LibraryFloatingActionsLocation(
        bottomViewPadding: 0,
      ),
      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: harness.active,
        builder: (context, active, child) => LibraryFloatingActions(
          scope: const LibraryCollectionScope.smart(
            type: LibraryCollectionScopeType.books,
            id: 'books',
            label: 'Books',
            sourceCount: 1,
          ),
          onCollectionsPressed: () => harness.collections++,
          onSearchPressed: harness.open,
          onAddPressed: () => harness.additions++,
          searchActive: active,
          horizontalViewPadding: harness.horizontalViewPadding,
          searchController: harness.controller,
          searchFocusNode: harness.focus,
          onSearchChanged: (value) => harness.query = value,
          onSearchClosed: harness.close,
          practiceDue: 2,
          onPracticePressed: () {},
        ),
      ),
    ),
  );
}

Future<_Harness> _pump(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  Locale locale = const Locale('en'),
  double scale = 1,
  bool reduceMotion = false,
  double horizontalViewPadding = 0,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final harness = _Harness()
    ..reducedMotion.value = reduceMotion
    ..horizontalViewPadding = horizontalViewPadding;
  addTearDown(harness.dispose);
  await tester.pumpWidget(
    _TestApp(harness: harness, locale: locale, scale: scale),
  );
  await tester.pumpAndSettle();
  return harness;
}

void main() {
  setUpAll(() async {
    await (FontLoader('Geist')..addFont(
          rootBundle.load(
            'packages/component_library/fonts/Geist-Variable.ttf',
          ),
        ))
        .load();
    final bytes = await File(
      '../../../test/fonts/NotoSansArabic.ttf',
    ).readAsBytes();
    await (FontLoader('Noto Sans Arabic')..addFont(
          Future.value(ByteData.sublistView(bytes)),
        ))
        .load();
  });

  for (final locale in [const Locale('en'), const Locale('ar')]) {
    testWidgets('Search sits between collections and Add in $locale', (
      tester,
    ) async {
      await _pump(tester, locale: locale);
      final centres = [
        tester.getCenter(_collections).dx,
        tester.getCenter(_search).dx,
        tester.getCenter(_add).dx,
      ];
      if (locale.languageCode == 'ar') {
        expect(centres[0], greaterThan(centres[1]));
        expect(centres[1], greaterThan(centres[2]));
      } else {
        expect(centres[0], lessThan(centres[1]));
        expect(centres[1], lessThan(centres[2]));
      }
      expect(tester.getSize(_search), const Size.square(48));
      expect(tester.getSize(_capsule).height, 56);
      expect(_field, findsNothing);
    });
  }

  testWidgets('one surface expands, preserves its anchor and reverses', (
    tester,
  ) async {
    final harness = await _pump(tester);
    final initial = tester.getRect(_capsule);
    final surface = tester.element(_capsule);
    await tester.tap(_search);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final opening = tester.getRect(_capsule);
    expect(identical(tester.element(_capsule), surface), isTrue);
    expect(opening.width, greaterThan(initial.width));
    expect(opening.width, lessThan(358));
    expect(opening.bottomRight, offsetMoreOrLessEquals(initial.bottomRight));
    expect(_field, findsOneWidget);
    expect(_collections.hitTestable(), findsNothing);
    expect(find.byKey(const ValueKey('libraryPracticeButton')), findsNothing);

    harness.close();
    await tester.pump();
    expect(tester.getRect(_capsule).width, closeTo(opening.width, .01));
    expect(_field, findsNothing);
    await tester.pumpAndSettle();
    expect(tester.getRect(_capsule), rectMoreOrLessEquals(initial));
    expect(find.byType(AppFloatingCapsule), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clear keeps editing; Back clears and restores browsing', (
    tester,
  ) async {
    final harness = await _pump(tester);
    await tester.tap(_search);
    await tester.pumpAndSettle();
    harness.focus.requestFocus();
    await tester.enterText(_field, 'Reading');
    await tester.pump();
    expect(harness.query, 'Reading');
    expect(_clear, findsOneWidget);
    await tester.tap(_clear);
    await tester.pump();
    expect(harness.controller.text, isEmpty);
    expect(harness.query, isEmpty);
    expect(harness.active.value, isTrue);
    expect(harness.focus.hasFocus, isTrue);
    expect(_clear, findsNothing);

    await tester.enterText(_field, 'Another query');
    await tester.pump();
    await tester.tap(_close);
    await tester.pump();
    expect(_field, findsNothing);
    expect(harness.focus.hasFocus, isFalse);
    expect(harness.query, isEmpty);
    expect(harness.controller.text, isEmpty);
    expect(find.text('Another query'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(_search, findsOneWidget);
    expect(harness.closed, 1);
    expect(tester.takeException(), isNull);
  });

  for (final locale in [const Locale('en'), const Locale('ar')]) {
    testWidgets('Back remains inside the expanding capsule at every frame: '
        '$locale', (tester) async {
      final harness = await _pump(tester, locale: locale, scale: 2);
      harness.open();
      await tester.pump();
      for (var frame = 0; frame < 14; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        final surface = tester.getRect(_capsule).inflate(.01);
        final back = tester.getRect(_close);
        expect(surface.contains(back.topLeft), isTrue);
        expect(surface.contains(back.bottomRight), isTrue);
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('a frozen long query retains its horizontal viewport and a quick '
      'empty reopen does not reuse it', (tester) async {
    final harness = await _pump(tester);
    harness.open();
    await tester.pumpAndSettle();
    harness.focus.requestFocus();
    const query =
        'A long search query that should scroll horizontally to its final words';
    await tester.enterText(_field, query);
    await tester.pumpAndSettle();
    final offset = tester.widget<TextField>(_field).scrollController!.offset;
    expect(offset, greaterThan(0));
    harness.close();
    await tester.pump();
    final viewport = find.byKey(
      const ValueKey('librarySearchSnapshotViewport'),
    );
    expect(_field, findsNothing);
    expect(viewport, findsOneWidget);
    expect(
      tester.widget<SingleChildScrollView>(viewport).controller!.offset,
      closeTo(offset, .01),
    );
    await tester.pump(const Duration(milliseconds: 40));
    harness.open();
    await tester.pump();
    harness.close();
    await tester.pump();
    expect(find.text(query), findsNothing);
    await tester.pumpAndSettle();
    expect(_field, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'resize and repeated reversals retain the current width and field',
    (tester) async {
      final harness = await _pump(tester);
      harness.open();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.view.physicalSize = const Size(800, 1280);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 32));
      final before = tester.getRect(_capsule);
      harness.close();
      await tester.pump();
      expect(tester.getRect(_capsule).width, closeTo(before.width, .01));
      await tester.pump(const Duration(milliseconds: 32));
      final reversing = tester.getRect(_capsule);
      harness.open();
      await tester.pump();
      expect(tester.getRect(_capsule).width, closeTo(reversing.width, .01));
      await tester.pumpAndSettle();
      expect(tester.getRect(_capsule).width, closeTo(480, .01));
      expect(_field, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('rapid toggles bound the exit layers and live fields', (
    tester,
  ) async {
    final harness = await _pump(tester);
    for (var switchIndex = 0; switchIndex < 12; switchIndex++) {
      harness.active.value = switchIndex.isEven;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byType(TextField).evaluate().length, lessThanOrEqualTo(1));
      expect(
        find
            .descendant(
              of: _capsule,
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget.key == const ValueKey('libraryBrowseModeLayer') ||
                    widget.key == const ValueKey('librarySearchModeLayer'),
              ),
            )
            .evaluate()
            .length,
        lessThanOrEqualTo(2),
      );
      expect(find.byType(AppFloatingCapsule), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpAndSettle();
    expect(_field, findsNothing);
    expect(_search, findsOneWidget);
  });

  testWidgets('fade-through keeps labels separate and reverses without an '
      'opacity jump', (tester) async {
    final harness = await _pump(tester);
    for (final (target, frames) in [
      (true, 6),
      (false, 3),
      (true, 2),
      (false, 9),
    ]) {
      final oldSearch = _layerOpacity(tester, 'librarySearchModeLayer');
      final oldBrowse = _layerOpacity(tester, 'libraryBrowseModeLayer');
      harness.active.value = target;
      await tester.pump();
      expect(
        _layerOpacity(tester, 'librarySearchModeLayer'),
        closeTo(oldSearch, .01),
      );
      expect(
        _layerOpacity(tester, 'libraryBrowseModeLayer'),
        closeTo(oldBrowse, .01),
      );
      for (var frame = 0; frame < frames; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(
          _layerOpacity(tester, 'librarySearchModeLayer') *
              _layerOpacity(tester, 'libraryBrowseModeLayer'),
          closeTo(0, .0001),
        );
      }
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion settles both modes without elapsed time', (
    tester,
  ) async {
    final harness = await _pump(tester, reduceMotion: true);
    final initial = tester.getRect(_capsule);
    harness.open();
    await tester.pump();
    expect(tester.getRect(_capsule).width, closeTo(358, .01));
    expect(_field, findsOneWidget);
    expect(_add, findsNothing);
    harness.close();
    await tester.pump();
    expect(tester.getRect(_capsule), rectMoreOrLessEquals(initial));
    expect(_field, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('enabling reduced motion settles an opening field without '
      'losing its query or focus', (tester) async {
    final harness = await _pump(tester);
    harness.open();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    harness.focus.requestFocus();
    await tester.enterText(_field, 'Still reading');
    await tester.pump();
    harness.reducedMotion.value = true;
    await tester.pump();
    await tester.pump();
    expect(_field, findsOneWidget);
    expect(harness.controller.text, 'Still reading');
    expect(harness.focus.hasFocus, isTrue);
    expect(tester.getRect(_capsule).width, closeTo(358, .01));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'search keeps the original horizontal safe insets from the screen',
    (tester) async {
      tester.view.viewPadding = const FakeViewPadding(left: 24, right: 8);
      tester.view.padding = const FakeViewPadding(left: 24, right: 8);
      final harness = await _pump(tester, horizontalViewPadding: 32);
      harness.open();
      await tester.pumpAndSettle();
      final bounds = tester.getRect(_capsule);
      expect(bounds.width, closeTo(326, .01));
      expect(bounds.left, closeTo(40, .01));
      expect(bounds.right, closeTo(366, .01));
      expect(tester.takeException(), isNull);
    },
  );

  for (final (locale, size, scale) in const [
    (Locale('de'), Size(320, 568), 2.0),
    (Locale('ar'), Size(390, 844), 2.0),
    (Locale('en'), Size(800, 1280), 1.0),
  ]) {
    testWidgets('editing fits $locale $size ${scale}x', (tester) async {
      final harness = await _pump(
        tester,
        locale: locale,
        size: size,
        scale: scale,
      );
      harness.open();
      await tester.pumpAndSettle();
      final bounds = tester.getRect(_capsule);
      expect(
        bounds.width,
        closeTo(size.width < 512 ? size.width - 32 : 480, .01),
      );
      expect(bounds.left, greaterThanOrEqualTo(16 - .01));
      expect(bounds.right, lessThanOrEqualTo(size.width - 16 + .01));
      expect(tester.getSize(_close), const Size.square(48));
      expect(
        MediaQuery.textScalerOf(tester.element(_field)).scale(14),
        closeTo(14 * scale, .01),
      );
      await tester.enterText(
        _field,
        'An overflowing query that remains editable in the available space',
      );
      await tester.pump();
      expect(tester.getSize(_clear), const Size.square(48));
      expect(tester.takeException(), isNull);
    });
  }
}
