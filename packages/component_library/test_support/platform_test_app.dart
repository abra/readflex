import 'package:component_library/component_library.dart';
import 'package:cupertino_ui/cupertino_ui.dart' as cupertino;
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' as material;

/// A real platform app host for feature contracts, without app routing or DI.
class PlatformTestApp extends StatelessWidget {
  const PlatformTestApp({
    required this.platform,
    required this.home,
    this.brightness = Brightness.light,
    this.locale = const Locale('en'),
    this.supportedLocales = const [Locale('en')],
    this.localizationsDelegates = const [],
    this.textScale = 1,
    super.key,
  });

  final TargetPlatform platform;
  final Widget home;
  final Brightness brightness;
  final Locale locale;
  final Iterable<Locale> supportedLocales;
  final Iterable<LocalizationsDelegate<dynamic>> localizationsDelegates;
  final double textScale;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.forPlatform(platform, brightness);
    final appHome = AppScaffold(body: home);
    if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
      return cupertino.CupertinoApp(
        theme: AppTheme.cupertino(theme),
        locale: locale,
        supportedLocales: supportedLocales,
        localizationsDelegates: localizationsDelegates,
        builder: (context, child) => AppPlatformTheme(
          platform: platform,
          brightness: brightness,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
        ),
        home: appHome,
      );
    }
    return material.MaterialApp(
      theme: theme,
      locale: locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: localizationsDelegates,
      builder: (context, child) => AppPlatformTheme(
        platform: platform,
        brightness: brightness,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
      ),
      home: appHome,
    );
  }
}
