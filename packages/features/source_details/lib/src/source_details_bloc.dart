import 'package:book_repository/book_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'source_details_event.dart';
part 'source_details_state.dart';

class SourceDetailsBloc extends Bloc<SourceDetailsEvent, SourceDetailsState> {
  SourceDetailsBloc({required BookRepository bookRepository})
    : _bookRepository = bookRepository,
      super(const SourceDetailsState()) {
    on<SourceDetailsLoadRequested>(_onLoadRequested);
  }

  final BookRepository _bookRepository;

  Future<void> _onLoadRequested(
    SourceDetailsLoadRequested event,
    Emitter<SourceDetailsState> emit,
  ) async {
    emit(state.copyWith(status: SourceDetailsStatus.loading));
    try {
      final source = await _bookRepository.getBookById(event.sourceId);
      if (source == null) {
        emit(const SourceDetailsState(status: SourceDetailsStatus.notFound));
        return;
      }
      emit(
        SourceDetailsState(status: SourceDetailsStatus.success, source: source),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(const SourceDetailsState(status: SourceDetailsStatus.failure));
    }
  }
}
