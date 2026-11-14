import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'reader_bloc.dart';
import 'reader_highlight_focus_cubit.dart';
import 'reader_surface.dart';
import 'reader_tap_action.dart';
import 'reader_ui_cubit.dart';

/// Turns a tap at ([x], [y]), as fractions of the page surface, into a page
/// turn or a chrome toggle, for any book surface.
void dispatchReaderTap(
  BuildContext context, {
  required double x,
  required double y,
  required ReaderSurface surface,
  required ReaderTapAxis axis,
}) {
  final uiCubit = context.read<ReaderUiCubit>();
  final capabilities = context.read<ReaderBloc>().state.formatCapabilities;
  context.read<ReaderHighlightFocusCubit>().clear();
  final command = readerTapCommandFor(
    x: x,
    y: y,
    chromeVisible: uiCubit.state.chromeVisible,
    isComic: capabilities.allowsPageGesturesWithChrome,
    axis: axis,
  );
  if (command != ReaderTapCommand.toggleChrome) uiCubit.hideChrome();
  switch (command) {
    case ReaderTapCommand.physicalLeftPage:
      surface.pageLeft();
    case ReaderTapCommand.physicalRightPage:
      surface.pageRight();
    case ReaderTapCommand.previousPage:
      surface.prevPage();
    case ReaderTapCommand.nextPage:
      surface.nextPage();
    case ReaderTapCommand.toggleChrome:
      uiCubit.toggleChrome();
  }
}
