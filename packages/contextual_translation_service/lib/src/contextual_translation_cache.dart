import 'contextual_translation_models.dart';

abstract class ContextualTranslationCache {
  ContextualTranslationResult? read(ContextualTranslationRequest request);

  void write(
    ContextualTranslationRequest request,
    ContextualTranslationResult result,
  );
}

class MemoryContextualTranslationCache implements ContextualTranslationCache {
  final _items = <String, ContextualTranslationResult>{};

  @override
  ContextualTranslationResult? read(ContextualTranslationRequest request) {
    return _items[request.toCacheKey()];
  }

  @override
  void write(
    ContextualTranslationRequest request,
    ContextualTranslationResult result,
  ) {
    _items[request.toCacheKey()] = result;
  }
}
