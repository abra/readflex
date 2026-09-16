import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:monitoring/monitoring.dart';
import 'package:readflex/utils/string_extension.dart';

const _stateLogLimit = 300;
const _eventLogLimit = 200;

/// Optional Bloc event/transition diagnostics and unconditional Bloc/Cubit errors.
class AppBlocObserver extends BlocObserver {
  /// Creates an instance of [AppBlocObserver] with the provided [logger].
  const AppBlocObserver(this.logger, {this.logActivity = !kReleaseMode});

  final bool logActivity;

  /// Logger used to log information during bloc transitions.
  final Logger logger;

  @override
  void onTransition(
    Bloc<Object?, Object?> bloc,
    Transition<Object?, Object?> transition,
  ) {
    super.onTransition(bloc, transition);
    if (!logActivity) return;
    final currentState = _formatState(transition.currentState, _stateLogLimit);
    final nextState = _formatState(transition.nextState, _stateLogLimit);
    final logMessage = StringBuffer()
      ..writeln('Bloc: ${bloc.runtimeType}')
      ..writeln('Event: ${transition.event.runtimeType}')
      ..writeln(
        'Transition: $currentState =>\n'
        '           $nextState',
      );

    logger.info(logMessage.toString());
  }

  @override
  void onEvent(Bloc<Object?, Object?> bloc, Object? event) {
    super.onEvent(bloc, event);
    if (!logActivity) return;
    final logMessage = StringBuffer()
      ..writeln('Bloc: ${bloc.runtimeType}')
      ..writeln('Event: ${event.runtimeType}')
      ..write('Details: ${_formatState(event, _eventLogLimit)}');

    logger.info(logMessage.toString());
  }

  @override
  void onError(BlocBase<Object?> bloc, Object error, StackTrace stackTrace) {
    final logMessage = StringBuffer()
      ..writeln('Bloc: ${bloc.runtimeType}')
      ..writeln(error.toString());

    logger.error(logMessage.toString(), error: error, stackTrace: stackTrace);
    super.onError(bloc, error, stackTrace);
  }

  static String _formatState(Object? value, int limit) =>
      value?.toString().limit(limit) ?? 'null';
}
