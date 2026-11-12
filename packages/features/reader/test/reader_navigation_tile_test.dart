import 'package:component_library/component_library.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show ListTile, Material;
import 'package:reader/src/reader_navigation_tile.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import '../../../component_library/test_support/platform_test_app.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform navigation rows retain large RTL content and taps', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(320, 568)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var taps = 0;
      await tester.pumpWidget(
        PlatformTestApp(
          platform: platform,
          locale: const Locale('ar'),
          supportedLocales: ReadflexSupportedLocales.locales,
          localizationsDelegates: readflexLocalizationsDelegates,
          textScale: 2,
          home: SingleChildScrollView(
            child: AppSurface(
              child: ReaderNavigationTile(
                title: const Text(
                  'فصل طويل من الكتاب للقراءة',
                  maxLines: 3,
                ),
                subtitle: const Text('42', maxLines: 1),
                trailing: const Icon(AppIcons.check, size: 20),
                selected: true,
                onTap: () => taps++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byType(CupertinoListTile),
        platform == TargetPlatform.iOS ? findsOneWidget : findsNothing,
      );
      expect(
        find.byType(ListTile),
        platform == TargetPlatform.android ? findsOneWidget : findsNothing,
      );
      final row = find.byType(ReaderNavigationTile);
      expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(taps, 1);
      if (platform == TargetPlatform.iOS) {
        expect(find.byType(Material), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
