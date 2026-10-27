import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex/app/developer/reader_engine_sheet.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  late PreferencesService preferences;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    preferences = await PreferencesService.create(supportedCodes: ['en']);
  });

  tearDown(() => preferences.dispose());

  Future<void> pumpSheet(
    WidgetTester tester, {
    Set<BookFormat> buildFormats = const {},
    Locale? locale,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        supportedLocales: ReadflexLocalizations.supportedLocales,
        home: Scaffold(
          body: ReaderEngineSheet(
            preferencesService: preferences,
            buildFormats: buildFormats,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder choice(BookFormat format) =>
      find.byKey(ValueKey('readerEngine-${format.name}'));

  testWidgets('shows the build setting and saves a per-format choice', (
    tester,
  ) async {
    await pumpSheet(tester, buildFormats: const {BookFormat.cbz});
    expect(
      tester.widget<AppChoiceControl<bool>>(choice(BookFormat.cbz)).selected,
      isTrue,
    );
    expect(
      tester.widget<AppChoiceControl<bool>>(choice(BookFormat.pdf)).selected,
      isFalse,
    );
    expect(find.byKey(const ValueKey('readerEngineReset')), findsNothing);

    final native = find.descendant(
      of: choice(BookFormat.pdf),
      matching: find.text('Native'),
    );
    await tester.tap(native);
    await tester.pumpAndSettle();
    expect(preferences.current.nativeReaderFormats, ['cbz', 'pdf']);
    expect(
      tester.widget<AppChoiceControl<bool>>(choice(BookFormat.pdf)).selected,
      isTrue,
    );

    final webView = find.descendant(
      of: choice(BookFormat.cbz),
      matching: find.text('WebView'),
    );
    await tester.tap(webView);
    await tester.pumpAndSettle();
    expect(preferences.current.nativeReaderFormats, ['pdf']);
  });

  for (final locale in ReadflexSupportedLocales.locales) {
    for (final (window, ratio) in const [
      (Size(390, 844), 1.0),
      (Size(320, 568), 1.0),
      (Size(320, 568), 2.0),
    ]) {
      testWidgets(
        'fits without truncation '
        '(${window.width.round()}@${ratio.round()}x, ${locale.toLanguageTag()})',
        (tester) async {
          tester.view.physicalSize = window * ratio;
          tester.view.devicePixelRatio = ratio;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await preferences.setNativeReaderFormats(['cbz']);
          await pumpSheet(tester, locale: locale);
          expect(tester.takeException(), isNull);
          for (final paragraph in tester.renderObjectList<RenderParagraph>(
            find.byType(RichText),
          )) {
            expect(paragraph.didExceedMaxLines, isFalse);
          }
          expect(
            find.byKey(const ValueKey('readerEngineReset')),
            findsOneWidget,
          );
        },
      );
    }
  }

  testWidgets('the reset action drops the override', (tester) async {
    await preferences.setNativeReaderFormats(['pdf']);
    await pumpSheet(tester);
    final reset = find.byKey(const ValueKey('readerEngineReset'));
    expect(reset, findsOneWidget);
    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(preferences.current.nativeReaderFormats, isNull);
    expect(find.byKey(const ValueKey('readerEngineReset')), findsNothing);
    expect(
      tester.widget<AppChoiceControl<bool>>(choice(BookFormat.pdf)).selected,
      isFalse,
      reason: 'back to the build, which has no native formats',
    );
  });
}
