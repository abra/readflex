import 'package:auth_service/auth_service.dart';
import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:profile/profile.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:subscription_service/subscription_service.dart';

void main() {
  late NoopAuthService authService;
  late PreferencesService preferencesService;

  setUp(() async {
    authService = NoopAuthService();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    preferencesService = await PreferencesService.create(
      supportedCodes: ['en'],
    );
  });

  tearDown(() => authService.dispose());

  Widget buildSubject({
    SubscriptionService? subscriptionService,
    String appVersion = '2.0.0',
  }) => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: ProfileScreen(
        authService: authService,
        subscriptionService:
            subscriptionService ?? const NoopSubscriptionService(),
        preferencesService: preferencesService,
        onSignInPressed: () {},
        onPremiumPressed: () {},
        appVersion: appVersion,
      ),
    ),
  );

  testWidgets('renders Guest label for unauthenticated user', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Guest'), findsOneWidget);
    expect(find.text('Sign in to sync your data'), findsOneWidget);
  });

  testWidgets('renders visible section labels', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    // Top sections are in the initial viewport
    expect(find.text('APPEARANCE'), findsOneWidget);
    expect(find.text('READING'), findsOneWidget);
    expect(find.text('GENERAL'), findsOneWidget);
  });

  testWidgets('renders settings rows', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Font & Text Size'), findsOneWidget);
    expect(find.text('Translation Language'), findsOneWidget);
    expect(find.text('Sync & Backup'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Privacy'), findsOneWidget);
  });

  testWidgets('renders app version after scrolling', (tester) async {
    await tester.pumpWidget(buildSubject(appVersion: '3.1.0'));
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('3.1.0'),
      200,
      scrollable: find.byType(Scrollable).last,
    );

    expect(find.text('3.1.0'), findsOneWidget);
  });

  testWidgets('renders stats row with placeholder values', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Books'), findsOneWidget);
    expect(find.text('Read time'), findsOneWidget);
    expect(find.text('Streak'), findsOneWidget);
  });

  testWidgets('does not show Sign Out for guest', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Sign Out'), findsNothing);
  });
}
