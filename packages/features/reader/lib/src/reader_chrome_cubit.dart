import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ReaderChromeState extends Equatable {
  const ReaderChromeState({this.chromeVisible = false});

  final bool chromeVisible;

  ReaderChromeState copyWith({bool? chromeVisible}) =>
      ReaderChromeState(chromeVisible: chromeVisible ?? this.chromeVisible);

  @override
  List<Object?> get props => [chromeVisible];
}

class ReaderChromeCubit extends Cubit<ReaderChromeState> {
  ReaderChromeCubit() : super(const ReaderChromeState());

  void toggle() => emit(state.copyWith(chromeVisible: !state.chromeVisible));

  void hide() {
    if (!state.chromeVisible) return;
    emit(state.copyWith(chromeVisible: false));
  }
}
