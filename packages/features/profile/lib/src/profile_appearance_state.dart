part of 'profile_appearance_cubit.dart';

class ProfileAppearanceState extends Equatable {
  const ProfileAppearanceState({
    required this.themeMode,
    required this.readerAppearance,
  });

  final ThemeMode themeMode;
  final ReaderAppearancePreferences readerAppearance;

  ProfileAppearanceState copyWith({
    ThemeMode? themeMode,
    ReaderAppearancePreferences? readerAppearance,
  }) => ProfileAppearanceState(
    themeMode: themeMode ?? this.themeMode,
    readerAppearance: readerAppearance ?? this.readerAppearance,
  );

  @override
  List<Object?> get props => [themeMode, readerAppearance];
}
