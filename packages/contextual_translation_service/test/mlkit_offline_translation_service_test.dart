import 'dart:async';
import 'dart:collection';

import 'package:contextual_translation_service/contextual_translation_service.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

void main() {
  late List<_FakeTranslator> created;
  late List<String> violations;
  late MlKitOfflineTranslationService service;
  Object? creationError;

  setUp(() {
    created = [];
    violations = [];
    creationError = null;
    _FakeTranslator.gates.clear();
    _FakeTranslator.nextError = null;
    service = MlKitOfflineTranslationService.forTesting(
      translatorFactory: ({required sourceLanguage, required targetLanguage}) {
        final error = creationError;
        if (error != null) throw error;
        final translator = _FakeTranslator(
          sourceLanguage,
          targetLanguage,
          violations,
        );
        created.add(translator);
        return translator;
      },
    );
  });

  tearDown(() {
    service.dispose();
    expect(violations, isEmpty);
  });

  Future<ContextualTranslationResult> translate({
    String source = 'en',
    String target = 'ru',
    String text = 'hello',
    String? sentence,
  }) {
    return service.translate(
      _request(target: target, text: text, sentence: sentence),
      sourceLanguage: source,
    );
  }

  test('reuses one translator for repeated requests in a pair', () async {
    final first = await translate(sentence: 'hello there');
    await translate(source: 'EN-us', text: 'world');
    await translate(source: 'en_GB', target: 'ru-RU', text: 'again');

    expect(created, hasLength(1));
    expect(created.single.texts, ['hello', 'hello there', 'world', 'again']);
    expect(created.single.closeCalls, 0);
    expect(first.translation.contextualTranslation, 'hello:ru');
    expect(first.translation.sentenceTranslation, 'hello there:ru');
    expect(first.detectedSourceLanguage, 'en');
  });

  test('a pair change closes the old translator and opens one', () async {
    await translate(target: 'ru');
    await translate(target: 'de');

    expect(created, hasLength(2));
    expect(created.first.targetLanguage, TranslateLanguage.russian);
    expect(created.first.closeCalls, 1);
    expect(created.last.targetLanguage, TranslateLanguage.german);
    expect(created.last.closeCalls, 0);
    expect(created.last.texts, ['hello']);
  });

  test('closes an idle translator after two minutes, then opens anew', () {
    fakeAsync((async) {
      _resolve(async, translate());

      async.elapse(const Duration(minutes: 1, seconds: 59));
      expect(created.single.closeCalls, 0);
      async.elapse(const Duration(seconds: 1));
      expect(created.single.closeCalls, 1);

      _resolve(async, translate(text: 'later'));
      expect(created, hasLength(2));
      expect(created.first.texts, ['hello']);
      expect(created.last.texts, ['later']);
      expect(created.last.closeCalls, 0);
    });
  });

  test('every request restarts the idle countdown', () {
    fakeAsync((async) {
      _resolve(async, translate());
      async.elapse(const Duration(minutes: 1, seconds: 30));
      _resolve(async, translate(text: 'again'));

      async.elapse(const Duration(minutes: 1, seconds: 59));
      expect(created.single.closeCalls, 0);
      async.elapse(const Duration(seconds: 1));
      expect(created.single.closeCalls, 1);
      expect(async.pendingTimers, isEmpty);
    });
  });

  test('does not count idle time while a request is running', () {
    fakeAsync((async) {
      final gate = Completer<void>();
      _FakeTranslator.gates.add(gate);
      final running = translate();
      async.elapse(const Duration(minutes: 5));
      expect(created.single.closeCalls, 0);

      gate.complete();
      _resolve(async, running);
      async.elapse(const Duration(minutes: 1, seconds: 59));
      expect(created.single.closeCalls, 0);
      async.elapse(const Duration(seconds: 1));
      expect(created.single.closeCalls, 1);
    });
  });

  test('concurrent requests in one pair share a translator', () async {
    final gate = Completer<void>();
    _FakeTranslator.gates.addAll([gate, gate]);
    final first = translate(text: 'one');
    final second = translate(text: 'two');
    await pumpEventQueue();
    expect(created, hasLength(1));
    expect(created.single.pending, 2);

    gate.complete();
    final results = await Future.wait([first, second]);

    expect(results.map((result) => result.translation.contextualTranslation), [
      'one:ru',
      'two:ru',
    ]);
    expect(created.single.closeCalls, 0);
  });

  test(
    'a pair change during a request closes the old translator after it',
    () async {
      final gate = Completer<void>();
      _FakeTranslator.gates.add(gate);
      final russian = translate(target: 'ru', text: 'first');
      await pumpEventQueue();

      final german = await translate(target: 'de', text: 'second');
      expect(german.translation.contextualTranslation, 'second:de');
      expect(created, hasLength(2));
      expect(created.first.closeCalls, 0, reason: 'still translating');

      gate.complete();
      expect(
        (await russian).translation.contextualTranslation,
        'first:ru',
        reason: 'finished on its own translator',
      );
      expect(created.first.closeCalls, 1);
      expect(created.last.closeCalls, 0);

      await translate(target: 'de', text: 'third');
      expect(created, hasLength(2), reason: 'the German translator stays');
      expect(created.last.texts, ['second', 'third']);
    },
  );

  test('switching back to a retired pair opens a new translator', () async {
    final gate = Completer<void>();
    _FakeTranslator.gates.add(gate);
    final russian = translate(target: 'ru');
    await pumpEventQueue();
    await translate(target: 'de');
    await translate(target: 'ru', text: 'back');

    expect(created, hasLength(3));
    expect(created[1].closeCalls, 1, reason: 'German replaced by Russian');
    expect(created.last.texts, ['back']);
    expect(created.first.closeCalls, 0);

    gate.complete();
    await russian;
    expect(created.first.closeCalls, 1);
    expect(created.last.closeCalls, 0);
  });

  test('dispose closes the translator once', () async {
    await translate();

    service
      ..dispose()
      ..dispose();

    expect(created.single.closeCalls, 1);
  });

  test('dispose during a request closes the translator after it', () async {
    final gate = Completer<void>();
    _FakeTranslator.gates.add(gate);
    final running = translate();
    await pumpEventQueue();

    service.dispose();
    expect(created.single.closeCalls, 0);

    gate.complete();
    expect((await running).translation.contextualTranslation, 'hello:ru');
    expect(created.single.closeCalls, 1);
  });

  test('dispose cancels the idle countdown', () {
    fakeAsync((async) {
      _resolve(async, translate());
      service.dispose();

      expect(created.single.closeCalls, 1);
      expect(async.pendingTimers, isEmpty);
    });
  });

  test('a request after dispose fails without opening a translator', () async {
    service.dispose();

    await expectLater(
      translate(),
      _failsWith(ContextualTranslationFailureReason.unavailable),
    );
    expect(created, isEmpty);
  });

  test('a failed translation discards its translator', () async {
    _FakeTranslator.nextError = Exception('model missing');

    await expectLater(
      translate(),
      _failsWith(ContextualTranslationFailureReason.unavailable),
    );
    expect(created.single.closeCalls, 1);

    await translate(text: 'retry');
    expect(created, hasLength(2));
    expect(created.last.texts, ['retry']);
    expect(created.last.closeCalls, 0);
  });

  test('a failure waits for other requests on its translator', () async {
    final healthyGate = Completer<void>();
    final failingGate = Completer<void>();
    _FakeTranslator.gates.addAll([healthyGate, failingGate]);
    final healthy = translate(text: 'healthy');
    created.single.error = Exception('model missing');
    final failing = translate(text: 'failing');
    created.single.error = null;

    failingGate.complete();
    await expectLater(
      failing,
      _failsWith(ContextualTranslationFailureReason.unavailable),
    );
    expect(created.single.closeCalls, 0, reason: 'healthy is still running');

    healthyGate.complete();
    expect((await healthy).translation.contextualTranslation, 'healthy:ru');
    expect(created.single.closeCalls, 1);

    await translate(text: 'next');
    expect(
      created,
      hasLength(2),
      reason: 'the failed translator is not reused',
    );
  });

  test('a factory failure keeps the current translator', () {
    fakeAsync((async) {
      _resolve(async, translate(target: 'ru'));
      creationError = StateError('no native translator');

      Object? error;
      translate(target: 'de').then<void>(
        (_) {},
        onError: (Object e) {
          error = e;
        },
      );
      async.flushMicrotasks();
      expect(
        error,
        isA<ContextualTranslationException>().having(
          (e) => e.reason,
          'reason',
          ContextualTranslationFailureReason.unavailable,
        ),
      );
      expect(created.single.closeCalls, 0);

      creationError = null;
      _resolve(async, translate(target: 'ru', text: 'still'));
      expect(created, hasLength(1));
      expect(created.single.texts, ['hello', 'still']);

      async.elapse(const Duration(minutes: 2));
      expect(created.single.closeCalls, 1, reason: 'idle close still runs');
    });
  });

  test('ignores errors from closing a native translator', () async {
    await translate();
    created.single.closeError = Exception('channel gone');

    service.dispose();
    await pumpEventQueue();

    expect(created.single.closeCalls, 1);
  });
}

