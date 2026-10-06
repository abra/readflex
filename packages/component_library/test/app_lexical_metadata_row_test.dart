import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child, {double width = 400}) => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: Align(
        alignment: AlignmentDirectional.topStart,
        child: SizedBox(width: width, child: child),
      ),
    ),
  );

  testWidgets('renders reading, phonetic pronunciation and part of speech', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const AppLexicalMetadataRow(
          reading: 'ぎんこう',
          pronunciation: '/ˈpaʊər/',
          partOfSpeech: 'noun',
        ),
      ),
    );
    final context = tester.element(find.byType(AppLexicalMetadataRow));
    final muted = context.text.bodyMedium.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    expect(tester.widget<Text>(find.text('ぎんこう')).style, muted);
    expect(tester.widget<Text>(find.text('noun')).style, muted);
    expect(
      tester.widget<Text>(find.text('/ˈpaʊər/')).style,
      muted.copyWith(fontFamily: AppTypography.fontFamilyPhonetic),
    );
    expect(
      tester.getTopLeft(find.text('/ˈpaʊər/')).dx -
          tester.getTopRight(find.text('ぎんこう')).dx,
      AppSpacing.sm,
    );
  });

  testWidgets('pronunciation stays LTR inside an RTL row', (tester) async {
    await tester.pumpWidget(
      host(
        const AppLexicalMetadataRow(
          reading: 'الطاقة',
          pronunciation: '/ˈpaʊər/',
          textDirection: TextDirection.rtl,
        ),
      ),
    );
    expect(
      Directionality.of(tester.element(find.text('/ˈpaʊər/'))),
      TextDirection.ltr,
    );
    expect(
      tester.widget<Text>(find.text('الطاقة')).textDirection,
      TextDirection.rtl,
    );
    // The row keeps the ambient (LTR) order; only the reading is RTL text.
    expect(
      tester.getTopLeft(find.text('/ˈpaʊər/')).dx,
      greaterThan(tester.getTopLeft(find.text('الطاقة')).dx),
    );
  });

  testWidgets('pieces keep separate semantics nodes', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        host(
          const AppLexicalMetadataRow(
            pronunciation: '/ˈpaʊər/',
            partOfSpeech: 'noun',
          ),
        ),
      );
      expect(find.bySemanticsLabel('/ˈpaʊər/'), findsOneWidget);
      expect(find.bySemanticsLabel('noun'), findsOneWidget);
      expect(find.bySemanticsLabel('/ˈpaʊər/ noun'), findsNothing);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('wraps onto a second run when narrow', (tester) async {
    await tester.pumpWidget(
      host(
        const AppLexicalMetadataRow(
          reading: 'a long reading',
          pronunciation: '/ˈlɒŋ prəˌnʌnsiˈeɪʃən/',
          partOfSpeech: 'adjective',
        ),
        width: 160,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(find.text('adjective')).dy,
      greaterThan(tester.getTopLeft(find.text('a long reading')).dy),
    );
  });

  testWidgets('renders nothing when every value is null or blank', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const AppLexicalMetadataRow(pronunciation: ' ', reading: '')),
    );
    expect(find.byType(Wrap), findsNothing);
    expect(find.byType(Text), findsNothing);
    expect(tester.getSize(find.byType(AppLexicalMetadataRow)).height, 0);
  });
}
