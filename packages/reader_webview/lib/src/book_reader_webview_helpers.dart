part of 'book_reader_webview.dart';

/// Exact CFI is the preferred restore path. When it is missing — or when the
/// WebView is retrying after the known iOS deep-CFI crash — fall back to the
/// persisted progress fraction so the reader reopens near the last spot
/// instead of at the cover.

@visibleForTesting
ReaderInitialLocation resolveInitialReaderLocation({
  required String? initialCfi,
  required double? initialProgress,
  required bool recoveringFromCrash,
  required bool isArticle,
}) {
  final cfi = switch (initialCfi) {
    final String value when value.isNotEmpty => value,
    _ => null,
  };
  final progress = switch (initialProgress) {
    final double value when value > 0 && value <= 1 => value,
    _ => null,
  };

  // End-of-article CFIs can land foliate-js in trailing buffer columns and make
  // it expose blank pages after restore. Progress restore keeps the last page
  // stable while preserving exact CFI restore for books and mid-article opens.
  final shouldRestoreArticleEndByProgress =
      isArticle && progress != null && progress >= 0.999;

  if (recoveringFromCrash || shouldRestoreArticleEndByProgress) {
    return ReaderInitialLocation(cfi: null, progress: progress);
  }
  if (cfi != null) {
    return ReaderInitialLocation(cfi: cfi, progress: null);
  }
  return ReaderInitialLocation(cfi: null, progress: progress);
}

@visibleForTesting
bool shouldAttemptWebContentRecovery({
  required String? initialCfi,
  required bool isArticle,
  required int recoveryAttempts,
  required int maxRecoveryAttempts,
  required bool recoveryInProgress,
}) {
  if (recoveryInProgress) return false;
  if (recoveryAttempts >= maxRecoveryAttempts) return false;

  final hasInitialCfi = switch (initialCfi?.trim()) {
    final String value when value.isNotEmpty => true,
    _ => false,
  };
  return hasInitialCfi || isArticle;
}

@visibleForTesting
final class ReaderInitialLocation {
  const ReaderInitialLocation({required this.cfi, required this.progress});

  final String? cfi;
  final double? progress;
}

@visibleForTesting
bool isGeneratedArticleReaderPath(String path) =>
    path.endsWith('/article.epub') && path.contains('/articles/');

@visibleForTesting
String buildReaderSearchStartScript({
  required int requestId,
  required String query,
}) {
  final escapedQuery = jsonEncode(query);
  return '''
(() => {
  const requestId = $requestId;
  const query = $escapedQuery;
  const defaultOptions = {
    scope: 'book',
    matchCase: false,
    matchDiacritics: false,
    matchWholeWords: false,
  };

  const sendSearchError = (message) => {
    try {
      const bridge = window.flutter_inappwebview;
      if (bridge && bridge.callHandler) {
        bridge.callHandler('onSearch', {
          requestId,
          type: 'error',
          message: String(message || 'Book search failed'),
        });
      }
    } catch (_) {}
  };

  try {
    if (typeof window.startSearch !== 'function') {
      sendSearchError('Book search bridge is missing');
      return;
    }
    Promise.resolve(window.startSearch(requestId, query, defaultOptions))
      .catch((error) => {
        sendSearchError(error && error.message ? error.message : error);
      });
  } catch (error) {
    sendSearchError(error && error.message ? error.message : error);
  }
})();
''';
}

@visibleForTesting
bool shouldLogReaderConsoleMessage({
  required bool debugMode,
  required String level,
}) {
  if (debugMode) return true;
  return level.toLowerCase().contains('error');
}

@visibleForTesting
String buildReaderCommandScript({
  required String label,
  required String expression,
}) {
  final escapedLabel = jsonEncode(label);
  return '''
(() => {
  const label = $escapedLabel;
  const reportError = (error) => {
    const message = error && error.stack ? error.stack : error;
    console.error('[readflex-eval:' + label + ']', message);
  };

  try {
    const result = $expression;
    if (result && typeof result.then === 'function') {
      result.catch(reportError);
    }
  } catch (error) {
    reportError(error);
  }
  return null;
})();
''';
}

