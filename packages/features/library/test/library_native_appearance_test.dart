import 'package:component_library/component_library.dart';
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoPopupSurface;
import 'package:domain_models/domain_models.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_feature/src/library_bloc.dart';
import 'package:library_feature/src/library_continue_reading_card.dart';
import 'package:library_feature/src/library_display_sheet.dart';
import 'package:library_feature/src/library_header.dart';
import 'package:library_feature/src/library_layout.dart';
import 'package:library_feature/src/library_layout_cubit.dart';
import 'package:library_feature/src/library_locale_cubit.dart';
import 'package:library_feature/src/library_page_animation_cubit.dart';
import 'package:library_feature/src/library_theme_cubit.dart';
import 'package:material_ui/material_ui.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../../component_library/test_support/platform_test_app.dart';

final _card = find.byKey(const ValueKey('libraryContinueReadingCard'));
final _cover = find.byKey(const ValueKey('libraryContinueReadingCover'));
final _title = find.byKey(const ValueKey('libraryContinueReadingTitle'));
final _progress = find.byKey(const ValueKey('libraryContinueReadingProgress'));

void main() {
  setUpAll(() async {
    for (final family in ['Literata', 'Geist']) {
      await (FontLoader(family)..addFont(
            rootBundle.load(
              'packages/component_library/fonts/$family-Variable.ttf',
            ),
          ))
          .load();
    }
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final brightness in Brightness.values) {
      testWidgets('$platform reading card uses its content role and selection '
          'in $brightness', (tester) async {
        tester.view
          ..physicalSize = const Size(1032, 1376)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final selected = ValueNotifier(false);
        addTearDown(selected.dispose);
        final source = _source(const Locale('de'));
        await tester.pumpWidget(
          PlatformTestApp(
            platform: platform,
            brightness: brightness,
            supportedLocales: ReadflexSupportedLocales.locales,
            localizationsDelegates: readflexLocalizationsDelegates,
            home: Align(
              alignment: Alignment.topCenter,
              child: ValueListenableBuilder<bool>(
                valueListenable: selected,
                builder: (context, value, _) => LibraryContinueReadingCard(
                  source: source,
                  isSelectionMode: true,
                  isSelected: value,
                  onPressed: () => selected.value = !value,
                  onLongPressed: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final context = tester.element(_card);
        final appearance = AppSurfaceAppearance.resolve(
          context,
          AppSurfaceRole.contentCard,
        );
        final surface = tester.widget<AppSurface>(_card);
        expect(surface.role, AppSurfaceRole.contentCard);
        expect(surface.shape, appearance.shape);
        expect(surface.color, isNull);
        expect(
          appearance.shape,
          platform == TargetPlatform.iOS
              ? isA<RoundedSuperellipseBorder>()
              : isA<RoundedRectangleBorder>(),
        );
        expect(tester.getSize(_cover), const Size(60, 90));
        expect(tester.getSize(_card).height, 122);
        final coverRect = tester.getRect(_cover);
        final progressRect = tester.getRect(_progress);
        expect(progressRect.bottom, coverRect.bottom);
        expect(progressRect.left - coverRect.right, kLibraryListCoverToTextGap);
        await tester.tap(_card);
        await tester.pumpAndSettle();
        final selectedSurface = tester.widget<AppSurface>(_card);
        expect(selectedSurface.color, context.colors.selectedControlBackground);
        expect(
          (selectedSurface.shape! as OutlinedBorder).side.color,
          context.colors.selectedControlForeground,
        );
        expect(
          find.byKey(const ValueKey('libraryListSelectionCheck')),
          findsOneWidget,
        );
        expect(tester.getSize(_card).height, 122);
        expect(tester.takeException(), isNull);
      });
    }

    for (final locale in [const Locale('de'), const Locale('ar')]) {
      testWidgets('$platform 200% phone retains full reading title and '
          'hierarchy in $locale', (tester) async {
        tester.view
          ..physicalSize = const Size(320, 568)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final source = _source(locale, long: true);
        await tester.pumpWidget(
          PlatformTestApp(
            platform: platform,
            locale: locale,
            textScale: 2,
            supportedLocales: ReadflexSupportedLocales.locales,
            localizationsDelegates: readflexLocalizationsDelegates,
            home: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LibraryHeader(
                    state: LibraryState(sources: [source]),
                    isOffline: false,
                    onDisplayPressed: () {},
                  ),
                  LibraryContinueReadingCard(
                    source: source,
                    onPressed: () {},
                    onLongPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final title = tester.widget<Text>(_title);
        final author = tester.widget<Text>(find.text(source.author!));
        final paragraph = tester.renderObject<RenderParagraph>(_title);
        expect(tester.getSize(_cover), const Size(60, 90));
        expect(title.data, source.title);
        expect(title.maxLines, isNull);
        expect(title.overflow, isNull);
        expect(title.style!.fontSize, greaterThan(author.style!.fontSize!));
        expect(
          paragraph.textScaler.scale(title.style!.fontSize!),
          title.style!.fontSize! * 2,
        );
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(
          tester.getRect(_title).top,
          greaterThan(tester.getRect(_cover).bottom),
        );
        expect(
          tester.getRect(find.text(source.author!)).top,
          greaterThan(tester.getRect(_title).bottom),
        );
        final heading = find.descendant(
          of: find.byKey(const ValueKey('libraryHeaderTitle')),
          matching: find.byType(Text),
        );
        expect(
          tester.renderObject<RenderParagraph>(heading).didExceedMaxLines,
          isFalse,
        );
        final headingRect = tester.getRect(heading);
        expect(headingRect.left, greaterThanOrEqualTo(AppSpacing.lg));
        expect(headingRect.right, lessThanOrEqualTo(320 - AppSpacing.lg));
        await tester.ensureVisible(_progress);
        await tester.pumpAndSettle();
        expect(_progress.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('$platform Display applies choices immediately and keeps '
          'Language in the same modal at 200% $locale', (tester) async {
        tester.view
          ..physicalSize = const Size(320, 568)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        SharedPreferencesAsyncPlatform.instance =
            InMemorySharedPreferencesAsync.empty();
        final preferences = await PreferencesService.create(
          supportedCodes: ReadflexSupportedLocales.codes,
        );
        final layout = LibraryLayoutCubit(preferencesService: preferences);
        final language = LibraryLocaleCubit(preferencesService: preferences);
        final theme = LibraryThemeCubit(preferencesService: preferences);
        final animation = LibraryPageAnimationCubit(
          preferencesService: preferences,
        );
        addTearDown(preferences.dispose);
        addTearDown(layout.close);
        addTearDown(language.close);
        addTearDown(theme.close);
        addTearDown(animation.close);
        await language.setLocale(locale);
        await tester.pumpWidget(
          PreferencesScope(
            service: preferences,
            child: Builder(
              builder: (context) => PlatformTestApp(
                platform: platform,
                locale: PreferencesScope.localeOf(context),
                textScale: 2,
                supportedLocales: ReadflexSupportedLocales.locales,
                localizationsDelegates: readflexLocalizationsDelegates,
                home: Builder(
                  builder: (context) => Center(
                    child: AppButton(
                      onPressed: () => showLibraryDisplaySheet(
                        context: context,
                        layoutCubit: layout,
                        localeCubit: language,
                        themeCubit: theme,
                        pageAnimationCubit: animation,
                      ),
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.byType(AppSettingsSection), findsNWidgets(3));
        final slide = find.byKey(
          const ValueKey('library-page-animation-slide'),
        );
        await tester.ensureVisible(slide);
        await tester.pumpAndSettle();
        await tester.tap(slide);
        await tester.pumpAndSettle();
        expect(
          preferences.current.readerPageAnimation,
          ReaderPageAnimation.slide,
        );
        final picker = find.byKey(const ValueKey('libraryLanguagePicker'));
        await tester.ensureVisible(picker);
        await tester.pumpAndSettle();
        final sheet = platform == TargetPlatform.iOS
            ? find.byType(CupertinoPopupSurface)
            : find.byType(BottomSheet);
        final originalRect = tester.getRect(sheet);
        await tester.tap(picker);
        await tester.pumpAndSettle();
        expect(tester.getRect(sheet), originalRect);
        final english = find.byKey(const ValueKey('libraryLanguageOption-en'));
        await tester.ensureVisible(english);
        await tester.pumpAndSettle();
        await tester.tap(english);
        await tester.pumpAndSettle();
        expect(preferences.current.locale, const Locale('en'));
        expect(tester.getRect(sheet), originalRect);
        await tester.tap(
          find.byTooltip(tester.element(english).l10n.commonBack),
        );
        await tester.pumpAndSettle();
        expect(picker, findsOneWidget);
        expect(
          tester
              .widget<AppChoiceControl<ReaderPageAnimation>>(
                find.byKey(const ValueKey('library-page-animation-control')),
              )
              .selected,
          ReaderPageAnimation.slide,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}

LibrarySource _source(Locale locale, {bool long = false}) {
  final title = locale.languageCode == 'ar'
      ? 'كتاب عن القراءة والتعلم'
      : 'Lesen und Lernen im Alltag';
  return LibrarySource.fromBook(
    Book(
      id: 'reading',
      title: long ? List.filled(6, title).join(' ') : title,
      author: locale.languageCode == 'ar' ? 'كاتب الكتاب' : 'Ada Writer',
      filePath: '/reading.epub',
      format: BookFormat.epub,
      readingProgress: .42,
      addedAt: DateTime(2026),
    ),
  );
}
