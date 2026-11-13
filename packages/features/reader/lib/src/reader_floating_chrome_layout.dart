import 'dart:math' as math;

import 'package:component_library/component_library.dart';
import 'package:flutter/widgets.dart';

/// Maximum dock column, including its two 16dp outer gutters.
const readerChromeDockMaxWidth = 560.0;

/// Three full-size targets with the existing pill's end padding and gaps.
const readerBrightnessChromeLength =
    AppSizes.buttonHeight * 3 + AppSpacing.sm * 2 + AppSpacing.md * 2;
const readerChromeProgressTrackHeight = 3.0;

/// Lays out the floating controls together without resizing the reading page.
/// Children keep their state while visibility animates inside each surface.
class ReaderFloatingChromeLayout extends StatelessWidget {
  const ReaderFloatingChromeLayout({
    required this.brightness,
    this.dock,
    this.top,
    this.progress,
    super.key,
  });

  final Widget brightness;
  final Widget? dock;
  final Widget? top;

  /// Article progress whose height includes its animated title padding.
  final Widget? progress;

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: CustomMultiChildLayout(
      delegate: _ReaderFloatingChromeDelegate(
        safePadding: MediaQuery.paddingOf(context),
        dockBottomInset: appBottomSafeInset(context),
        trailingInset: AppWindowSize.isWide(context)
            ? AppSpacing.sm
            : AppSpacing.lg,
        textDirection: Directionality.of(context),
        brightnessWidth: AppWindowSize.isWide(context)
            ? AppSizes.buttonHeight
            : AppSizes.buttonHeight + AppSpacing.xs * 2,
      ),
      children: [
        if (top != null) LayoutId(id: _ChromeSlot.top, child: top!),
        if (progress != null)
          LayoutId(id: _ChromeSlot.progress, child: progress!),
        LayoutId(id: _ChromeSlot.brightness, child: brightness),
        if (dock != null) LayoutId(id: _ChromeSlot.dock, child: dock!),
      ],
    ),
  );
}

enum _ChromeSlot { top, progress, brightness, dock }

class _ReaderFloatingChromeDelegate extends MultiChildLayoutDelegate {
  _ReaderFloatingChromeDelegate({
    required this.safePadding,
    required this.dockBottomInset,
    required this.trailingInset,
    required this.textDirection,
    required this.brightnessWidth,
  });

  final EdgeInsets safePadding;
  final double dockBottomInset;
  final double trailingInset;
  final TextDirection textDirection;
  final double brightnessWidth;

  @override
  void performLayout(Size size) {
    Rect? dockBounds;
    if (hasChild(_ChromeSlot.dock)) {
      final availableWidth = math.max(0.0, size.width - safePadding.horizontal);
      final width = math.max(
        0.0,
        math.min(availableWidth, readerChromeDockMaxWidth) - AppSpacing.lg * 2,
      );
      final dockLeft = safePadding.left + (availableWidth - width) / 2;
      final railLeft = textDirection == TextDirection.rtl
          ? safePadding.left + trailingInset
          : size.width - safePadding.right - trailingInset - brightnessWidth;
      final overlapsRail =
          railLeft < dockLeft + width + AppSpacing.sm &&
          railLeft + brightnessWidth > dockLeft - AppSpacing.sm;
      // A short, narrow window must leave room for all three brightness
      // targets. The dock receives the remaining height in this same pass.
      final dockMaxHeight = overlapsRail
          ? math.max(
              0.0,
              size.height -
                  safePadding.top -
                  AppSizes.buttonHeight -
                  AppSpacing.sm -
                  AppSpacing.xs,
            )
          : size.height;
      final dockSize = layoutChild(
        _ChromeSlot.dock,
        BoxConstraints.tightFor(width: width)
            .copyWith(maxHeight: dockMaxHeight),
      );
      final offset = Offset(
        dockLeft,
        size.height - dockSize.height,
      );
      positionChild(_ChromeSlot.dock, offset);
      dockBounds = offset & Size(width, dockSize.height - dockBottomInset);
    }

    final railLeft = textDirection == TextDirection.rtl
        ? safePadding.left + trailingInset
        : size.width - safePadding.right - trailingInset - brightnessWidth;
    final railOverlapsDock =
        dockBounds != null &&
        railLeft < dockBounds.right + AppSpacing.sm &&
        railLeft + brightnessWidth > dockBounds.left - AppSpacing.sm;
    final spaceAboveDock = dockBounds == null
        ? size.height - safePadding.vertical
        : dockBounds.top - AppSpacing.sm - safePadding.top;
    final compact =
        railOverlapsDock && spaceAboveDock < readerBrightnessChromeLength;
    final brightness = layoutChild(
      _ChromeSlot.brightness,
      BoxConstraints.loose(size).copyWith(
        maxHeight: compact ? AppSizes.buttonHeight : size.height,
      ),
    );
    final left = textDirection == TextDirection.rtl
        ? safePadding.left + trailingInset
        : size.width - safePadding.right - trailingInset - brightness.width;
    var top = compact
        ? safePadding.top + AppSpacing.xs
        : (size.height - brightness.height) / 2;
    // Wide docks leave an unobstructed side rail: retain the centre there.
    if (!compact && railOverlapsDock) {
      top = math.max(
        safePadding.top,
        math.min(top, dockBounds.top - AppSpacing.sm - brightness.height),
      );
    }
    positionChild(_ChromeSlot.brightness, Offset(left, top));

    if (hasChild(_ChromeSlot.top)) {
      // A short window shares its top row; text never sits behind the pill.
      final reservedWidth = compact
          ? brightness.width +
                trailingInset +
                AppSpacing.sm +
                (textDirection == TextDirection.rtl
                    ? safePadding.left
                    : safePadding.right)
          : 0.0;
      layoutChild(
        _ChromeSlot.top,
        BoxConstraints.tightFor(width: size.width - reservedWidth)
            .copyWith(maxHeight: size.height),
      );
      positionChild(
        _ChromeSlot.top,
        Offset(
          textDirection == TextDirection.rtl ? reservedWidth : 0,
          compact ? AppSpacing.xs : 0,
        ),
      );
    }

    if (hasChild(_ChromeSlot.progress)) {
      final progressSize = layoutChild(
        _ChromeSlot.progress,
        BoxConstraints.tightFor(width: size.width - safePadding.horizontal)
            .copyWith(maxHeight: size.height),
      );
      // Padding animates with title visibility; retain that same interpolation
      // when the compact row also needs its safe-edge gutter.
      final titleFraction =
          ((progressSize.height - readerChromeProgressTrackHeight) /
                  AppSizes.buttonHeight)
              .clamp(0.0, 1.0);
      positionChild(
        _ChromeSlot.progress,
        Offset(
          safePadding.left,
          safePadding.top + (compact ? AppSpacing.xs * titleFraction : 0),
        ),
      );
    }
  }

  @override
  bool shouldRelayout(_ReaderFloatingChromeDelegate oldDelegate) =>
      safePadding != oldDelegate.safePadding ||
      dockBottomInset != oldDelegate.dockBottomInset ||
      trailingInset != oldDelegate.trailingInset ||
      brightnessWidth != oldDelegate.brightnessWidth ||
      textDirection != oldDelegate.textDirection;
}
