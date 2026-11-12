import 'package:component_library/component_library.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_highlight_footer.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import '../../../component_library/test_support/platform_test_app.dart';

void main() {
  for (final (platform, size, gutter, labelInset, targetInset) in [
    (TargetPlatform.android, const Size(390, 844), 16.0, 16.0, 0.0),
    (TargetPlatform.iOS, const Size(390, 844), 24.0, 24.0, 12.0),
    (TargetPlatform.iOS, const Size(1024, 768), 16.0, 12.0, 0.0),
  ]) {
    for (final locale in [const Locale('en'), const Locale('ar')]) {
      testWidgets('highlight footer aligns ${platform.name} $size $locale', (
        tester,
      ) async {
        tester.view
          ..physicalSize = size
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var expanded = 0;
        await tester.pumpWidget(
          PlatformTestApp(
            platform: platform,
            locale: locale,
            supportedLocales: ReadflexSupportedLocales.locales,
            localizationsDelegates: readflexLocalizationsDelegates,
            home: Align(
              alignment: Alignment.topCenter,
              child: ReaderHighlightFooter(
                location: 'Chapter 1',
                canExpand: true,
                expanded: false,
                onExpanded: () => expanded++,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final footer = tester.getRect(find.byType(ReaderHighlightFooter));
        final location = tester.getRect(find.text('Chapter 1'));
        final context = tester.element(find.byType(ReaderHighlightFooter));
        final label = tester.getRect(
          find.text(context.l10n.readerExpandHighlight),
        );
        final action = find.byType(AppButton);
        final target = tester.getRect(action);
        final rtl = locale.languageCode == 'ar';
        expect(
          rtl ? footer.right - location.right : location.left - footer.left,
          gutter,
        );
        expect(
          rtl ? label.left - footer.left : footer.right - label.right,
          labelInset,
        );
        expect(
          rtl ? target.left - footer.left : footer.right - target.right,
          targetInset,
        );
        expect(target.height, greaterThanOrEqualTo(48));
        await tester.tap(action);
        expect(expanded, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
