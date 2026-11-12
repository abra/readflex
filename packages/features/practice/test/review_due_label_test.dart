import 'package:domain_models/domain_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:practice/src/review_due_label.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

void main() {
  Future<String> labelFor(
    WidgetTester tester,
    FsrsCardData fsrs, {
    Locale locale = const Locale('en'),
    bool use24HourFormat = true,
  }) async {
    String? label;
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        supportedLocales: ReadflexSupportedLocales.locales,
        localizationsDelegates: readflexLocalizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            alwaysUse24HourFormat: use24HourFormat,
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) {
            label = reviewDueLabel(context, fsrs);
            return Text(label!);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(label, isNotNull);
    return label!;
  }

  testWidgets('formats the same local and UTC instant in local clock time', (
    tester,
  ) async {
    final local = DateTime(2030, 2, 15, 14, 35);
    const expected = 'Next review: Feb 15, 2030, 14:35';
    for (final deadline in [local, local.toUtc()]) {
      final fsrs = FsrsCardData(
        state: FsrsState.review,
        nextReviewAt: deadline,
      );
      expect(await labelFor(tester, fsrs), expected);
    }
  });

  testWidgets('honours the system 12-hour or 24-hour preference', (
    tester,
  ) async {
    final fsrs = FsrsCardData(
      state: FsrsState.review,
      nextReviewAt: DateTime(2030, 2, 15, 14, 35).toUtc(),
    );
    expect(
      await labelFor(tester, fsrs, use24HourFormat: false),
      'Next review: Feb 15, 2030, 2:35 PM',
    );
    expect(
      await labelFor(tester, fsrs),
      'Next review: Feb 15, 2030, 14:35',
    );
  });

  testWidgets('localizes the calendar date and supports Arabic RTL', (
    tester,
  ) async {
    final fsrs = FsrsCardData(
      state: FsrsState.review,
      nextReviewAt: DateTime(2030, 2, 15, 14, 35),
    );
    final english = await labelFor(tester, fsrs);
    final russian = await labelFor(tester, fsrs, locale: const Locale('ru'));
    expect(russian, startsWith('Повторение: '));
    expect(russian, contains('февр'));
    expect(russian, contains('2030'));
    expect(russian, contains('14:35'));

    final arabic = await labelFor(tester, fsrs, locale: const Locale('ar'));
    expect(arabic, startsWith('المراجعة التالية: '));
    expect(arabic, contains('فبراير'));
    expect(
      Directionality.of(tester.element(find.text(arabic))),
      TextDirection.rtl,
    );
    // Locale changes must not reuse another locale's cached formatter.
    expect(await labelFor(tester, fsrs), english);
  });

  testWidgets('missing deadlines keep the new or due status', (tester) async {
    expect(await labelFor(tester, const FsrsCardData()), 'New');
    expect(
      await labelFor(tester, const FsrsCardData(state: FsrsState.review)),
      'Due',
    );
  });

  testWidgets('preserves stored dates for overdue and new-state items', (
    tester,
  ) async {
    final deadline = DateTime(2001, 2, 15, 14, 35).toUtc();
    for (final state in [FsrsState.review, FsrsState.newCard]) {
      expect(
        await labelFor(
          tester,
          FsrsCardData(state: state, nextReviewAt: deadline),
        ),
        'Next review: Feb 15, 2001, 14:35',
      );
    }
  });
}
