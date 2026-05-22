import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monitoring/monitoring.dart';
import 'package:readflex/app/bloc/app_bloc_observer.dart';

void main() {
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
