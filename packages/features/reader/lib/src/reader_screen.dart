import 'dart:async';

import 'package:article_repository/article_repository.dart';
import 'package:book_repository/book_repository.dart';
import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:highlight_repository/highlight_repository.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:reader_webview/reader_webview.dart';
import 'package:screen_control_service/screen_control_service.dart';
import 'package:shared/shared.dart';

import 'book_custom_css.dart';
import 'reader_appearance_cubit.dart';
import 'reader_appearance_sheet.dart';
import 'reader_bookmark_filter.dart';
import 'reader_bloc.dart';
import 'reader_brightness_cubit.dart';
import 'reader_chrome_actions.dart';
import 'reader_chrome_progress_layout.dart';
import 'reader_image_page_progress_overlay.dart';
import 'reader_color_utils.dart';
import 'reader_device_font_scale.dart';
import 'reader_drawer_messages.dart';
import 'reader_directional_layout.dart';
import 'reader_keep_awake_cubit.dart';
import 'reader_loading_indicator_style.dart';
import 'reader_progress_label.dart';
import 'reader_search_cubit.dart';
import 'reader_selection_cubit.dart';
import 'reader_system_ui_overlay.dart';
import 'reader_tap_action.dart';
import 'reader_tap_zone_hint.dart';
import 'reader_toc_active_index.dart';
import 'reader_ui_cubit.dart';

part 'reader_screen_lifecycle.dart';
part 'reader_screen_content.dart';
part 'reader_screen_chrome.dart';
part 'reader_screen_drawers.dart';
part 'reader_screen_context_panel.dart';

// Text actions are shown only after the WebView reports an actual text
// selection. Image-page formats are filtered in the selection callback so they
// cannot trap the reader chrome with a stale action panel.
bool _selectionActionsVisible(bool hasSelection) => hasSelection;

/// Duration and curve for the reader chrome slide animation.
const _kChromeAnimDuration = Duration(milliseconds: 200);
const _kChromeAnimCurve = Curves.easeOutCubic;
const _kChromeHideAnimCurve = Curves.easeInCubic;
const _kReaderTopChromeHeight = 64.0;
const _kReaderPageBookmarkIndicatorLift = 28.0;
const _kReaderPageBookmarkIndicatorSize = AppIconSize.md;
const _kReaderBrightnessStep = 0.05;
const _kReaderBrightnessEpsilon = 0.0001;
const _kReaderBrightnessChromeWidth = 56.0;
const _kReaderBrightnessChromeHeight = 190.0;
const _kReaderBrightnessChromeDragHeight =
    _kReaderBrightnessChromeHeight - AppSpacing.sm * 2;

const _kReaderTocTileEstimatedHeight = 60.0;
const _traceReaderBuilds = bool.fromEnvironment(
  'READFLEX_TRACE_READER_BUILDS',
);

typedef _ReaderChromeOverlaySnapshot = ({
  bool chromeVisible,
  ReaderOverlay overlay,
});

void _debugTraceReader(String message) {
  if (!_traceReaderBuilds || kReleaseMode) return;
  debugPrint('[reader-trace] $message');
}

double _snapReaderBrightnessButtonValue(double value, double delta) {
  final percent = value * 100;
  final stepPercent = _kReaderBrightnessStep * 100;
  final steppedPercent = delta.isNegative
      ? ((percent - _kReaderBrightnessEpsilon) / stepPercent).floor() *
            stepPercent
      : ((percent + _kReaderBrightnessEpsilon) / stepPercent).ceil() *
            stepPercent;
  return (steppedPercent / 100)
      .clamp(
        ReaderBrightnessCubit.minBrightness,
        ReaderBrightnessCubit.maxBrightness,
      )
      .toDouble();
}

String _readerBrightnessDebugValue(double? value) {
  if (value == null) return 'null';
  return '${(value * 100).round()}% (${value.toStringAsFixed(3)})';
}

String _readerBrightnessLabel(ReaderBrightnessState state) {
  if (!state.usesSystemBrightness) return '${state.percent}%';
  return 'System';
}

