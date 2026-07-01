import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'reader route keeps fullscreen behavior without platform transition',
    () {
      final source = File('lib/app/routing.dart').readAsStringSync();
      final readerRoute = _readerRouteSource(source);

      expect(readerRoute, contains('return CustomTransitionPage'));
      expect(readerRoute, contains('fullscreenDialog: true'));
      expect(readerRoute, contains('transitionDuration: Duration.zero'));
      expect(readerRoute, contains('reverseTransitionDuration: Duration.zero'));
      expect(
        readerRoute,
        contains('transitionsBuilder: (_, _, _, child) => child'),
      );
      expect(readerRoute, isNot(contains('return MaterialPage')));
    },
  );
}

String _readerRouteSource(String source) {
  final start = source.indexOf('path: AppRoutes.readerPath');
  if (start == -1) {
    throw StateError('Reader route not found.');
  }
  final end = source.indexOf('path: AppRoutes.onboarding', start);
  if (end == -1) {
    throw StateError('Reader route end not found.');
  }
  return source.substring(start, end);
}
