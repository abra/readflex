import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS WebView override removes modern system edit menus', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      pubspec,
      contains('path: third_party/flutter_inappwebview_ios'),
    );

    final source = File(
      'third_party/flutter_inappwebview_ios/ios/Classes/'
      'InAppWebView/InAppWebView.swift',
    ).readAsStringSync();
    final buildMenuStart = source.indexOf(
      'public override func buildMenu(with builder: UIMenuBuilder)',
    );
    final superBuildMenu = source.indexOf(
      'super.buildMenu(with: builder)',
      buildMenuStart,
    );
    final removeEditMenu = source.indexOf(
      'builder.remove(menu: .standardEdit)',
      buildMenuStart,
    );

    expect(buildMenuStart, greaterThanOrEqualTo(0));
    expect(superBuildMenu, greaterThan(buildMenuStart));
    expect(removeEditMenu, greaterThan(superBuildMenu));
    expect(source, contains('builder.remove(menu: .share)'));
    expect(source, contains('builder.remove(menu: .lookup)'));
    expect(
      source,
      contains('if settings?.disableContextMenu == true {'),
    );
    expect(source, contains('dismissSystemEditMenu()'));
    expect(source, contains(r'$0 as? UIEditMenuInteraction'));
    expect(source, contains(r'$0.dismissMenu()'));
    expect(source, contains('readflexEditMenuInteractions()'));
    expect(source, contains('pendingViews.append(contentsOf: view.subviews)'));
    expect(source, contains('[reader-context-menu-native] buildMenu'));
    expect(
      source,
      contains('[reader-context-menu-native] willPresentEditMenu'),
    );
  });
}
