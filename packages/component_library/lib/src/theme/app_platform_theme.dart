import 'package:cupertino_ui/cupertino_ui.dart' as cupertino;
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' as material;

import 'app_theme.dart';
import 'app_theme_scope.dart';

/// Semantic theme with private platform adapters for selection/third-party UI.
class AppPlatformTheme extends StatelessWidget {
  const AppPlatformTheme({
    required this.platform,
    required this.brightness,
    required this.child,
    this.inheritMaterialTheme = false,
    super.key,
  });
  final TargetPlatform platform;
  final Brightness brightness;
  final Widget child;

  /// Android app roots inherit MaterialApp's animated theme. Standalone
  /// hosts keep the explicit platform/brightness adapter by default.
  final bool inheritMaterialTheme;

  @override
  Widget build(BuildContext context) {
    if (inheritMaterialTheme && platform == TargetPlatform.android) {
      return _PlatformThemeBody(
        adapter: material.Theme.of(context),
        child: child,
      );
    }
    final adapter = AppTheme.forPlatform(platform, brightness);
    // Material localizes text geometry for the current script below this theme.
    return material.Theme(
      data: adapter,
      child: _PlatformThemeBody(adapter: adapter, child: child),
    );
  }
}

class _PlatformThemeBody extends StatelessWidget {
  const _PlatformThemeBody({required this.adapter, required this.child});
  final material.ThemeData adapter;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isCupertino =
        adapter.platform == TargetPlatform.iOS ||
        adapter.platform == TargetPlatform.macOS;
    final data = AppTheme.dataFor(
      isCupertino ? adapter : material.Theme.of(context),
    );
    Widget content = AppThemeScope(
      data: data,
      child: DefaultTextStyle(
        style: data.text.bodyLarge,
        child: IconTheme(
          data: data.isCupertino
              ? IconThemeData(color: data.colors.onSurface, size: 24)
              : material.Theme.of(context).iconTheme,
          child: DefaultSelectionStyle(
            selectionColor: data.selectionHandleColor.withValues(
              alpha: data.isCupertino ? .2 : .4,
            ),
            cursorColor: data.selectionHandleColor,
            child: child,
          ),
        ),
      ),
    );
    if (data.isCupertino) {
      content = cupertino.CupertinoTheme(
        data: AppTheme.cupertino(adapter),
        child: content,
      );
    }
    // Pagecraft's adaptive selection region and legacy dependencies still
    // consume Material theme data; the visible platform controls own their UI.
    return content;
  }
}
