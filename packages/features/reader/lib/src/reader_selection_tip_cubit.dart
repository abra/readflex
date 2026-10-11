import 'dart:async';

import 'package:domain_models/domain_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:preferences_service/preferences_service.dart';

/// Where the one-time "Press and hold a word" tip is in this reader session.
enum ReaderSelectionTipPhase {
  /// Not shown yet; it appears once a text page is on screen.
  waiting,

  /// On screen.
  visible,

  /// Gone for this session: hidden after an interaction, dismissed for good,
  /// or not due at all.
  done,
}

/// Teaches text selection, the way into Highlight, Copy, Translate and
/// Define, with a tip at the bottom of the reader.
///
/// The rules follow common tip guidance (Apple's TipKit):
/// - it appears at most once per reader session, and in at most [maxShows]
///   sessions;
/// - "Got it" or any text selection ends it for good, since the reader then
///   knows the gesture;
/// - turning a page or opening the reader's controls only hides it until the
///   next session, so it never sits over the page while someone reads.
///
/// [PreferencesService] stores what happened; this cubit owns the policy.
/// One cubit lives per [ReaderScreen] route.
class ReaderSelectionTipCubit extends Cubit<ReaderSelectionTipPhase> {
  ReaderSelectionTipCubit({required PreferencesService preferencesService})
    : _preferences = preferencesService,
      super(_initialPhase(preferencesService.current));

  /// Sessions after which the tip stops appearing, acknowledged or not.
  static const maxShows = 3;

  final PreferencesService _preferences;

  static ReaderSelectionTipPhase _initialPhase(Preferences preferences) =>
      preferences.readerSelectionTipDismissed ||
          preferences.readerSelectionTipShowCount >= maxShows
      ? ReaderSelectionTipPhase.done
      : ReaderSelectionTipPhase.waiting;

  /// A text page is on screen with nothing over it: shows the tip if this
  /// session has not shown it, and counts the show.
  void showIfDue() {
    if (state != ReaderSelectionTipPhase.waiting) return;
    emit(ReaderSelectionTipPhase.visible);
    _persist(
      (preferences) => preferences.copyWith(
        readerSelectionTipShowCount:
            preferences.readerSelectionTipShowCount + 1,
      ),
    );
  }

  /// The reader turned a page or opened controls: hides a visible tip until
  /// the next session. Before the tip appeared this does nothing, so a tap
  /// while the page loads does not use up the session.
  void hideForSession() {
    if (state != ReaderSelectionTipPhase.visible) return;
    emit(ReaderSelectionTipPhase.done);
  }

  /// "Got it", or the reader selected text: the tip never appears again.
  void dismissForever() {
    if (state != ReaderSelectionTipPhase.done) {
      emit(ReaderSelectionTipPhase.done);
    }
    if (_preferences.current.readerSelectionTipDismissed) return;
    _persist(
      (preferences) => preferences.copyWith(readerSelectionTipDismissed: true),
    );
  }

  void _persist(Preferences Function(Preferences) transform) {
    // PreferencesService applies the change at once and only fails here when
    // it is already disposed; the tip state above stands either way.
    unawaited(
      _preferences.update(transform).catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        if (!isClosed) addError(error, stackTrace);
      }),
    );
  }
}

/// Whether the reader can select text in a source, so the tip has something
/// to teach: articles and reflowable books, PDFs only with a text layer,
/// never comics.
bool readerSupportsSelectionTip({
  required SourceType sourceType,
  required BookFormat? format,
  required bool? hasSearchableText,
}) {
  if (sourceType == SourceType.article) return true;
  return switch (format) {
    BookFormat.cbz => false,
    BookFormat.pdf => hasSearchableText == true,
    BookFormat.epub ||
    BookFormat.fb2 ||
    BookFormat.mobi ||
    BookFormat.azw3 ||
    null => true,
  };
}

/// Whether a reported relocation is the reader turning a page themselves.
///
/// Books only: the article shell also reports image loads and layout
/// observers as `scroll`, so it cannot tell a reader's scroll apart.
bool isReaderPageTurn({
  required SourceType sourceType,
  required String? relocationReason,
}) =>
    sourceType == SourceType.book &&
    (relocationReason == 'page' || relocationReason == 'snap');
