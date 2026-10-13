import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onboarding/onboarding.dart';
import 'package:onboarding/src/onboarding_app_icon.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

// Layout, copy, accessibility and goldens are covered by the app's
// test/ui/onboarding_test.dart; these tests pin the package contract.

void main() {
  Future<ReadflexLocalizations> pumpOnboarding(
    WidgetTester tester, {
    required VoidCallback onAddBook,
    required VoidCallback onNotNow,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
        supportedLocales: ReadflexSupportedLocales.locales,
        home: OnboardingScreen(onAddBook: onAddBook, onNotNow: onNotNow),
      ),
    );
    return ReadflexLocalizations.of(
      tester.element(find.byType(OnboardingScreen)),
    )!;
  }

  group('actions', () {
    testWidgets('Add your first book calls only onAddBook', (tester) async {
      var added = 0;
      var skipped = 0;
      final l10n = await pumpOnboarding(
        tester,
        onAddBook: () => added++,
        onNotNow: () => skipped++,
      );

      await tester.tap(
        find.widgetWithText(FilledButton, l10n.onboardingAddBook),
      );
      await tester.pump();

      expect(added, 1);
      expect(skipped, 0);
    });

    testWidgets('Not now calls only onNotNow', (tester) async {
      var added = 0;
      var skipped = 0;
      final l10n = await pumpOnboarding(
        tester,
        onAddBook: () => added++,
        onNotNow: () => skipped++,
      );

      await tester.tap(find.widgetWithText(TextButton, l10n.onboardingNotNow));
      await tester.pump();

      expect(added, 0);
      expect(skipped, 1);
    });
  });

  group('app icon', () {
    test('the app resolves the icon from this package', () {
      expect(onboardingAppIcon.package, 'onboarding');
      expect(
        onboardingAppIcon.keyName,
        'packages/onboarding/assets/app_icon.png',
      );
    });

    test('the package bundles the icon at 1x, 2x and 3x', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      // A package's own tests bundle its assets without the packages/ prefix.
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final variants = manifest.getAssetVariants(onboardingAppIcon.assetName);

      expect(
        variants?.map((variant) => variant.targetDevicePixelRatio),
        unorderedEquals([null, 2.0, 3.0]),
      );
    });

    testWidgets('the icon is decorative and 80dp square', (tester) async {
      await pumpOnboarding(tester, onAddBook: () {}, onNotNow: () {});

      final image = tester.widget<Image>(
        find.descendant(
          of: find.byType(OnboardingAppIcon),
          matching: find.byType(Image),
        ),
      );
      expect(image.image, onboardingAppIcon);
      expect(image.excludeFromSemantics, isTrue);
      expect(
        tester.getSize(find.byType(OnboardingAppIcon)),
        const Size.square(OnboardingAppIcon.size),
      );
    });
  });
}
