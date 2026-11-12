import 'package:component_library/component_library.dart';
import 'package:cupertino_ui/cupertino_ui.dart' as cupertino;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' as material;
import 'package:readflex_localizations/readflex_localizations.dart';

/// Root platform application. Services and feature state remain outside it.
class ReadflexPlatformApp extends StatelessWidget {
  const ReadflexPlatformApp({
    this.routerConfig,
    this.home,
    this.locale,
    this.brightness,
    this.builder,
    super.key,
  }) : assert((routerConfig == null) != (home == null));

  final RouterConfig<Object>? routerConfig;
  final Widget? home;
  final Locale? locale;

  /// Null follows the operating system.
  final Brightness? brightness;
  final TransitionBuilder? builder;

  @override
  Widget build(BuildContext context) {
    final platform = defaultTargetPlatform;
    final effectiveBrightness =
        brightness ??
        MediaQuery.maybePlatformBrightnessOf(context) ??
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final adapter = AppTheme.forPlatform(platform, effectiveBrightness);
    if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
      if (routerConfig != null) {
        return cupertino.CupertinoApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.cupertino(adapter),
          locale: locale,
          supportedLocales: ReadflexSupportedLocales.locales,
          localizationsDelegates: readflexLocalizationsDelegates,
          routerConfig: routerConfig,
          builder: (context, child) => _PlatformBody(
            platform: platform,
            brightness: effectiveBrightness,
            builder: builder,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      }
      return cupertino.CupertinoApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.cupertino(adapter),
        locale: locale,
        supportedLocales: ReadflexSupportedLocales.locales,
        localizationsDelegates: readflexLocalizationsDelegates,
        home: home,
        builder: (context, child) => _PlatformBody(
          platform: platform,
          brightness: effectiveBrightness,
          builder: builder,
          child: child ?? const SizedBox.shrink(),
        ),
      );
    }
    if (routerConfig != null) {
      return material.MaterialApp.router(
        debugShowCheckedModeBanner: false,
        locale: locale,
        supportedLocales: ReadflexSupportedLocales.locales,
        localizationsDelegates: readflexLocalizationsDelegates,
        theme: adapter,
        themeMode: material.ThemeMode.light,
        routerConfig: routerConfig,
        builder: (context, child) => _PlatformBody(
          platform: platform,
          brightness: effectiveBrightness,
          builder: builder,
          child: child ?? const SizedBox.shrink(),
        ),
      );
    }
    return material.MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: ReadflexSupportedLocales.locales,
      localizationsDelegates: readflexLocalizationsDelegates,
      theme: adapter,
      themeMode: material.ThemeMode.light,
      home: home,
      builder: (context, child) => _PlatformBody(
        platform: platform,
        brightness: effectiveBrightness,
        builder: builder,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}

class _PlatformBody extends StatelessWidget {
  const _PlatformBody({
    required this.platform,
    required this.brightness,
    required this.child,
    required this.builder,
  });
  final TargetPlatform platform;
  final Brightness brightness;
  final Widget child;
  final TransitionBuilder? builder;

  @override
  Widget build(BuildContext context) => AppPlatformTheme(
    platform: platform,
    brightness: brightness,
    inheritMaterialTheme: platform == TargetPlatform.android,
    // toastification still reads the legacy inherited theme/localizations.
    // ignore: deprecated_member_use
    child: material.MaterialUiCompatibilityBridge(
      child: Builder(
        builder: (context) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: appSystemUiOverlayStyle(
            brightness: brightness,
            backgroundColor: context.appTheme.backgroundColor,
          ),
          child: builder == null ? child : builder!(context, child),
        ),
      ),
    ),
  );
}
