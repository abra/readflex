import 'dart:io';

import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

const goldenBoundary = ValueKey('golden-surface');

enum VisualProfile {
  phone(Size(390, 844), Brightness.light, 1, Locale('en')),
  dark(Size(390, 844), Brightness.dark, 1, Locale('en')),
  largeText(Size(320, 568), Brightness.light, 2, Locale('de')),
  landscape(Size(844, 390), Brightness.light, 1, Locale('en')),
  tabletRtl(Size(768, 1024), Brightness.dark, 1, Locale('ar'));

  const VisualProfile(this.size, this.brightness, this.scale, this.locale);
  final Size size;
  final Brightness brightness;
  final double scale;
  final Locale locale;
}

Future<void> loadUiFonts() async {
  for (final entry in {
    'Noto Sans Phonetics': 'NotoSans-Phonetics.ttf',
    'Geist': 'Geist-Variable.ttf',
    'Literata': 'Literata-Variable.ttf',
    'PT Serif': 'PTSerif-Regular.ttf',
    'Open Sans': 'OpenSans-Variable.ttf',
  }.entries) {
    final family = entry.key;
    await (FontLoader(family)..addFont(
          rootBundle.load(
            'packages/component_library/fonts/${entry.value}',
          ),
        ))
        .load();
  }
  await (FontLoader('packages/lucide_icons_flutter/Lucide')..addFont(
        rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
      ))
      .load();
  for (final family in AppTypography.fontFamilyFallback) {
    final bytes = await File(
      'test/fonts/${family.replaceAll(' ', '')}.ttf',
    ).readAsBytes();
    await (FontLoader(
      family,
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  }
}

Future<void> pumpGoldenSurface(
  WidgetTester tester,
  VisualProfile profile,
  WidgetBuilder builder,
) async {
  tester.view.physicalSize = profile.size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      debugShowCheckedModeBanner: false,
      theme: profile.brightness == Brightness.light
          ? AppTheme.light()
          : AppTheme.dark(),
      locale: profile.locale,
      supportedLocales: ReadflexSupportedLocales.locales,
      localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
      builder: (context, child) => RepaintBoundary(
        key: goldenBoundary,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(profile.scale),
            disableAnimations: true,
          ),
          child: child!,
        ),
      ),
      home: Builder(builder: builder),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> expectUiGolden(
  WidgetTester tester,
  VisualProfile profile,
  String surface,
) async {
  expect(tester.takeException(), isNull, reason: '$surface/${profile.name}');
  await expectLater(
    find.byKey(goldenBoundary),
    matchesGoldenFile('goldens/${profile.name}/$surface.png'),
  );
  expect(tester.takeException(), isNull, reason: '$surface/${profile.name}');
}
