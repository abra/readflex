import 'package:article_repository/article_repository.dart';
import 'package:book_repository/book_repository.dart';
import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:highlight_repository/highlight_repository.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:screen_control_service/screen_control_service.dart';
import 'package:shared/shared.dart';

import 'reader_appearance_cubit.dart';
import 'reader_article_progress_cubit.dart';
import 'reader_bloc.dart';
import 'reader_brightness_cubit.dart';
import 'reader_highlight_effect_listener.dart';
import 'reader_highlight_focus_cubit.dart';
import 'reader_image_highlight_cubit.dart';
import 'reader_image_selection_cubit.dart';
import 'reader_keep_awake_cubit.dart';
import 'reader_screen_content.dart';
import 'reader_screen_lifecycle.dart';
import 'reader_search_cubit.dart';
import 'reader_selection_cubit.dart';
import 'reader_selection_tip_cubit.dart';
import 'reader_ui_cubit.dart';

/// Full-screen reader for a library source (route `/reader/:sourceId`).
///
/// Composition only: wires [ReaderBloc] (source + highlights + position
/// persistence), [ReaderUiCubit] (chrome/drawer/search-highlight state),
/// [ReaderSearchCubit] (document-search state), and [ReaderSelectionCubit]
/// (text selection) around an internal [ReaderView]. [textActions] follow
/// the plugin contract from `package:shared` and are wired in the
/// composition root.
class ReaderScreen extends StatelessWidget {
  const ReaderScreen({
    required this.sourceId,
    required this.bookRepository,
    required this.highlightRepository,
    required this.preferencesService,
    required this.screenControlService,
    required this.textActions,
    this.initialSearchHistory = const [],
    this.articleRepository,
    this.initialSource,
    this.onSearchHistoryChanged,
    this.onSourceOpened,
    this.onReadingPositionSaved,
    this.onArticleTitlePressed,
    this.onOpenExternalLink,
    this.initialCfi,
    super.key,
  });

  final String sourceId;
  final BookRepository bookRepository;
  final ArticleRepository? articleRepository;
  final HighlightRepository highlightRepository;
  final PreferencesService preferencesService;
  final ScreenControlService screenControlService;
  final List<TextAction> textActions;
  final List<String> initialSearchHistory;
  final Book? initialSource;
  final ValueChanged<List<String>>? onSearchHistoryChanged;
  final VoidCallback? onSourceOpened;

  /// Called with the saved progress after each reading position write reaches
  /// storage, so the screen below can update while the reader still covers
  /// it.
  final ValueChanged<double>? onReadingPositionSaved;
  final void Function(String url, String title)? onArticleTitlePressed;

  /// Opens a link from a book, article or PDF after the reader confirmed it
  /// in the link sheet: a web page, an email or a phone number.
  final ValueChanged<String>? onOpenExternalLink;

  /// Where to open instead of the saved position: a highlight or a saved
  /// word's anchor. Applied once the document is ready.
  final String? initialCfi;

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
            onReadingPositionSaved: onReadingPositionSaved,
          )..add(ReaderSourceLoadRequested(sourceId: sourceId)),
        ),
        BlocProvider(create: (_) => ReaderUiCubit()),
        BlocProvider(create: (_) => ReaderArticleProgressCubit()),
        BlocProvider(
          create: (_) => ReaderSearchCubit(
            initialRecentQueries: initialSearchHistory,
            onRecentQueriesChanged: onSearchHistoryChanged,
          ),
        ),
        BlocProvider(create: (_) => ReaderSelectionCubit()),
        BlocProvider(create: (_) => ReaderImageSelectionCubit()),
        BlocProvider(
          create: (_) => ReaderImageHighlightCubit(
            highlightRepository: highlightRepository,
          ),
        ),
        BlocProvider(create: (_) => ReaderHighlightFocusCubit()),
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
        BlocProvider(
          create: (_) => ReaderSelectionTipCubit(
            preferencesService: preferencesService,
          ),
        ),
      ],
      child: Builder(
        builder: (context) => ReaderSourceOpenedNotifier(
          onSourceOpened: onSourceOpened,
          child: ReaderBrightnessLifecycleScope(
            cubit: context.read<ReaderBrightnessCubit>(),
            child: ReaderHighlightEffectListener(
              child: ReaderKeepAwakeDriver(
                child: ReaderView(
                  textActions: textActions,
                  initialCfi: initialCfi,
                  onRetry: () => context.read<ReaderBloc>().add(
                    ReaderSourceLoadRequested(sourceId: sourceId),
                  ),
                  onArticleTitlePressed: onArticleTitlePressed,
                  onOpenExternalLink: onOpenExternalLink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
