import 'dart:math' as math;

import 'package:cupertino_ui/cupertino_ui.dart' as cupertino;
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' as material;

import 'theme/extensions/build_context_ext.dart';
import 'theme/tokens/app_sizes.dart';
import 'theme/tokens/app_spacing.dart';

enum AppFloatingActionButtonAnimator { none }

/// Layout information independent of either platform scaffold.
@immutable
class AppScaffoldGeometry {
  const AppScaffoldGeometry({
    required this.scaffoldSize,
    required this.floatingActionButtonSize,
    required this.contentBottom,
    required this.viewPadding,
    required this.viewInsets,
    required this.textDirection,
    this.snackBarSize = Size.zero,
    this.bottomSheetSize = Size.zero,
  });
  final Size scaffoldSize;
  final Size floatingActionButtonSize;
  final double contentBottom;
  final EdgeInsets viewPadding;
  final EdgeInsets viewInsets;
  final TextDirection textDirection;
  final Size snackBarSize;
  final Size bottomSheetSize;

  AppScaffoldGeometry copyWith({EdgeInsets? viewPadding}) =>
      AppScaffoldGeometry(
        scaffoldSize: scaffoldSize,
        floatingActionButtonSize: floatingActionButtonSize,
        contentBottom: contentBottom,
        viewPadding: viewPadding ?? this.viewPadding,
        viewInsets: viewInsets,
        textDirection: textDirection,
        snackBarSize: snackBarSize,
        bottomSheetSize: bottomSheetSize,
      );
}

abstract class AppFloatingActionButtonLocation {
  const AppFloatingActionButtonLocation();
  static const centerFloat = _AppFloatLocation(centered: true);
  static const endFloat = _AppFloatLocation(centered: false);
  Offset getOffset(AppScaffoldGeometry geometry);
}

class _AppFloatLocation extends AppFloatingActionButtonLocation {
  const _AppFloatLocation({required this.centered});
  final bool centered;

  @override
  Offset getOffset(AppScaffoldGeometry geometry) {
    final size = geometry.floatingActionButtonSize;
    final viewport = geometry.scaffoldSize;
    final obscuredBottom = viewport.height - geometry.contentBottom;
    final safeMargin = math.max(
      AppSpacing.lg,
      geometry.viewPadding.bottom - obscuredBottom + AppSpacing.lg,
    );
    final x = centered
        ? (viewport.width - size.width) / 2
        : geometry.textDirection == TextDirection.rtl
        ? math.max(geometry.viewInsets.left, geometry.viewPadding.left) +
              AppSpacing.lg
        : viewport.width -
              math.max(geometry.viewInsets.right, geometry.viewPadding.right) -
              size.width -
              AppSpacing.lg;
    var y = geometry.contentBottom - size.height - safeMargin;
    if (geometry.snackBarSize.height > 0) {
      y = math.min(
        y,
        geometry.contentBottom -
            geometry.snackBarSize.height -
            size.height -
            AppSpacing.lg,
      );
    }
    if (geometry.bottomSheetSize.height > 0) {
      y = math.min(
        y,
        geometry.contentBottom -
            geometry.bottomSheetSize.height -
            size.height / 2,
      );
    }
    return Offset(x, y);
  }
}

