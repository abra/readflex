// Global BLoC observer: logs every event, state transition and error
// across all blocs and cubits in the application.
//
// Registered once in starter.dart via Bloc.observer so that individual
// blocs do not need their own logging logic.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:monitoring/monitoring.dart';
import 'package:readflex/utils/string_extension.dart';

const _stateLogLimit = 300;
const _newStateLogLimit = 150;
const _eventLogLimit = 200;

/// [BlocObserver] which logs all bloc state changes, errors and events.
class AppBlocObserver extends BlocObserver {
  /// Creates an instance of [AppBlocObserver] with the provided [logger].
  const AppBlocObserver(this.logger);

  /// Logger used to log information during bloc transitions.
  final Logger logger;

  @override
  void onTransition(
    Bloc<Object?, Object?> bloc,
    Transition<Object?, Object?> transition,
  ) {
    final currentState = _formatState(transition.currentState, _stateLogLimit);
    final nextState = _formatState(transition.nextState, _stateLogLimit);
    final logMessage = StringBuffer()
      ..writeln('Bloc: ${bloc.runtimeType}')
      ..writeln('Event: ${transition.event.runtimeType}')
      ..writeln(
        'Transition: $currentState =>\n'
        '           $nextState',
      )
      ..write(
        'New State: ${_formatState(transition.nextState, _newStateLogLimit)}\n',
      );

    logger.info(logMessage.toString());
    super.onTransition(bloc, transition);
  }

  @override
  void onEvent(Bloc<Object?, Object?> bloc, Object? event) {
    final logMessage = StringBuffer()
      ..writeln('Bloc: ${bloc.runtimeType}')
      ..writeln('Event: ${event.runtimeType}')
      ..write('Details: ${_formatState(event, _eventLogLimit)}');

    logger.info(logMessage.toString());
    super.onEvent(bloc, event);
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
