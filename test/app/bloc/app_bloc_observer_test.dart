import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monitoring/monitoring.dart';
import 'package:readflex/app/bloc/app_bloc_observer.dart';

void main() {
  test(
    'disabled activity does not format states or events but still logs errors',
    () {
      final sink = _CollectingLogObserver();
      final observer = AppBlocObserver(
        Logger(observers: [sink]),
        logActivity: false,
      );
      final bloc = _ProbeBloc();
      addTearDown(bloc.close);
      final current = _CountingState();
      final next = _CountingState();
      final event = _CountingState();

      observer.onEvent(bloc, event);
      observer.onTransition(
        bloc,
        Transition<Object?, Object?>(
          currentState: current,
          event: event,
          nextState: next,
        ),
      );
      expect([current.formats, next.formats, event.formats], [0, 0, 0]);
      expect(sink.messages, isEmpty);

      observer.onError(bloc, StateError('failed'), StackTrace.empty);
      expect(sink.messages.single, contains('failed'));
    },
  );

  test('each transition state is formatted only once', () {
    final observer = AppBlocObserver(Logger());
    final bloc = _ProbeBloc();
    addTearDown(bloc.close);
    final current = _CountingState();
    final next = _CountingState();

    observer.onTransition(
      bloc,
      Transition<Object?, Object?>(
        currentState: current,
        event: const _VerboseEvent('load'),
        nextState: next,
      ),
    );

    expect(current.formats, 1);
    expect(next.formats, 1);
  });

  test('transition logs truncate large state payloads', () {
    final sink = _CollectingLogObserver();
    final logger = Logger(observers: [sink]);
    final observer = AppBlocObserver(logger);
    final bloc = _ProbeBloc();
    final longPayload = '${'x' * 500}FULL_ARTICLE_BODY';

    observer.onTransition(
      bloc,
      Transition<Object?, Object?>(
        currentState: _VerboseState('before $longPayload'),
        event: const _VerboseEvent('load'),
        nextState: _VerboseState('after $longPayload'),
      ),
    );

    expect(sink.messages, hasLength(1));
    expect(sink.messages.single, isNot(contains('FULL_ARTICLE_BODY')));
    expect(sink.messages.single.length, lessThan(1000));

    bloc.close();
  });
}

class _CountingState {
  int formats = 0;

  @override
  String toString() {
    formats++;
    return 'state';
  }
}

class _CollectingLogObserver with LogObserver {
  final messages = <String>[];

  @override
  void onLog(LogMessage logMessage) {
    messages.add(logMessage.message);
  }
}

class _ProbeBloc extends Bloc<Object?, Object?> {
  _ProbeBloc() : super(null);
}

class _VerboseState {
  const _VerboseState(this.value);

  final String value;

  @override
  String toString() => 'VerboseState($value)';
}

class _VerboseEvent {
  const _VerboseEvent(this.value);

  final String value;

  @override
  String toString() => 'VerboseEvent($value)';
}
