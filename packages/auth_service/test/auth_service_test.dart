import 'package:auth_service/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NoopAuthService', () {
    late NoopAuthService service;

    setUp(() => service = NoopAuthService());
    tearDown(() => service.dispose());

    test('status is unauthenticated', () {
      expect(service.status, AuthStatus.unauthenticated);
    });

    test('currentUser is null', () {
      expect(service.currentUser, isNull);
    });

    test('signIn completes without error', () async {
      await expectLater(
        service.signIn(email: 'a@b.com', password: '123'),
        completes,
      );
    });

    test('signOut completes without error', () async {
      await expectLater(service.signOut(), completes);
    });
  });

  group('AuthScope', () {
    testWidgets('of() throws when no AuthScope ancestor', (tester) async {
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            expect(() => AuthScope.of(context), throwsA(isA<FlutterError>()));
            return const SizedBox();
          },
        ),
      );
    });

    testWidgets('of() returns service from ancestor', (tester) async {
      final service = NoopAuthService();
      addTearDown(service.dispose);

      late AuthService result;
      await tester.pumpWidget(
        AuthScope(
          service: service,
          child: Builder(
            builder: (context) {
              result = AuthScope.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(result, same(service));
    });
  });
}
