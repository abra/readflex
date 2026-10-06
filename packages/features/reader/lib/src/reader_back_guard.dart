import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'reader_back_navigation.dart';
import 'reader_highlight_focus_cubit.dart';
import 'reader_search_cubit.dart';
import 'reader_ui_cubit.dart';

/// Routes system Back to the topmost reader overlay; the route itself only
/// pops once nothing is layered over the page.
class ReaderBackGuard extends StatelessWidget {
  const ReaderBackGuard({
    required this.onCloseSearchPanel,
    required this.onCloseTocDrawer,
    required this.onDismissHighlightPopup,
    required this.onEndSearch,
    required this.child,
    super.key,
  });

  final VoidCallback onCloseSearchPanel;
  final VoidCallback onCloseTocDrawer;
  final VoidCallback onDismissHighlightPopup;
  final VoidCallback onEndSearch;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final overlay = context.select<ReaderUiCubit, ReaderOverlay>(
      (c) => c.state.overlay,
    );
    final highlightPopupVisible = context
        .select<ReaderHighlightFocusCubit, bool>((c) => c.state.hasHighlight);
    final searchNavigating = context.select<ReaderSearchCubit, bool>(
      (c) => c.state.isNavigating,
    );
    final target = readerBackTargetFor(
      overlay: overlay,
      highlightPopupVisible: highlightPopupVisible,
      searchNavigating: searchNavigating,
    );

    return PopScope(
      canPop: target == ReaderBackTarget.route,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        switch (target) {
          case ReaderBackTarget.searchPanel:
            onCloseSearchPanel();
          case ReaderBackTarget.tocDrawer:
            onCloseTocDrawer();
          case ReaderBackTarget.highlightPopup:
            onDismissHighlightPopup();
          case ReaderBackTarget.searchNavigation:
            onEndSearch();
          case ReaderBackTarget.route:
            break;
        }
      },
      child: child,
    );
  }
}
