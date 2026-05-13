import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum ReaderOverlay { none, toc, search, appearance }

class ReaderUiState extends Equatable {
  const ReaderUiState({
    this.chromeVisible = false,
    this.overlay = ReaderOverlay.none,
    this.searchHighlightVisible = false,
    this.ignoreNextSearchRelocation = false,
    this.clearSearchToken = 0,
  });

  final bool chromeVisible;
  final ReaderOverlay overlay;
  final bool searchHighlightVisible;
  final bool ignoreNextSearchRelocation;

  /// Incremented when foliate-js search annotations must be cleared.
  final int clearSearchToken;

  bool get tocDrawerVisible => overlay == ReaderOverlay.toc;

  bool get searchDrawerVisible => overlay == ReaderOverlay.search;

  bool get appearanceSheetVisible => overlay == ReaderOverlay.appearance;

  ReaderUiState copyWith({
    bool? chromeVisible,
    ReaderOverlay? overlay,
    bool? searchHighlightVisible,
    bool? ignoreNextSearchRelocation,
    int? clearSearchToken,
  }) {
    return ReaderUiState(
      chromeVisible: chromeVisible ?? this.chromeVisible,
      overlay: overlay ?? this.overlay,
      searchHighlightVisible:
          searchHighlightVisible ?? this.searchHighlightVisible,
      ignoreNextSearchRelocation:
          ignoreNextSearchRelocation ?? this.ignoreNextSearchRelocation,
      clearSearchToken: clearSearchToken ?? this.clearSearchToken,
    );
  }

  @override
  List<Object?> get props => [
    chromeVisible,
    overlay,
    searchHighlightVisible,
    ignoreNextSearchRelocation,
    clearSearchToken,
  ];
}

class ReaderUiCubit extends Cubit<ReaderUiState> {
  ReaderUiCubit() : super(const ReaderUiState());

  static const _userRelocationReasons = {'page', 'scroll', 'snap'};

  bool beginAppearanceSheet() {
    if (state.appearanceSheetVisible) return false;
    emit(
      state.copyWith(
        chromeVisible: false,
        overlay: ReaderOverlay.appearance,
        searchHighlightVisible: false,
        ignoreNextSearchRelocation: false,
        clearSearchToken: state.clearSearchToken + 1,
      ),
    );
    return true;
  }

  void appearanceSheetHidden() {
    if (!state.appearanceSheetVisible) return;
    emit(
      state.copyWith(
        chromeVisible: true,
        overlay: ReaderOverlay.none,
      ),
    );
  }

  void clearReaderSearch() {
    emit(
      state.copyWith(
        searchHighlightVisible: false,
        ignoreNextSearchRelocation: false,
        clearSearchToken: state.clearSearchToken + 1,
      ),
    );
  }

  void closeSearchDrawer({
    bool restoreChrome = true,
    bool clearSearch = true,
  }) {
    if (!state.searchDrawerVisible) return;
    emit(
      state.copyWith(
        chromeVisible: restoreChrome ? true : state.chromeVisible,
        overlay: ReaderOverlay.none,
        searchHighlightVisible: clearSearch
            ? false
            : state.searchHighlightVisible,
        ignoreNextSearchRelocation: clearSearch
            ? false
            : state.ignoreNextSearchRelocation,
        clearSearchToken: clearSearch
            ? state.clearSearchToken + 1
            : state.clearSearchToken,
      ),
    );
  }

  void closeTocDrawer({bool restoreChrome = true}) {
    if (!state.tocDrawerVisible) return;
    emit(
      state.copyWith(
        chromeVisible: restoreChrome ? true : state.chromeVisible,
        overlay: ReaderOverlay.none,
      ),
    );
  }

  void openSearchDrawer() {
    if (state.searchDrawerVisible) return;
    emit(
      state.copyWith(
        chromeVisible: false,
        overlay: ReaderOverlay.search,
        searchHighlightVisible: false,
        ignoreNextSearchRelocation: false,
        clearSearchToken: state.clearSearchToken + 1,
      ),
    );
  }

  void openTocDrawer() {
    if (state.tocDrawerVisible) return;
    emit(
      state.copyWith(
        chromeVisible: false,
        overlay: ReaderOverlay.toc,
        searchHighlightVisible: false,
        ignoreNextSearchRelocation: false,
        clearSearchToken: state.clearSearchToken + 1,
      ),
    );
  }

  void searchResultHighlightActivated() {
    emit(
      state.copyWith(
        searchHighlightVisible: true,
        ignoreNextSearchRelocation: true,
      ),
    );
  }

  void readerPositionChanged({required String? relocationReason}) {
    if (!state.searchHighlightVisible) return;

    if (state.ignoreNextSearchRelocation) {
      emit(state.copyWith(ignoreNextSearchRelocation: false));
      return;
    }

    if (_userRelocationReasons.contains(relocationReason)) {
      clearReaderSearch();
    }
  }

  void showChrome() {
    if (state.chromeVisible) return;
    emit(state.copyWith(chromeVisible: true));
  }

  void hideChrome() {
    if (!state.chromeVisible) return;
    emit(state.copyWith(chromeVisible: false));
  }

  void toggleChrome() {
    emit(state.copyWith(chromeVisible: !state.chromeVisible));
  }
}