final _readerDrawerCloseButtonStyle = IconButton.styleFrom(
  backgroundColor: Colors.transparent,
  disabledBackgroundColor: Colors.transparent,
  hoverColor: Colors.transparent,
  focusColor: Colors.transparent,
  highlightColor: Colors.transparent,
);

double _readerDrawerListBottomPadding(BuildContext context) {
  return MediaQuery.viewInsetsOf(context).bottom +
      MediaQuery.paddingOf(context).bottom +
      AppSpacing.lg;
}

ReaderTapAxis _readerTapAxisForPageTurnStyle(ReaderPageTurnStyle style) {
  return style == ReaderPageTurnStyle.vertical
      ? ReaderTapAxis.vertical
      : ReaderTapAxis.horizontal;
}

/// Full-screen reader for a book (route `/reader/:sourceId`).
///
/// Composition only: wires [ReaderBloc] (source + highlights + position
/// persistence), [ReaderUiCubit] (chrome/drawer/search-highlight state),
/// [ReaderSearchCubit] (book-search state), and [ReaderSelectionCubit]
/// (text selection) around an internal [_ReaderView]. [textActions] follow
/// the plugin contract from `package:shared` and are wired in the
/// composition root.
class ReaderScreen extends StatelessWidget {
  const ReaderScreen({
    required this.sourceId,
    required this.serverPort,
    required this.bookRepository,
    required this.highlightRepository,
    required this.preferencesService,
    required this.screenControlService,
    required this.textActions,
    this.initialSearchHistory = const [],
    this.articleRepository,
    this.initialSource,
    this.initialSourceType = SourceType.book,
    this.onSearchHistoryChanged,
    this.onSourceOpened,
    super.key,
  });

  final String sourceId;
  final int serverPort;
  final BookRepository bookRepository;
  final ArticleRepository? articleRepository;
  final HighlightRepository highlightRepository;
  final PreferencesService preferencesService;
  final ScreenControlService screenControlService;
  final List<TextAction> textActions;
  final List<String> initialSearchHistory;
  final Book? initialSource;
  final SourceType initialSourceType;
  final ValueChanged<List<String>>? onSearchHistoryChanged;
  final VoidCallback? onSourceOpened;

  @override
  Widget build(BuildContext context) {
    debugLogScreenBuild('ReaderScreen(sourceId: $sourceId)');

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => ReaderBloc(
            bookRepository: bookRepository,
            articleRepository: articleRepository,
            highlightRepository: highlightRepository,
            initialSource: initialSource?.id == sourceId ? initialSource : null,
            initialSourceType: initialSourceType,
          )..add(ReaderSourceLoadRequested(sourceId: sourceId)),
        ),
        BlocProvider(create: (_) => ReaderUiCubit()),
        BlocProvider(
          create: (_) => ReaderSearchCubit(
            initialRecentQueries: initialSearchHistory,
            onRecentQueriesChanged: onSearchHistoryChanged,
          ),
        ),
        BlocProvider(create: (_) => ReaderSelectionCubit()),
        BlocProvider(
          create: (_) => ReaderAppearanceCubit(
            preferencesService: preferencesService,
            sourceId: sourceId,
          ),
        ),
        BlocProvider(
          create: (_) => ReaderBrightnessCubit(
            preferencesService: preferencesService,
            screenControlService: screenControlService,
            sourceId: sourceId,
          ),
        ),
        BlocProvider(
          create: (_) => ReaderKeepAwakeCubit(
            screenControlService: screenControlService,
          ),
        ),
      ],
      child: Builder(
        builder: (context) => _ReaderSourceOpenedNotifier(
          onSourceOpened: onSourceOpened,
          child: ReaderBrightnessLifecycleScope(
            cubit: context.read<ReaderBrightnessCubit>(),
            child: ReaderKeepAwakeDriver(
              child: _ReaderView(
                serverPort: serverPort,
                textActions: textActions,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
