import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subscription_paywall/subscription_paywall.dart';

import 'helpers/fake_subscription_service.dart';

void main() {
  late FakeSubscriptionService service;

  setUp(() {
    service = FakeSubscriptionService();
  });

  Widget buildSubject() => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: SingleChildScrollView(
        child: SubscriptionPaywallSheet(subscriptionService: service),
      ),
    ),
  );

  testWidgets('renders header and headline', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump(); // let load() complete

    expect(find.text('Readflex Premium'), findsOneWidget);
    expect(find.text('Unlock Premium Features'), findsOneWidget);
  });

  testWidgets('renders three feature items', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(
      find.text('AI-powered translations with context'),
      findsOneWidget,
    );
    expect(find.text('AI-generated flashcards'), findsOneWidget);
    expect(find.text('Cloud sync across devices'), findsOneWidget);
  });

  testWidgets('renders Subscribe and Maybe later buttons', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Subscribe'), findsOneWidget);
    expect(find.text('Maybe later'), findsOneWidget);
  });

  testWidgets('shows error message on purchase failure', (tester) async {
    service.shouldThrow = true;
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await tester.tap(find.text('Subscribe'));
    await tester.pump();

    expect(find.text('Purchase failed. Please try again.'), findsOneWidget);
  });

  testWidgets('premium icon is rendered', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.byIcon(AppIcons.premium), findsOneWidget);
  });
}
