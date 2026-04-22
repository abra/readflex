import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ReaderReviewReminderState extends Equatable {
  const ReaderReviewReminderState({this.showReminder = false});

  final bool showReminder;

  ReaderReviewReminderState copyWith({bool? showReminder}) =>
      ReaderReviewReminderState(
        showReminder: showReminder ?? this.showReminder,
      );

  @override
  List<Object?> get props => [showReminder];
}

class ReaderReviewReminderCubit extends Cubit<ReaderReviewReminderState> {
  ReaderReviewReminderCubit({
    required String sourceId,
    required Future<int> Function(String sourceId)? onCheckDueItems,
    Duration checkInterval = const Duration(minutes: 5),
  }) : super(const ReaderReviewReminderState()) {
    if (onCheckDueItems != null) {
      _start(sourceId, onCheckDueItems, checkInterval);
    }
  }

  Timer? _timer;

  void _start(
    String sourceId,
    Future<int> Function(String) onCheckDueItems,
    Duration interval,
  ) {
    _check(sourceId, onCheckDueItems);
    _timer = Timer.periodic(
      interval,
      (_) => _check(sourceId, onCheckDueItems),
    );
  }

  Future<void> _check(
    String sourceId,
    Future<int> Function(String) onCheckDueItems,
  ) async {
    try {
      final count = await onCheckDueItems(sourceId);
      if (!isClosed && count > 0) {
        emit(const ReaderReviewReminderState(showReminder: true));
      }
    } catch (e, st) {
      if (!isClosed) addError(e, st);
    }
  }

  void dismiss() {
    if (!state.showReminder) return;
    emit(const ReaderReviewReminderState());
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
