enum ArticleTextDirection {
  ltr('ltr'),
  rtl('rtl')
  ;

  const ArticleTextDirection(this.value);

  final String value;

  static ArticleTextDirection? fromString(String? value) {
    final normalized = value?.trim().toLowerCase();
    return switch (normalized) {
      'ltr' => ArticleTextDirection.ltr,
      'rtl' => ArticleTextDirection.rtl,
      _ => null,
    };
  }
}

const _rtlLanguageCodes = {
  'ar',
  'arc',
  'ckb',
  'dv',
  'fa',
  'he',
  'iw',
  'lrc',
  'mzn',
  'nqo',
  'ps',
  'sd',
  'ug',
  'ur',
  'yi',
};

String? normalizeArticleLanguage(String? language) {
  final trimmed = language?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;

  final firstTag = trimmed.split(RegExp(r'[,;\s]+')).first.trim();
  if (firstTag.isEmpty || firstTag == '*') return null;

  final normalized = firstTag.replaceAll('_', '-').toLowerCase();
  return normalized == 'x-default' ? null : normalized;
}

ArticleTextDirection? articleTextDirectionForLanguage(String? language) {
  final normalized = normalizeArticleLanguage(language);
  if (normalized == null) return null;

  final subtags = normalized.split('-');
  if (subtags.any((subtag) => subtag == 'arab' || subtag == 'hebr')) {
    return ArticleTextDirection.rtl;
  }

  final languageCode = subtags.first;
  return _rtlLanguageCodes.contains(languageCode)
      ? ArticleTextDirection.rtl
      : null;
}

ArticleTextDirection? inferArticleTextDirectionFromText(String text) {
  final sample = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (sample.isEmpty) return null;

  final bounded = sample.length > 5000 ? sample.substring(0, 5000) : sample;
  final rtlCount = RegExp(
    r'[\u0590-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFF]',
  ).allMatches(bounded).length;
  final ltrCount = RegExp(
    r'[A-Za-z\u00C0-\u024F\u1E00-\u1EFF]',
  ).allMatches(bounded).length;

  if (rtlCount == 0 && ltrCount == 0) return null;
  return rtlCount > ltrCount
      ? ArticleTextDirection.rtl
      : ArticleTextDirection.ltr;
}