@visibleForTesting
String buildArticleTextDirectionPatchScript({
  required String textAlign,
  required bool justify,
}) {
  final escapedTextAlign = jsonEncode(textAlign);
  final escapedJustify = justify ? 'true' : 'false';
  return '''
(() => {
  const requestedTextAlign = $escapedTextAlign;
  const requestedJustify = $escapedJustify;
  const rtlSampleRegex = /[\u0590-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFF]/g;
  const ltrSampleRegex = /[A-Za-z\u00C0-\u024F\u1E00-\u1EFF]/g;

  const inferDirection = (doc) => {
    const sample = (doc.body?.textContent || '').replace(/\\s+/g, ' ').slice(0, 5000);
    if (!sample) return '';
    const rtlCount = (sample.match(rtlSampleRegex) || []).length;
    const ltrCount = (sample.match(ltrSampleRegex) || []).length;
    return rtlCount > ltrCount ? 'rtl' : '';
  };

  const resolveTextAlign = () => {
    const resolved = !requestedTextAlign || requestedTextAlign === 'auto'
      ? (requestedJustify ? 'justify' : 'start')
      : requestedTextAlign;
    if (resolved === 'start') return 'right';
    if (resolved === 'end') return 'left';
    return resolved;
  };

  const apply = () => {
    const view = document.querySelector('foliate-view');
    const renderer = view?.shadowRoot?.querySelector('foliate-paginator, foliate-fxl');
    const iframe = renderer?.shadowRoot?.querySelector('iframe');
    const doc = iframe?.contentDocument;
    if (!doc?.body) return false;

    const direction = doc.documentElement.dataset.readflexTextDirection
      || doc.documentElement.getAttribute('dir')
      || doc.body.getAttribute('dir')
      || inferDirection(doc);
    if (direction !== 'rtl') return false;

    doc.documentElement.dir = 'rtl';
    doc.documentElement.dataset.readflexTextDirection = 'rtl';
    doc.body.dir = 'rtl';

    let style = doc.getElementById('readflex-article-text-direction-runtime');
    if (!style) {
      style = doc.createElement('style');
      style.id = 'readflex-article-text-direction-runtime';
      doc.head?.append(style);
    }

    const align = resolveTextAlign();
    const selector = [
      'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
      'p', 'li', 'blockquote', 'dd', 'dt', 'figcaption', 'caption',
      'section', 'article', 'main', 'div:not(.readflex-wide-table)',
      'th', 'td',
    ].join(',');
    const nodes = Array.from(doc.body.querySelectorAll(selector));
    if (nodes.length === 0) nodes.push(doc.body);
    for (const node of nodes) {
      node.style.setProperty('direction', 'rtl', 'important');
      node.style.setProperty('unicode-bidi', 'plaintext');
      node.style.setProperty('text-align', align, 'important');
    }

    style.textContent = [
      'html[data-readflex-text-direction="rtl"] body h1,',
      'html[data-readflex-text-direction="rtl"] body h2,',
      'html[data-readflex-text-direction="rtl"] body h3,',
      'html[data-readflex-text-direction="rtl"] body h4,',
      'html[data-readflex-text-direction="rtl"] body h5,',
      'html[data-readflex-text-direction="rtl"] body h6,',
      'html[data-readflex-text-direction="rtl"] body p,',
      'html[data-readflex-text-direction="rtl"] body li,',
      'html[data-readflex-text-direction="rtl"] body blockquote,',
      'html[data-readflex-text-direction="rtl"] body dd,',
      'html[data-readflex-text-direction="rtl"] body dt,',
      'html[data-readflex-text-direction="rtl"] body figcaption,',
      'html[data-readflex-text-direction="rtl"] body caption,',
      'html[data-readflex-text-direction="rtl"] body section,',
      'html[data-readflex-text-direction="rtl"] body article,',
      'html[data-readflex-text-direction="rtl"] body main,',
      'html[data-readflex-text-direction="rtl"] body div:not(.readflex-wide-table),',
      'html[data-readflex-text-direction="rtl"] body th,',
      'html[data-readflex-text-direction="rtl"] body td {',
      '  direction: rtl !important;',
      '  unicode-bidi: plaintext;',
      '  text-align: ' + align + ' !important;',
      '}',
    ].join('\\n');
    if (!doc.documentElement.dataset.readflexRtlPatchLogged) {
      doc.documentElement.dataset.readflexRtlPatchLogged = 'true';
      console.log('[readflex-article-rtl] applied nodes=' + nodes.length + ' align=' + align);
    }
    return true;
  };

  apply();
  setTimeout(apply, 0);
  setTimeout(apply, 100);
  return null;
})()
''';
}
