import 'package:domain_models/domain_models.dart';

import 'reader_search_cubit.dart';
import 'reader_surface.dart';
import 'reader_ui_cubit.dart';

/// Coordinates search jumps and return-to-reading across every page surface.
/// Owns only transient navigation state; the host owns cubits and renderers.
class ReaderSearchNavigator {
  ReaderSearchNavigator({
    required ReaderSearchCubit searchCubit,
    required ReaderUiCubit uiCubit,
    required this._surface,
    required this._sourceType,
    required this._closeSearchPanel,
    required this._waitForLayout,
  }) : _search = searchCubit,
       _ui = uiCubit;

  final ReaderSearchCubit _search;
  final ReaderUiCubit _ui;
  final ReaderSurface Function() _surface;
  final SourceType Function() _sourceType;
  final void Function() _closeSearchPanel;
  final Future<void> Function() _waitForLayout;

  ReaderSearchLocation? _latestLocation;
  ReaderSearchLocation? _searchStartLocation;
  int _generation = 0;
  bool _disposed = false;

  void rememberLocation({required String cfi, required double fraction}) {
    if (_disposed || cfi.isEmpty || !fraction.isFinite) return;
    _latestLocation = ReaderSearchLocation(
      cfi: cfi,
      fraction: fraction.clamp(0, 1),
    );
  }

  void openSearch() {
    if (_disposed) return;
    // Capture before the keyboard can resize the native viewport.
    if (!_search.state.isNavigating) _searchStartLocation = _latestLocation;
    _ui.openSearchDrawer();
  }

  void surfaceLoading() {
    if (_disposed) return;
    _latestLocation = null;
    endSearch();
  }

  void endSearch() {
    if (_disposed) return;
    _generation++;
    _searchStartLocation = null;
    _search.reset();
  }

  Future<void> selectResult(int index) async {
    if (_disposed || index < 0 || index >= _search.state.results.length) return;
    final result = _search.state.results[index];
    final query = _search.state.query;
    if (result.cfi.isEmpty) return;
    _search.resultSelected(
      index: index,
      returnLocation: _searchStartLocation ?? _latestLocation,
    );
    _closeSearchPanel();
    final generation = ++_generation;
    // Keep the existing viewport until the panel and keyboard have closed.
    await _waitForLayout();
    if (_disposed ||
        generation != _generation ||
        _search.state.query != query ||
        _search.state.activeResultIndex != index) {
      return;
    }
    _ui.searchResultHighlightActivated();
    _surface().goToSearchResult(result.cfi);
  }

  Future<void> returnToReading() async {
    if (_disposed) return;
    final origin = _search.state.returnLocation;
    if (origin == null) return;
    endSearch();
    final generation = _generation;
    await _waitForLayout();
    if (_disposed || generation != _generation) return;
    if (_sourceType() == SourceType.article) {
      // Article CFIs center a sentence; progress restores the exact viewport.
      _surface().goToFraction(origin.fraction);
    } else {
      _surface().goToBookmark(cfi: origin.cfi, progress: origin.fraction);
    }
  }

  /// Invalidates pending jumps without closing the host's dependencies.
  void dispose() {
    _disposed = true;
    _generation++;
  }
}
