import 'package:component_library/component_library.dart';
import 'package:connectivity_service/connectivity_service.dart'
    show ConnectivityScope, ConnectivityStatus;
import 'package:flutter/material.dart';

const _offlineBannerMessage = 'No internet connection';
const _offlineBannerAnimationDuration = Duration(milliseconds: 160);

/// App-level banner that reports offline state without coupling features to
/// connectivity infrastructure.
class AppConnectivityBannerHost extends StatelessWidget {
  const AppConnectivityBannerHost({
    required this.child,
    this.currentPath = '/',
    super.key,
  });

  final Widget child;
  final String currentPath;

  @override
  Widget build(BuildContext context) {
    final isOffline =
        ConnectivityScope.of(context) == ConnectivityStatus.offline;
    final showBanner = isOffline && !_isReaderPath(currentPath);
    final colors = context.appColors;

    return Column(
      children: [
        AnimatedSwitcher(
          duration: _offlineBannerAnimationDuration,
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: showBanner
              ? ColoredBox(
                  key: ValueKey('offlineBanner'),
                  color: colors.warning,
                  child: const SafeArea(
                    left: false,
                    right: false,
                    bottom: false,
                    child: OfflineBanner(message: _offlineBannerMessage),
                  ),
                )
              : const SizedBox.shrink(
                  key: ValueKey('offlineBannerHidden'),
                ),
        ),
        Expanded(
          child: showBanner
              ? MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: child,
                )
              : child,
        ),
      ],
    );
  }

  bool _isReaderPath(String path) =>
      path == '/reader' || path.startsWith('/reader/');
}
