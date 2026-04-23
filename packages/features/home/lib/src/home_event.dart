part of 'home_bloc.dart';

sealed class HomeEvent {
  const HomeEvent();
}

/// Initial dashboard load — fired from [HomeScreen] on first build.
final class HomeLoadRequested extends HomeEvent {
  const HomeLoadRequested();
}
