import 'dart:async';

import 'package:component_library/component_library.dart';
import 'package:connectivity_service/connectivity_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex/app/connectivity_banner_host.dart';

void main() {
  group('AppConnectivityBannerHost', () {
    testWidgets('does not show the offline banner while online', (
      tester,
    ) async {
      final service = _FakeConnectivityService(ConnectivityStatus.online);
      addTearDown(service.dispose);

      await tester.pumpWidget(_TestApp(service: service));

      expect(find.text('No internet connection'), findsNothing);
      expect(find.byType(OfflineBanner), findsNothing);
    });

    testWidgets('shows the offline banner while offline', (tester) async {
      final service = _FakeConnectivityService(ConnectivityStatus.offline);
      addTearDown(service.dispose);

      await tester.pumpWidget(_TestApp(service: service));

      expect(find.text('No internet connection'), findsOneWidget);
      expect(find.byType(OfflineBanner), findsOneWidget);
    });

    testWidgets('shows the offline banner above route content', (
      tester,
    ) async {
      final service = _FakeConnectivityService(ConnectivityStatus.offline);
      addTearDown(service.dispose);

      await tester.pumpWidget(
        _TestApp(
          service: service,
          child: const Align(
            alignment: Alignment.topCenter,
            child: Text('Library'),
          ),
        ),
      );

      final bannerRect = tester.getRect(find.byType(OfflineBanner));
      final titleRect = tester.getRect(find.text('Library'));

      expect(bannerRect.top, 0);
      expect(titleRect.top, greaterThanOrEqualTo(bannerRect.bottom));
    });

    testWidgets('hides the offline banner on reader routes', (tester) async {
      final service = _FakeConnectivityService(ConnectivityStatus.offline);
      addTearDown(service.dispose);

      await tester.pumpWidget(
        _TestApp(service: service, currentPath: '/reader/source-1'),
      );

      expect(find.byType(OfflineBanner), findsNothing);
      expect(find.text('No internet connection'), findsNothing);
    });

    testWidgets('updates from connectivity stream', (tester) async {
      final service = _FakeConnectivityService(ConnectivityStatus.online);
      addTearDown(service.dispose);

      await tester.pumpWidget(
        _TestApp(
          service: service,
          child: const SizedBox.expand(child: Text('Library')),
        ),
      );

      service.emit(ConnectivityStatus.offline);
      await tester.pump();

      expect(find.byType(OfflineBanner), findsOneWidget);

      service.emit(ConnectivityStatus.online);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));

      expect(find.byType(OfflineBanner), findsNothing);
    });

    testWidgets('removes top padding from child while banner is visible', (
      tester,
    ) async {
      final service = _FakeConnectivityService(ConnectivityStatus.offline);
      addTearDown(service.dispose);
      var childTopPadding = -1.0;

      await tester.pumpWidget(
        _TestApp(
          service: service,
          mediaQueryPadding: const EdgeInsets.only(top: 44),
          child: Builder(
            builder: (context) {
              childTopPadding = MediaQuery.paddingOf(context).top;
              return const SizedBox.expand(child: Text('Library'));
            },
          ),
        ),
      );

      expect(childTopPadding, 0);
    });

    testWidgets('paints the status bar safe area with banner color', (
      tester,
    ) async {
      final service = _FakeConnectivityService(ConnectivityStatus.offline);
      addTearDown(service.dispose);

      await tester.pumpWidget(
        _TestApp(
          service: service,
          mediaQueryPadding: const EdgeInsets.only(top: 44),
        ),
      );

      final bannerBackground = tester.widget<ColoredBox>(
        find.byKey(const ValueKey('offlineBanner')),
      );
      final colors = Theme.of(
        tester.element(find.byType(AppConnectivityBannerHost)),
      ).extension<AppColorsExt>()!;

      expect(bannerBackground.color, colors.warning);
    });
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({
    required this.service,
    this.currentPath = '/',
    this.mediaQueryPadding,
    this.child = const SizedBox.expand(child: Text('Library')),
  });

  final ConnectivityService service;
  final String currentPath;
  final EdgeInsets? mediaQueryPadding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConnectivityScope(
      service: service,
      child: MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              final mediaQuery = MediaQuery.of(context);
              return MediaQuery(
                data: mediaQuery.copyWith(
                  padding: mediaQueryPadding ?? mediaQuery.padding,
                ),
                child: AppConnectivityBannerHost(
                  currentPath: currentPath,
                  child: child,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FakeConnectivityService implements ConnectivityService {
  _FakeConnectivityService(this._status);

  final _controller = StreamController<ConnectivityStatus>.broadcast();
  ConnectivityStatus _status;

  void emit(ConnectivityStatus status) {
    _status = status;
    _controller.add(status);
  }

  @override
  ConnectivityStatus get status => _status;

  @override
  Stream<ConnectivityStatus> get statusStream => _controller.stream;

  @override
  Future<void> refresh() async {}

  @override
  void dispose() {
    unawaited(_controller.close());
  }
}
