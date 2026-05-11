import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Whether the reader's bottom action chrome is shown.
class ReaderChromeState extends Equatable {
  const ReaderChromeState({this.chromeVisible = false});

  final bool chromeVisible;

  ReaderChromeState copyWith({bool? chromeVisible}) =>
      ReaderChromeState(chromeVisible: chromeVisible ?? this.chromeVisible);

  @override
  List<Object?> get props => [chromeVisible];
}

/// Toggles visibility of the reader's slide-in/out chrome in response to
/// WebView tap gestures (`toggle`), transient overlays (`show`/`hide`), or
/// text selection (`hide`, so the context panel has the bottom of the screen
/// to itself).
class ReaderChromeCubit extends Cubit<ReaderChromeState> {
  ReaderChromeCubit() : super(const ReaderChromeState());

  void toggle() => emit(state.copyWith(chromeVisible: !state.chromeVisible));

  void show() {
    if (state.chromeVisible) return;
    emit(state.copyWith(chromeVisible: true));
  }

  void hide() {
    if (!state.chromeVisible) return;
    emit(state.copyWith(chromeVisible: false));
  }
}
