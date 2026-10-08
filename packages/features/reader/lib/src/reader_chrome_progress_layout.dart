import 'dart:math' as math;

import 'package:component_library/component_library.dart';
import 'package:flutter/painting.dart';

/// Gap between the chapter (or time) label and the page label on the line
/// under the slider.
const readerProgressLabelGap = AppSpacing.md;

/// The slider's overlay radius, which is also how far its track is inset
/// from the slider's box. The labels under it take the same inset, so they
/// start and end with the track.
const readerProgressTrackInset = 14.0;

const _referenceFontSize = 14.0;
const _stackedTextScale = 1.3;

/// The page label is short and numeric in every locale, so it keeps its
/// natural width, bounded only by the row: its digits never truncate. The
/// chapter label takes the rest and truncates first.
double readerProgressEndLabelMaxWidth(double rowWidth) =>
    math.max(0, rowWidth - readerProgressLabelGap);

/// Above 130% text the labels under the slider take a line each: the chapter
/// keeps two lines and the page counter never loses digits.
bool readerProgressLabelsStack(TextScaler textScaler) =>
    textScaler.scale(_referenceFontSize) >
    _referenceFontSize * _stackedTextScale;
