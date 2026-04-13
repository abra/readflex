// Article reader bridge: fetches article HTML from local server,
// reports scroll position and text selection to Flutter.
//
// Communicates with Flutter via:
//   JS → Flutter: window.flutter_inappwebview.callHandler(name, data)
//   Flutter → JS: evaluateJavascript('functionName(args)')

(function () {
  'use strict';

  // ── State ──

  let _scrollDebounceTimer = null;
  const SCROLL_DEBOUNCE_MS = 200;

  // ── Init ──

  /** Called by Flutter after the WebView loads this page. */
  window.initArticle = function (articleHtml) {
    const container = document.getElementById('content');
    if (!container) return;

    container.innerHTML = articleHtml;
    _fixImages(container);
    _setupScrollTracking();
    _setupSelectionTracking();
    _callFlutter('onReady', {});
  };

  /**
   * Fixes common image issues after innerHTML injection:
   * - Moves data-src / data-lazy-src to src (lazy-loading placeholders)
   * - Removes loading="lazy" (IntersectionObserver may not fire)
   * - Removes srcset to force the browser to use src
   */
  function _fixImages(container) {
    var imgs = container.querySelectorAll('img');
    for (var i = 0; i < imgs.length; i++) {
      var img = imgs[i];

      // Prefer data-src over current src (many sites use 1x1 placeholder in src)
      var dataSrc = img.getAttribute('data-src') ||
                    img.getAttribute('data-lazy-src') ||
                    img.getAttribute('data-original');
      if (dataSrc) {
        img.setAttribute('src', dataSrc);
        img.removeAttribute('data-src');
        img.removeAttribute('data-lazy-src');
        img.removeAttribute('data-original');
      }

      // Remove lazy loading — it doesn't work reliably after innerHTML inject
      img.removeAttribute('loading');

      // Remove srcset to avoid resolution-selection issues in WebView
      img.removeAttribute('srcset');
      img.removeAttribute('data-srcset');
    }

    // Also fix <source> inside <picture>
    var sources = container.querySelectorAll('picture source');
    for (var j = 0; j < sources.length; j++) {
      var source = sources[j];
      var dataSrcset = source.getAttribute('data-srcset');
      if (dataSrcset) {
        source.setAttribute('srcset', dataSrcset);
        source.removeAttribute('data-srcset');
      }
    }
  }

  /** Called by Flutter to restore scroll position after content loads. */
  window.scrollToFraction = function (fraction) {
    const maxScroll = document.documentElement.scrollHeight - window.innerHeight;
    if (maxScroll <= 0) return;
    window.scrollTo({ top: maxScroll * fraction, behavior: 'instant' });
  };

  /** Called by Flutter when reader theme/font changes. */
  window.changeStyle = function (style) {
    const root = document.documentElement;
    if (style.fontFamily) root.style.setProperty('--reader-font-family', style.fontFamily);
    if (style.fontSize) root.style.setProperty('--reader-font-size', style.fontSize);
    if (style.lineHeight) root.style.setProperty('--reader-line-height', style.lineHeight);
    if (style.textColor) root.style.setProperty('--reader-text-color', style.textColor);
    if (style.bgColor) root.style.setProperty('--reader-bg-color', style.bgColor);
    if (style.accentColor) root.style.setProperty('--reader-accent-color', style.accentColor);
    if (style.secondaryColor) root.style.setProperty('--reader-secondary-color', style.secondaryColor);
    if (style.dividerColor) root.style.setProperty('--reader-divider-color', style.dividerColor);
    if (style.codeBgColor) root.style.setProperty('--reader-code-bg', style.codeBgColor);
    if (style.padding) root.style.setProperty('--reader-padding', style.padding);
  };

  /** Called by Flutter to render highlight overlays over matched text. */
  window.renderHighlights = function (highlights) {
    // Remove existing overlays.
    document.querySelectorAll('.reader-highlight').forEach(function (el) {
      const parent = el.parentNode;
      while (el.firstChild) parent.insertBefore(el.firstChild, el);
      parent.removeChild(el);
    });

    if (!highlights || highlights.length === 0) return;

    const container = document.getElementById('content');
    if (!container) return;

    highlights.forEach(function (h) {
      _highlightText(container, h.text, h.id);
    });
  };

  /** Called by Flutter to get the current scroll fraction. */
  window.getScrollFraction = function () {
    return _computeScrollFraction();
  };

  // ── Scroll tracking ──

  function _setupScrollTracking() {
    window.addEventListener('scroll', function () {
      if (_scrollDebounceTimer) clearTimeout(_scrollDebounceTimer);
      _scrollDebounceTimer = setTimeout(function () {
        _reportScroll();
      }, SCROLL_DEBOUNCE_MS);
    }, { passive: true });
  }

  function _reportScroll() {
    _callFlutter('onRelocated', {
      fraction: _computeScrollFraction(),
    });
  }

  function _computeScrollFraction() {
    const maxScroll = document.documentElement.scrollHeight - window.innerHeight;
    if (maxScroll <= 0) return 1.0;
    return Math.min(1.0, Math.max(0.0, window.scrollY / maxScroll));
  }

  // ── Selection tracking ──

  function _setupSelectionTracking() {
    document.addEventListener('selectionchange', function () {
      const sel = window.getSelection();
      if (!sel || sel.isCollapsed || !sel.toString().trim()) {
        _callFlutter('onSelectionCleared', {});
        return;
      }

      const text = sel.toString().trim();
      const range = sel.getRangeAt(0);
      const rect = range.getBoundingClientRect();

      _callFlutter('onSelectionEnd', {
        text: text,
        scrollOffset: _computeScrollFraction(),
        position: {
          left: rect.left,
          top: rect.top,
          right: rect.right,
          bottom: rect.bottom,
        },
      });
    });
  }

  // ── Highlight rendering ──

  function _highlightText(container, text, highlightId) {
    if (!text) return;

    const walker = document.createTreeWalker(
      container,
      NodeFilter.SHOW_TEXT,
      null,
    );

    let node;
    while ((node = walker.nextNode())) {
      const idx = node.textContent.indexOf(text);
      if (idx === -1) continue;

      const range = document.createRange();
      range.setStart(node, idx);
      range.setEnd(node, idx + text.length);

      const span = document.createElement('span');
      span.className = 'reader-highlight';
      span.dataset.highlightId = highlightId || '';
      span.addEventListener('click', function () {
        _callFlutter('onHighlightTap', { id: highlightId });
      });

      range.surroundContents(span);
      break; // First match only.
    }
  }

  // ── Flutter bridge ──

  function _callFlutter(name, data) {
    if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
      window.flutter_inappwebview.callHandler(name, data);
    }
  }
})();
