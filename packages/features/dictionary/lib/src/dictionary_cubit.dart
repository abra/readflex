import 'package:dictionary_service/dictionary_service.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared/shared.dart';

enum DictionarySheetStatus {
  initial,
  loading,
  success,
  notFound,
  unsupportedLanguage,
  failure,
}

class DictionarySheetState extends Equatable {
  const DictionarySheetState({
    this.status = DictionarySheetStatus.initial,
    this.result,
    this.failure,
  });

  final DictionarySheetStatus status;
  final DictionaryLookupResult? result;
  final DictionaryLookupException? failure;

  DictionarySheetState copyWith({
    DictionarySheetStatus? status,
    Object? result = _absent,
    Object? failure = _absent,
  }) {
    return DictionarySheetState(
      status: status ?? this.status,
      result: result == _absent
          ? this.result
          : result as DictionaryLookupResult?,
      failure: failure == _absent
          ? this.failure
          : failure as DictionaryLookupException?,
    );
  }

  @override
  List<Object?> get props => [status, result, failure];
}

class DictionaryCubit extends Cubit<DictionarySheetState> {
  DictionaryCubit({required DictionaryLookupService dictionaryService})
    : _dictionaryService = dictionaryService,
      super(const DictionarySheetState());

  final DictionaryLookupService _dictionaryService;

  Future<void> lookup(TextSelectionContext selection) async {
    if (state.status == DictionarySheetStatus.loading) return;
    emit(
      state.copyWith(
        status: DictionarySheetStatus.loading,
        result: null,
        failure: null,
      ),
    );
    try {
      final result = await _dictionaryService.lookup(
        DictionaryLookupRequest(
          term: selection.effectiveSelectedText,
          sourceLanguage: selection.sourceLanguageHint,
          contextText:
              selection.effectiveMarkedContextText ?? selection.contextText,
        ),
      );
      emit(
        state.copyWith(
          status: _statusFor(result.status),
          result: result,
          failure: null,
        ),
      );
    } on DictionaryLookupException catch (error) {
      emit(
        state.copyWith(
          status: DictionarySheetStatus.failure,
          result: null,
          failure: error,
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(
        state.copyWith(
          status: DictionarySheetStatus.failure,
          result: null,
          failure: const DictionaryLookupException(
            DictionaryLookupFailureReason.invalidResponse,
            'Unexpected dictionary lookup failure',
          ),
        ),
      );
    }
  }
}

DictionarySheetStatus _statusFor(DictionaryLookupStatus status) {
  return switch (status) {
    DictionaryLookupStatus.found => DictionarySheetStatus.success,
    DictionaryLookupStatus.notFound => DictionarySheetStatus.notFound,
    DictionaryLookupStatus.unsupportedLanguage =>
      DictionarySheetStatus.unsupportedLanguage,
  };
}

const _absent = Object();
