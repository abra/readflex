import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_ui_cubit.dart';

void main() {
  group('ReaderUiCubit', () {
    ReaderUiCubit buildCubit() => ReaderUiCubit();

    test('initial state hides chrome and overlays', () {
      final cubit = buildCubit();
      expect(cubit.state.chromeVisible, isFalse);
      expect(cubit.state.overlay, ReaderOverlay.none);
      expect(cubit.state.clearSearchToken, 0);
    });

    test('toggleChrome flips chrome visibility', () {
      final cubit = buildCubit();

      cubit.toggleChrome();
      expect(cubit.state.chromeVisible, isTrue);

      cubit.toggleChrome();
      expect(cubit.state.chromeVisible, isFalse);
    });

    test('openTocDrawer hides chrome and requests search clear', () {
      final cubit = buildCubit()..showChrome();

      cubit.openTocDrawer();

      expect(cubit.state.chromeVisible, isFalse);
      expect(cubit.state.tocDrawerVisible, isTrue);
      expect(cubit.state.clearSearchToken, 1);
    });

    test('closeTocDrawer restores chrome by default', () {
      final cubit = buildCubit()..openTocDrawer();

      cubit.closeTocDrawer();

      expect(cubit.state.chromeVisible, isTrue);
      expect(cubit.state.overlay, ReaderOverlay.none);
    });

    test('search result highlight survives initial relocation only', () {
      final cubit = buildCubit()..searchResultHighlightActivated();

      cubit.readerPositionChanged(relocationReason: 'page');
      expect(cubit.state.searchHighlightVisible, isTrue);
      expect(cubit.state.ignoreNextSearchRelocation, isFalse);
      expect(cubit.state.clearSearchToken, 0);

      cubit.readerPositionChanged(relocationReason: 'page');
      expect(cubit.state.searchHighlightVisible, isFalse);
      expect(cubit.state.clearSearchToken, 1);
    });

    test('appearance sheet returns chrome when fully hidden', () {
      final cubit = buildCubit()..showChrome();

      final opened = cubit.beginAppearanceSheet();
      expect(opened, isTrue);
      expect(cubit.state.chromeVisible, isFalse);
      expect(cubit.state.appearanceSheetVisible, isTrue);

      cubit.appearanceSheetHidden();
      expect(cubit.state.chromeVisible, isTrue);
      expect(cubit.state.overlay, ReaderOverlay.none);
    });
  });
}
