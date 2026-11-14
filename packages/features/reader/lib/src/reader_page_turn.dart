import 'package:flutter/widgets.dart';
import 'package:pagecraft/pagecraft.dart';
import 'package:preferences_service/preferences_service.dart';

import 'reader_tap_action.dart';

ReaderTapAxis readerTapAxisForPageTurnStyle(ReaderPageTurnStyle style) {
  return style == ReaderPageTurnStyle.vertical
      ? ReaderTapAxis.vertical
      : ReaderTapAxis.horizontal;
}

/// The axis native fixed-layout pages turn along for [style].
Axis readerPageAxis(ReaderPageTurnStyle style) =>
    style == ReaderPageTurnStyle.vertical ? Axis.vertical : Axis.horizontal;

PageTurnAnimation readerPageTurnAnimation(ReaderPageAnimation animation) =>
    switch (animation) {
      ReaderPageAnimation.slide => PageTurnAnimation.slide,
      ReaderPageAnimation.cover => PageTurnAnimation.cover,
    };
