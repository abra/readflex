import 'package:flutter/services.dart';

import 'dictionary_service.dart';

class PlatformSystemDictionaryService implements SystemDictionaryService {
  const PlatformSystemDictionaryService({
    MethodChannel channel = const MethodChannel(_channelName),
  }) : _channel = channel;

  static const _channelName = 'io.github.abra.readflex/dictionary';

  final MethodChannel _channel;

  @override
  Future<bool> showDefinition(String term) async {
    final normalized = term.trim();
    if (normalized.isEmpty) return false;
    try {
      return await _channel.invokeMethod<bool>('showDefinition', {
            'term': normalized,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