/// Platform page chrome with one body/state tree and shared floating geometry.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    this.appBar,
    this.body,
    this.backgroundColor,
    this.floatingActionButton,
    this.floatingActionButtonLocation =
        AppFloatingActionButtonLocation.endFloat,
    this.floatingActionButtonAnimator = AppFloatingActionButtonAnimator.none,
    this.bottomNavigationBar,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
    this.resizeToAvoidBottomInset = true,
    super.key,
  });

  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Color? backgroundColor;
  final Widget? floatingActionButton;
  final AppFloatingActionButtonLocation floatingActionButtonLocation;
  final AppFloatingActionButtonAnimator floatingActionButtonAnimator;
  final Widget? bottomNavigationBar;
  final bool extendBody;
  final bool extendBodyBehindAppBar;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    if (!context.isCupertino) {
      return material.Scaffold(
        appBar: appBar,
        body: body,
        backgroundColor: backgroundColor,
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: _MaterialFloatingLocation(
          floatingActionButtonLocation,
        ),
        floatingActionButtonAnimator:
            material.FloatingActionButtonAnimator.noAnimation,
        bottomNavigationBar: bottomNavigationBar,
        extendBody: extendBody,
        extendBodyBehindAppBar: extendBodyBehindAppBar,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      );
    }
    return cupertino.CupertinoPageScaffold(
      backgroundColor: backgroundColor ?? context.appTheme.backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      navigationBar: appBar == null
          ? null
          : _CupertinoNavigationAdapter(
              obstructs: !extendBodyBehindAppBar,
              child: appBar!,
            ),
      child: _CupertinoScaffoldBody(
        originalMedia: MediaQuery.of(context),
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: floatingActionButtonLocation,
        bottomNavigationBar: bottomNavigationBar,
        extendBody: extendBody,
        child: body ?? const SizedBox.shrink(),
      ),
    );
  }
}

class _MaterialFloatingLocation extends material.FloatingActionButtonLocation {
  const _MaterialFloatingLocation(this.location);
  final AppFloatingActionButtonLocation location;
  @override
  Offset getOffset(material.ScaffoldPrelayoutGeometry geometry) =>
      location.getOffset(
        AppScaffoldGeometry(
          scaffoldSize: geometry.scaffoldSize,
          floatingActionButtonSize: geometry.floatingActionButtonSize,
          contentBottom: geometry.contentBottom,
          viewPadding: geometry.minViewPadding,
          viewInsets: geometry.minInsets,
          textDirection: geometry.textDirection,
          snackBarSize: geometry.snackBarSize,
          bottomSheetSize: geometry.bottomSheetSize,
        ),
      );
}

class _CupertinoNavigationAdapter extends StatelessWidget
    implements cupertino.ObstructingPreferredSizeWidget {
  const _CupertinoNavigationAdapter({
    required this.child,
    required this.obstructs,
  });
  final PreferredSizeWidget child;
  final bool obstructs;
  @override
  Size get preferredSize => child is AppNavigationBar
      ? const Size.fromHeight(cupertino.kMinInteractiveDimensionCupertino)
      : child.preferredSize;
  @override
  bool shouldFullyObstruct(BuildContext context) => obstructs;
  @override
  Widget build(BuildContext context) => child;
}

enum _CupertinoSlot { body, footer, floating }

class _CupertinoScaffoldBody extends StatelessWidget {
  const _CupertinoScaffoldBody({
    required this.originalMedia,
    required this.resizeToAvoidBottomInset,
    required this.floatingActionButton,
    required this.floatingActionButtonLocation,
    required this.bottomNavigationBar,
    required this.extendBody,
    required this.child,
  });
  final MediaQueryData originalMedia;
  final bool resizeToAvoidBottomInset;
  final Widget? floatingActionButton;
  final AppFloatingActionButtonLocation floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final bool extendBody;
  final Widget child;

  @override
  Widget build(BuildContext context) => CustomMultiChildLayout(
    delegate: _CupertinoScaffoldLayout(
      media: originalMedia,
      keyboardConsumed: resizeToAvoidBottomInset,
      location: floatingActionButtonLocation,
      direction: Directionality.of(context),
      extendBody: extendBody,
    ),
    children: [
      LayoutId(
        id: _CupertinoSlot.body,
        child: MediaQuery.removePadding(
          context: context,
          removeBottom: bottomNavigationBar != null && !extendBody,
          child: child,
        ),
      ),
      if (bottomNavigationBar != null)
        LayoutId(id: _CupertinoSlot.footer, child: bottomNavigationBar!),
      if (floatingActionButton != null)
        LayoutId(
          id: _CupertinoSlot.floating,
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            removeBottom: true,
            child: floatingActionButton!,
          ),
        ),
    ],
  );
}

