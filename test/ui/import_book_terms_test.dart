import 'dart:async';

import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:import_flow/import_flow.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'golden_support.dart';

void main() {
  setUpAll(loadUiFonts);

  for (final width in [360.0, 390.0, 402.0, 430.0]) {
    testWidgets('compact consent keeps the sheet level at width $width', (
      tester,
    ) async {
      late BuildContext host;
      await pumpGoldenSurface(tester, VisualProfile.phone, (context) {
        host = context;
        return const Scaffold();
      }, surfaceSize: Size(width, 900));
      unawaited(
        showImportFlowSheet(
          host,
          onPickBookFile: () async => null,
          onImportBook: (_, {onProgress}) async => null,
          onImportArticle: (_, {onStage}) async => null,
          isBookImportTermsAccepted: () => false,
        ),
      );
      await tester.pumpAndSettle();
      final menuRect = tester.getRect(find.byType(BottomSheet));
      for (final action in [
        find.text(host.l10n.importFromDevice),
        find.byTooltip(host.l10n.commonBack),
      ]) {
        await tester.tap(action);
        await tester.pump();
        // Inspect intermediate frames too: equal final sizes can hide a jump.
        for (var frame = 0; frame < 22; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(tester.getRect(find.byType(BottomSheet)), menuRect);
        }
        await tester.pumpAndSettle();
        expect(tester.getRect(find.byType(BottomSheet)), menuRect);
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.byTooltip(host.l10n.commonClose));
      await tester.pumpAndSettle();
    });
  }

  for (final locale in ReadflexSupportedLocales.locales) {
    for (final profile in [VisualProfile.phone, VisualProfile.largeText]) {
      testWidgets('book terms ${locale.languageCode} ${profile.name}', (
        tester,
      ) async {
        late BuildContext host;
        await pumpGoldenSurface(tester, profile, (context) {
          host = context;
          return const Scaffold();
        }, locale: locale);
        final l10n = host.l10n;
        var pickerCalls = 0;
        var acceptCalls = 0;
        var termsCalls = 0;
        var privacyCalls = 0;
        unawaited(
          showImportFlowSheet(
            host,
            onPickBookFile: () async {
              pickerCalls++;
              return null;
            },
            onImportBook: (_, {onProgress}) async => null,
            onImportArticle: (_, {onStage}) async => null,
            isBookImportTermsAccepted: () => false,
            acceptBookImportTerms: () async => acceptCalls++,
            onOpenTerms: () async => termsCalls++,
            onOpenPrivacy: () async => privacyCalls++,
          ),
        );
        await tester.pumpAndSettle();
        final menuRect = tester.getRect(find.byType(BottomSheet));
        await tester.ensureVisible(find.text(l10n.importFromDevice));
        await tester.tap(find.text(l10n.importFromDevice));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final legalText = find.byKey(const ValueKey('importFlowLegalText'));
        final legalStyle = host.text.bodySmall.copyWith(
          color: host.colors.onSurfaceVariant,
        );
        final paragraph = TextPainter(
          text: TextSpan(
            text:
                '${l10n.importLegalPrefix}${l10n.importTerms}'
                '${l10n.importLegalAnd}${l10n.importPrivacyPolicy}'
                '${l10n.importLegalSuffix}',
            style: legalStyle,
          ),
          textDirection: Directionality.of(tester.element(legalText)),
          textScaler: TextScaler.linear(profile.scale),
          locale: locale,
        )..layout(maxWidth: tester.getSize(legalText).width);
        addTearDown(paragraph.dispose);
        expect(
          tester.getSize(legalText).height,
          closeTo(paragraph.height, .01),
          reason: 'inline links must keep the normal paragraph line height',
        );

        final scrollable = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Scrollable),
        );
        expect(scrollable, findsOneWidget);
        final position = tester.state<ScrollableState>(scrollable).position;
        final confirm = find.text(l10n.importBookTermsConfirm);
        final checkbox = find.byType(Checkbox);
        final primary = find.widgetWithText(FilledButton, l10n.commonContinue);
        expect(tester.widget<FilledButton>(primary).onPressed, isNull);

        if (profile.scale == 1) {
          expect(
            position.maxScrollExtent,
            0,
            reason: 'the full consent form fits on a normal phone',
          );
          expect(checkbox.hitTestable(), findsOneWidget);
          expect(
            tester.getRect(confirm).bottom,
            lessThan(tester.getRect(primary).top),
            reason: 'the entire confirmation stays above the footer',
          );
          final fades = tester.widgetList<ScrollEdgeFade>(
            find.descendant(
              of: find.byType(BottomSheet),
              matching: find.byType(ScrollEdgeFade),
            ),
          );
          expect(fades.every((fade) => !fade.visible), isTrue);
        }

        final semantics = tester.ensureSemantics();
        try {
          for (final label in [l10n.importTerms, l10n.importPrivacyPolicy]) {
            await Scrollable.ensureVisible(
              tester.element(legalText),
              alignment: label == l10n.importTerms ? 0 : 1,
            );
            await tester.pumpAndSettle();
            expect(
              find.semantics.byLabel(label).evaluate().single,
              matchesSemantics(label: label, isLink: true, hasTapAction: true),
            );
            await tester.tapOnText(
              find.textRange.ofSubstring(label, descendentOf: legalText),
            );
          }
        } finally {
          semantics.dispose();
        }
        expect(termsCalls, 1);
        expect(privacyCalls, 1);
        expect(pickerCalls, 0);

        await tester.ensureVisible(checkbox);
        await tester.pumpAndSettle();
        await tester.tap(checkbox);
        await tester.pumpAndSettle();
        expect(tester.widget<Checkbox>(checkbox).value, isTrue);
        expect(tester.widget<FilledButton>(primary).onPressed, isNotNull);
        // A short landscape viewport may switch to scrolling the entire form.
        // That layout change must preserve the user's explicit confirmation.
        tester.view.physicalSize = Size(
          profile.size.height,
          profile.size.width,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(tester.widget<Checkbox>(checkbox).value, isTrue);
        await tester.ensureVisible(primary);
        await tester.pumpAndSettle();
        expect(primary.hitTestable(), findsOneWidget);
        expect(tester.getSize(primary).height, greaterThanOrEqualTo(48));
        tester.view.physicalSize = profile.size;
        await tester.pumpAndSettle();
        expect(tester.widget<Checkbox>(checkbox).value, isTrue);
        await tester.ensureVisible(primary);
        await tester.pumpAndSettle();
        await tester.tap(primary);
        await tester.pumpAndSettle();
        expect(acceptCalls, 1);
        expect(pickerCalls, 1);
        expect(find.text(l10n.importAddToLibraryTitle), findsOneWidget);
        expect(tester.getRect(find.byType(BottomSheet)), menuRect);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip(l10n.commonClose));
        await tester.pumpAndSettle();
      });
    }
  }
}