ContextualTranslationRequest _request({
  String target = 'ru',
  String text = 'hello',
  String? sentence,
}) {
  return ContextualTranslationRequest(
    requestId: 'request-$text',
    sourceLanguage: 'en',
    targetLanguage: target,
    selection: TranslationSelection(text: text),
    context: TranslationTextContext(
      level: 'sentence',
      current: TranslationContextPassage(text: sentence ?? text),
    ),
    anchor: const TranslationAnchor(sourceId: 'source-1', sourceType: 'book'),
  );
}

Matcher _failsWith(ContextualTranslationFailureReason reason) => throwsA(
  isA<ContextualTranslationException>().having(
    (e) => e.reason,
    'reason',
    reason,
  ),
);

T _resolve<T>(FakeAsync async, Future<T> future) {
  late T value;
  var done = false;
  future.then((result) {
    value = result;
    done = true;
  });
  async.flushMicrotasks();
  expect(done, isTrue, reason: 'the future did not complete');
  return value;
}

class _FakeTranslator implements OnDeviceTranslator {
  _FakeTranslator(this.sourceLanguage, this.targetLanguage, this._violations)
    : error = nextError {
    nextError = null;
  }

  /// Each translation waits for the next queued gate, if any.
  static final gates = Queue<Completer<void>>();

  /// The error of every translation by the next created translator.
  static Object? nextError;

  @override
  final TranslateLanguage sourceLanguage;
  @override
  final TranslateLanguage targetLanguage;
  @override
  final String id = 'fake';

  final List<String> _violations;
  Object? error;
  Object? closeError;
  final texts = <String>[];
  var pending = 0;
  var closeCalls = 0;

  @override
  Future<String> translateText(String text) async {
    if (closeCalls > 0) _violations.add('translated "$text" after close');
    final error = this.error;
    final gate = gates.isEmpty ? null : gates.removeFirst();
    pending++;
    try {
      await gate?.future;
      if (error != null) throw error;
      texts.add(text);
      return '$text:${targetLanguage.bcpCode}';
    } finally {
      pending--;
    }
  }

  @override
  Future<void> close() async {
    if (pending > 0) _violations.add('closed while translating');
    closeCalls++;
    final error = closeError;
    if (error != null) throw error;
  }
}