class _CupertinoScaffoldLayout extends MultiChildLayoutDelegate {
  _CupertinoScaffoldLayout({
    required this.media,
    required this.keyboardConsumed,
    required this.location,
    required this.direction,
    required this.extendBody,
  });
  final MediaQueryData media;
  final bool keyboardConsumed;
  final AppFloatingActionButtonLocation location;
  final TextDirection direction;
  final bool extendBody;

  @override
  void performLayout(Size size) {
    final loose = BoxConstraints(maxWidth: size.width, maxHeight: size.height);
    var footerHeight = 0.0;
    if (hasChild(_CupertinoSlot.footer)) {
      footerHeight = layoutChild(
        _CupertinoSlot.footer,
        loose.tighten(width: size.width),
      ).height;
      positionChild(
        _CupertinoSlot.footer,
        Offset(0, size.height - footerHeight),
      );
    }
    layoutChild(
      _CupertinoSlot.body,
      BoxConstraints(
        maxWidth: size.width,
        maxHeight: extendBody
            ? size.height
            : math.max(0, size.height - footerHeight),
      ),
    );
    positionChild(_CupertinoSlot.body, Offset.zero);
    if (hasChild(_CupertinoSlot.floating)) {
      final floatingSize = layoutChild(_CupertinoSlot.floating, loose);
      final consumedKeyboard = keyboardConsumed ? media.viewInsets.bottom : 0.0;
      final offset = location.getOffset(
        AppScaffoldGeometry(
          scaffoldSize: Size(size.width, size.height + consumedKeyboard),
          floatingActionButtonSize: floatingSize,
          contentBottom: size.height - footerHeight,
          viewPadding: media.viewPadding,
          viewInsets: media.viewInsets,
          textDirection: direction,
        ),
      );
      positionChild(
        _CupertinoSlot.floating,
        Offset(
          offset.dx.clamp(0, math.max(0, size.width - floatingSize.width)),
          offset.dy.clamp(0, math.max(0, size.height - floatingSize.height)),
        ),
      );
    }
  }

  @override
  bool shouldRelayout(_CupertinoScaffoldLayout oldDelegate) =>
      oldDelegate.media != media ||
      oldDelegate.keyboardConsumed != keyboardConsumed ||
      oldDelegate.location != location ||
      oldDelegate.direction != direction ||
      oldDelegate.extendBody != extendBody;
}

/// Shared navigation contract, rendered using the platform's navigation bar.
class AppNavigationBar extends StatelessWidget implements PreferredSizeWidget {
  const AppNavigationBar({
    this.title,
    this.leading,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.excludeHeaderSemantics = false,
    this.titleSpacing,
    this.backgroundColor,
    super.key,
  });
  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;
  final bool excludeHeaderSemantics;
  final double? titleSpacing;
  final Color? backgroundColor;

  @override
  Size get preferredSize => const Size.fromHeight(AppSizes.appBarHeight);

  @override
  Widget build(BuildContext context) {
    if (context.isCupertino) {
      return cupertino.CupertinoNavigationBar(
        leading: leading,
        middle: title,
        trailing: actions == null
            ? null
            : Row(mainAxisSize: MainAxisSize.min, children: actions!),
        automaticallyImplyLeading: automaticallyImplyLeading,
        automaticallyImplyMiddle: false,
        backgroundColor: backgroundColor ?? context.appTheme.backgroundColor,
        enableBackgroundFilterBlur: false,
      );
    }
    return material.AppBar(
      title: title,
      leading: leading,
      actions: actions,
      automaticallyImplyLeading: automaticallyImplyLeading,
      excludeHeaderSemantics: excludeHeaderSemantics,
      titleSpacing: titleSpacing,
      backgroundColor: backgroundColor,
    );
  }
}
