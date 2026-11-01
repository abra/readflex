import 'package:flutter_bloc/flutter_bloc.dart';

/// The article's live scroll fraction, independent of saved-position reports.
/// Null until the current article has a reading position.
class ReaderArticleProgressCubit extends Cubit<double?> {
  ReaderArticleProgressCubit() : super(null);

  void update(double fraction) {
    if (!fraction.isFinite) return;
    emit(fraction.clamp(0.0, 1.0));
  }

  void reset() => emit(null);
}
