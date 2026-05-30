console.log('book.js')
console.log('ReadflexUA', navigator.userAgent)

import './view.js'
import { FootnoteHandler } from './footnotes.js'
import { Overlayer } from './overlayer.js'
import {
  attachGestures as readflexAttachGestures,
  registerGesture as readflexRegisterGesture,
} from './readflex_gestures.js'
import { applyTextContrastGuard } from './readflex_contrast_guard.js'
import { normalizeLoadedDocument } from './readflex_document_normalizer.js'
const { configure, ZipReader, BlobReader, TextWriter, BlobWriter } =
  await import('./vendor/zip.js')
const { EPUB } = await import('./epub.js')

var isPdf = false;

const getPosition = (target) => {
  const clamp01 = value => Math.min(Math.max(value, 0), 1);

  const frameRect = (framePos, elementRect, scaleX = 1, scaleY = 1) => {
    return {
      left: scaleX * elementRect.left + framePos.left,
      right: scaleX * elementRect.right + framePos.left,
      top: scaleY * elementRect.top + framePos.top,
      bottom: scaleY * elementRect.bottom + framePos.top
    };
  };
  const rootNode = target.getRootNode?.() ?? target?.endContainer?.getRootNode?.();
  const frameElement = rootNode?.defaultView?.frameElement;

  let scaleX = 1, scaleY = 1;
  if (frameElement) {
    const transform = getComputedStyle(frameElement).transform;
    const matches = transform.match(/matrix\((.+)\)/);
    if (matches) {
      [scaleX, , , scaleY] = matches[1].split(/\s*,\s*/).map(Number);
    }
  }

  const frame = frameElement?.getBoundingClientRect() ?? { top: 0, left: 0 };

  const rects = Array.from(target.getClientRects());
  if (!rects.length) {
    return {
      left: 0,
      top: 0,
      right: 0,
      bottom: 0
    };
  }
  const frameRects = rects.map(rect => frameRect(frame, rect, scaleX, scaleY));

  const boundingRect = frameRects.reduce((acc, rect) => ({
    left: Math.min(acc.left, rect.left),
    top: Math.min(acc.top, rect.top),
    right: Math.max(acc.right, rect.right),
    bottom: Math.max(acc.bottom, rect.bottom)
  }), { ...frameRects[0] });

  const screenWidth = window.innerWidth;
  const screenHeight = window.innerHeight;

  return {
    left: clamp01(boundingRect.left / screenWidth),
    top: clamp01(boundingRect.top / screenHeight),
    right: clamp01(boundingRect.right / screenWidth),
    bottom: clamp01(boundingRect.bottom / screenHeight)
  };
};

const getSelectionRange = (selection) => {
  if (!selection?.rangeCount) return null;
  const range = selection.getRangeAt(0);
  return range.collapsed ? null : range;
};

const unwrapCFI = cfi => cfi?.match(/^epubcfi\((.+)\)$/)?.[1] ?? cfi

const CONTEXT_WINDOW_CHARS = 120;
const MAX_CONTEXT_CHARS = 600;

const _collapseWhitespace = (text) =>
  typeof text === 'string'
    ? text.replace(/\s+/g, ' ').trim()
    : '';

const _sliceWithWindow = (text, start, end) => {
  if (!text) return '';
  const safeStart = Math.max(0, Math.min(text.length, start));
  const safeEnd = Math.max(safeStart, Math.min(text.length, end));
  return text.slice(safeStart, safeEnd);
};

const buildRangeContextText = (range) => {
  if (!range) return '';

  const selectionText = range.toString().trim();
  const startNode = range.startContainer;
  const endNode = range.endContainer;
  const startText = startNode?.textContent ?? '';
  const endText = endNode?.textContent ?? '';

  let contextText = '';

  if (startNode === endNode) {
    const segment = _sliceWithWindow(
      startText,
      range.startOffset - CONTEXT_WINDOW_CHARS,
      range.endOffset + CONTEXT_WINDOW_CHARS
    );
    contextText = _collapseWhitespace(segment);
  } else {
    const startSegment = _collapseWhitespace(
      _sliceWithWindow(
        startText,
        range.startOffset - CONTEXT_WINDOW_CHARS,
        range.startOffset + CONTEXT_WINDOW_CHARS
      )
    );
    const endSegment = _collapseWhitespace(
      _sliceWithWindow(
        endText,
        range.endOffset - CONTEXT_WINDOW_CHARS,
        range.endOffset + CONTEXT_WINDOW_CHARS
      )
    );
    const parts = [
      startSegment,
      selectionText,
      endSegment
    ].filter(Boolean);
    contextText = parts.join(' ');
  }

  if (!contextText && selectionText) {
    contextText = selectionText;
  }

  contextText = _collapseWhitespace(contextText);

  if (contextText.length > MAX_CONTEXT_CHARS) {
    return contextText.slice(0, MAX_CONTEXT_CHARS);
  }

  return contextText;
};

const handleSelection = (view, doc, index) => {
  const selection = doc.getSelection();
  const range = getSelectionRange(selection);

  if (!range) return;

  const position = getPosition(range);
  const cfi = view.getCFI(index, range);
  const lang = 'en-US'

  let text = selection.toString();
  if (!text) {
    const newSelection = range.startContainer.ownerDocument.getSelection();
    newSelection.removeAllRanges();
    newSelection.addRange(range);
    text = newSelection.toString();
  }

  const contextText = buildRangeContextText(range);

  onSelectionEnd({
    index,
    range,
    lang,
    cfi,
    pos: position,
    text,
    contextText
  });
};

const setSelectionHandler = (view, doc, index) => {
  let hasActiveSelection = false;
  let lastPointerUpRange = null;
  doc.__anxSelectionClearedAt = 0;
  doc.__anxSuppressClick = false;

  // Notify Flutter when the selection collapses so it can hide the context menu.
  const handleSelectionStateChange = () => {
    const selectionRange = getSelectionRange(doc.getSelection());
    if (selectionRange) {
      hasActiveSelection = true;
      doc.__anxSelectionClearedAt = 0;
      doc.__anxSuppressClick = false;
      return;
    }

    if (!hasActiveSelection) return;
    hasActiveSelection = false;
    lastPointerUpRange = null;
    doc.__anxSelectionClearedAt = Date.now();
    doc.__anxSuppressClick = true;
    callFlutter('onSelectionCleared');
  };

  doc.addEventListener('selectionchange', handleSelectionStateChange);

  const rangesEqual = (a, b) => (
    a.startContainer === b.startContainer
    && a.startOffset === b.startOffset
    && a.endContainer === b.endContainer
    && a.endOffset === b.endOffset
  );

  const shouldSkipPointerUp = () => {
    const selectionRange = getSelectionRange(doc.getSelection());
    if (!selectionRange) return false;

    if (lastPointerUpRange && rangesEqual(lastPointerUpRange, selectionRange)) {
      return true;
    }

    lastPointerUpRange = selectionRange.cloneRange();
    return false;
  };

  //    doc.addEventListener('pointerdown', () => isSelecting = true);
  // if macos or iOS
  if (navigator.platform.includes('Mac')
    || navigator.platform.includes('iPhone')
    || navigator.platform.includes('iPad')
  ) {
    doc.addEventListener('pointerup', () => {
      if (shouldSkipPointerUp()) return;
      handleSelection(view, doc, index);
    });
  }
  else if (navigator.platform.includes('Win')) {
    if (navigator.maxTouchPoints > 0) {
      // In Edge, the longpress by touch generates following touch event sequence:
      // pointerover -> enter -> down -> move(n) -> cancel -> out -> leave
      // While on the flutter webview, it generates:
      // pointerover -> enter -> down -> move(n) -> up -> out -> leave
      // Besides above event difference (cancle/up),
      // the touch event is not triggered when change text selection range.
      // Thus cannot use pointerup to detect the end of touch selection.
      // Instead, we use selectionchange event to detect the end of touch selection
      // for Edge and flutter webview.

      // for mouse pointerup, handle selection directly
      doc.addEventListener('pointerup', (e) => {
        if (e.pointerType === 'touch') return;
        if (shouldSkipPointerUp()) return;
        handleSelection(view, doc, index);
      });

      // filter out selectionchange event cause by mouse
      var isMouseSelecting = false;
      doc.addEventListener('pointerdown', (e) => {
        if (e.pointerType !== 'mouse') return;
        isMouseSelecting = true;
      });
      doc.addEventListener('pointerup', (e) => {
        if (e.pointerType !== 'mouse') return;
        isMouseSelecting = false;
      });

      var debounceTimerId = undefined;
      doc.addEventListener('selectionchange', () => {
        if (isMouseSelecting) return;

        const selRange = getSelectionRange(doc.getSelection())
        if (!selRange) return;

        clearTimeout(debounceTimerId);
        let delay = 500;
        debounceTimerId = setTimeout(() => {
          handleSelection(view, doc, index);
        }, delay);
      });

    } else {
      doc.addEventListener('pointerup', () => {
        if (shouldSkipPointerUp()) return;
        handleSelection(view, doc, index);
      });
    }
  }

  else {
    doc.addEventListener('contextmenu', e => {
      // if (e.pointerType === 'mouse') {
      handleSelection(view, doc, index);
      // }
    });

    if (navigator.userAgent.includes('Phone; OpenHarmony')) {
      let debounceTimerId;
      doc.addEventListener('selectionchange', () => {
        const selRange = getSelectionRange(doc.getSelection());
        if (!selRange) return;

        clearTimeout(debounceTimerId);
        debounceTimerId = setTimeout(() => {
          handleSelection(view, doc, index);
        }, 500);
      });
    }
  }
  // doc.addEventListener('selectionchange', () => handleSelection(view, doc, index));

  if (!view.isFixedLayout) {
    // go to the next page when selecting to the end of a page
    // this makes it possible to select across pages

    doc.addEventListener('selectstart', () => {
      const container = view.shadowRoot.querySelector('foliate-paginator').shadowRoot.querySelector("#container");
      if (!container) return;
      globalThis.originalScrollLeft = container.scrollLeft;
    });


    doc.addEventListener('selectionchange', () => {
      if (view.renderer.getAttribute('flow') !== 'paginated') return
      const { lastLocation } = view
      if (!lastLocation) return

      const selRange = getSelectionRange(doc.getSelection())
      if (!selRange) return

      if (globalThis.pageDebounceTimer) {
        clearTimeout(globalThis.pageDebounceTimer);
        globalThis.pageDebounceTimer = null;
      }

      const container = view.shadowRoot.querySelector('foliate-paginator').shadowRoot.querySelector("#container");

      if (selRange.compareBoundaryPoints(Range.END_TO_END, lastLocation.range) >= 0) {
        globalThis.pageDebounceTimer = setTimeout(async () => {
          await view.next();
          globalThis.originalScrollLeft = container.scrollLeft;
          globalThis.pageDebounceTimer = null;
        }, 1000);
        return
      }

      const preventScroll = () => {
        const selRange = getSelectionRange(doc.getSelection());
        if (!selRange || !view.lastLocation || !view.lastLocation.range) return;

        if (view.lastLocation.range.startContainer === selRange.endContainer) {
          container.scrollLeft = globalThis.originalScrollLeft;
        }
      };

      container.addEventListener('scroll', preventScroll);

      doc.addEventListener('pointerup', () => {
        container.removeEventListener('scroll', preventScroll);
      }, { once: true });
    })

  }
}
const isZip = async file => {
  const arr = new Uint8Array(await file.slice(0, 4).arrayBuffer())
  return arr[0] === 0x50 && arr[1] === 0x4b && arr[2] === 0x03 && arr[3] === 0x04
}

const isPDF = async file => {
  const arr = new Uint8Array(await file.slice(0, 5).arrayBuffer())
  return arr[0] === 0x25
    && arr[1] === 0x50 && arr[2] === 0x44 && arr[3] === 0x46
    && arr[4] === 0x2d
}

const makeZipLoader = async file => {
  configure({ useWebWorkers: false })
  const reader = new ZipReader(new BlobReader(file))
  const entries = await reader.getEntries()
  const map = new Map(entries.map(entry => [entry.filename, entry]))
  const load = f => (name, ...args) =>
    map.has(name) ? f(map.get(name), ...args) : null
  const loadText = load(entry => entry.getData(new TextWriter()))
  const loadBlob = load((entry, type) => entry.getData(new BlobWriter(type)))
  const getSize = name => map.get(name)?.uncompressedSize ?? 0
  return { entries, loadText, loadBlob, getSize }
}

const getFileEntries = async entry => entry.isFile ? entry
  : (await Promise.all(Array.from(
    await new Promise((resolve, reject) => entry.createReader()
      .readEntries(entries => resolve(entries), error => reject(error))),
    getFileEntries))).flat()

const makeDirectoryLoader = async entry => {
  const entries = await getFileEntries(entry)
  const files = await Promise.all(
    entries.map(entry => new Promise((resolve, reject) =>
      entry.file(file => resolve([file, entry.fullPath]),
        error => reject(error)))))
  const map = new Map(files.map(([file, path]) =>
    [path.replace(entry.fullPath + '/', ''), file]))
  const decoder = new TextDecoder()
  const decode = x => x ? decoder.decode(x) : null
  const getBuffer = name => map.get(name)?.arrayBuffer() ?? null
  const loadText = async name => decode(await getBuffer(name))
  const loadBlob = name => map.get(name)
  const getSize = name => map.get(name)?.size ?? 0
  return { loadText, loadBlob, getSize }
}

const isCBZ = ({ name, type }) =>
  type === 'application/vnd.comicbook+zip' || name.endsWith('.cbz')

const isFB2 = ({ name, type }) =>
  type === 'application/x-fictionbook+xml' || name.endsWith('.fb2')

const isFBZ = ({ name, type }) =>
  type === 'application/x-zip-compressed-fb2'
  || name.endsWith('.fb2.zip') || name.endsWith('.fbz')

const getView = async file => {
  let book
  if (file.isDirectory) {
    const loader = await makeDirectoryLoader(file)
    const { EPUB } = await import('./epub.js')
    book = await new EPUB(loader).init()
  }
  else if (!file.size) throw new Error('File not found')
  else if (await isZip(file)) {
    const loader = await makeZipLoader(file)
    if (isCBZ(file)) {
      const { makeComicBook } = await import('./comic-book.js')
      book = makeComicBook(loader, file)
    } else if (isFBZ(file)) {
      const { makeFB2 } = await import('./fb2.js')
      const { entries } = loader
      const entry = entries.find(entry => entry.filename.endsWith('.fb2'))
      const blob = await loader.loadBlob((entry ?? entries[0]).filename)
      book = await makeFB2(blob)
    } else {
      book = await new EPUB(loader).init()
    }
  }
  else if (await isPDF(file)) {
    isPdf = true;
    const { makePDF } = await import('./pdf.js')
    book = await makePDF(file)
  }
  else {
    const { isMOBI, MOBI } = await import('./mobi.js')
    if (await isMOBI(file)) {
      const fflate = await import('./vendor/fflate.js')
      book = await new MOBI({ unzlib: fflate.unzlibSync }).open(file)
    } else if (isFB2(file)) {
      const { makeFB2 } = await import('./fb2.js')
      book = await makeFB2(file)
    }
  }
  if (!book) throw new Error('File type not supported')
  const view = document.createElement('foliate-view')
  document.body.append(view)
  await view.open(book)
  return view
}

const escapeCSSString = value => value
  .replaceAll('\\', '\\\\')
  .replaceAll('"', '\\"')

const quoteFontFamily = value => `"${escapeCSSString(value)}"`

const getFontFamilyToken = fontName =>
  fontName === 'system' ? 'system-ui' : quoteFontFamily(fontName)

const getReaderStylePrelude = ({ fontSize,
  textScale = 1,
  fontName,
  fontPath,
  fontWeight,
  letterSpacing,
  spacing,
  textIndent,
  paragraphSpacing,
  fontColor,
  backgroundColor,
  justify,
  textAlign,
  hyphenate,
  writingMode,
  backgroundImage,
  flow,
  customCSS,
  customCSSEnabled,
  overrideFont = true,
  overrideColor = true,
  useBookLayout = true,
}) => {
  const fontFaceDecl =
    !fontName || fontName === 'book' || fontName === 'system' || !fontPath
      ? ''
      : `
    @font-face {
      font-family: ${quoteFontFamily(fontName)};
      src: url('${fontPath}');
      font-display: swap;
    }`

  const fontFamilyVarDecl = !overrideFont || fontName === 'book'
    ? ''
    : `--readflex-font-family: ${getFontFamilyToken(fontName)};`
  const safeFontSize = Number(fontSize) || 1
  const safeTextScale = Number(textScale) || 1
  const rootFontSizePx = 16 * safeFontSize
  const proseFontSizePx = rootFontSizePx * safeTextScale
  const inlineCodeFontSizePx = rootFontSizePx * 0.9
  const kbdFontSizePx = rootFontSizePx * 0.85
  const codeBlockFontSizePx = rootFontSizePx * 0.875

  const resolvedTextAlign = !textAlign || textAlign === 'auto'
    ? (justify ? 'justify' : 'start')
    : textAlign
  const rtlArticleTextAlign = resolvedTextAlign === 'start'
    ? 'right'
    : resolvedTextAlign === 'end'
      ? 'left'
      : resolvedTextAlign

  return `
    ${fontFaceDecl}
    :root {
      ${fontFamilyVarDecl}
      --readflex-font-size: ${fontSize}em;
      --readflex-text-scale: ${safeTextScale};
      --readflex-prose-font-size: ${proseFontSizePx}px;
      --readflex-inline-code-font-size: ${inlineCodeFontSizePx}px;
      --readflex-kbd-font-size: ${kbdFontSizePx}px;
      --readflex-code-block-font-size: ${codeBlockFontSizePx}px;
      --readflex-letter-spacing: ${letterSpacing}px;
      --readflex-line-height: ${spacing};
      --readflex-text-indent: ${textIndent}em;
      --readflex-paragraph-spacing: ${paragraphSpacing / 2}em;
      --readflex-font-color: ${fontColor};
      --readflex-background-color: ${backgroundColor};
      --readflex-font-weight: ${fontWeight};
      --readflex-text-align: ${resolvedTextAlign};
      --readflex-rtl-article-text-align: ${rtlArticleTextAlign};
      --readflex-hyphens: ${hyphenate ? 'auto' : 'manual'};
    }`
}

// Three override flags let callers decide whether reader preferences beat
// publisher CSS:
//   overrideFont   — force font-family and font-weight
//   overrideColor  — force text color (accent links live in customCSS instead)
//   useBookLayout  — force line-height, text-indent, hyphenation, margins
// When a flag is false, the corresponding rules are omitted and the book's
// own CSS wins. Defaults preserve the historical "override everything" behavior.
const getCSS = style => {
  const {
    fontName,
    backgroundImage,
    flow,
    customCSS,
    customCSSEnabled,
    overrideFont = true,
    overrideColor = true,
    useBookLayout = true,
    writingMode,
  } = style
  const fontFamilyDecl = !overrideFont || fontName === 'book' ? '' :
    'font-family: var(--readflex-font-family) !important;'

  const writingModeDecl = writingMode === 'auto' ? '' : `writing-mode: ${writingMode} !important;`

  const backgroundImageDecl = !backgroundImage || flow || backgroundImage === 'none' ? 'background: none !important;' :
    `background-image: url('${backgroundImage}') !important;
    background-size: 100% 100% !important;
    background-repeat: repeat !important;
    background-attachment: scroll !important;
    background-position: center center !important;
    background-clip: content-box !important;`

  const htmlColorDecl = overrideColor ? 'color: var(--readflex-font-color) !important;' : ''
  const paraColorDecl = overrideColor ? 'color: var(--readflex-font-color) !important;' : ''
  const paraFontWeightDecl = overrideFont ? 'font-weight: var(--readflex-font-weight) !important;' : ''
  const headingLineHeightDecl = useBookLayout ? 'line-height: var(--readflex-line-height) !important;' : ''
  const paraLayoutDecl = useBookLayout ? `
        line-height: var(--readflex-line-height) !important;
        text-indent: var(--readflex-text-indent) !important;
        -webkit-hyphens: var(--readflex-hyphens);
        hyphens: var(--readflex-hyphens);
        -webkit-hyphenate-limit-before: 3;
        -webkit-hyphenate-limit-after: 2;
        -webkit-hyphenate-limit-lines: 2;
        hanging-punctuation: allow-end last;
        widows: 2;
        margin-block-start: var(--readflex-paragraph-spacing) !important;
        margin-block-end: var(--readflex-paragraph-spacing) !important;` : ''

  // Some CSS selectors are inspired by https://github.com/readest/foliate-js
  return [getReaderStylePrelude(style), `
    @namespace epub "http://www.idpf.org/2007/ops";

    html {
        ${writingModeDecl}
        ${htmlColorDecl}
        ${backgroundImageDecl}
        background-color: var(--readflex-background-color) !important;
        letter-spacing: var(--readflex-letter-spacing);
        font-size: var(--readflex-font-size);
        orphans: 1;
        widows: 1;
    }

    body {
        background-image: none !important;
        background-color: var(--readflex-background-color) !important;
        padding: 0;
    }

    /* Readflex patch: many EPUBs wrap content in <body><div class="container"
       style="padding: 5%">...</div></body> or <body><section>...</section></body>
       with publisher-defined inline padding. Body itself is locked to padding:0
       in paginator's columnize(), but inner wrappers add a second layer of edge
       spacing — visibly wider text margins on those books than on others.
       Reset only the horizontal padding/margin (inline-axis); vertical (block)
       is preserved because publishers use it intentionally for chapter headers
       and section breaks. */
    body > div,
    body > section,
    body > article,
    body > main {
        padding-inline-start: 0 !important;
        padding-inline-end: 0 !important;
        margin-inline-start: 0 !important;
        margin-inline-end: 0 !important;
    }

    body > div:only-of-type,
    body > div:only-of-type > div:only-of-type {
        overflow: visible !important;
    }

    img, svg, canvas, video {
        max-inline-size: 100% !important;
        max-block-size: 100% !important;
        inline-size: auto;
        block-size: auto;
        object-fit: contain !important;
        break-inside: avoid !important;
        box-sizing: border-box !important;
        font-size: initial !important;
    }

    iframe, object, embed {
        max-inline-size: 100% !important;
        box-sizing: border-box !important;
    }

    a > img {
        font-size: var(--readflex-font-size) !important;
    }

    /* Readflex Level-2 typography reset: beat publisher CSS like
       "body { font-family: ... !important }" by listing element-level
       selectors with the same specificity (0,0,0,1) — our rules come
       last in source order so they win on ties. */
    html, body,
    p, li, blockquote, dd, dt, dl, div, span, font, section, article,
    h1, h2, h3, h4, h5, h6,
    td, th, caption, ol, ul {
        ${fontFamilyDecl}
    }

    /* Anchor only the body font-size, not paragraph elements.
       Some Calibre conversions wrap content in a body class like
       ".calibre1 { font-size: 0.75em }" which shrinks the whole
       book. Other Calibre conversions instead use ".calibre3" on
       block-level paragraphs to enlarge text — those should keep
       working, which is why this rule is body-only. The user-
       controlled scale lives as inline style on html and wins by
       specificity, so we only need to neutralise the body layer. */
    body {
        font-size: 1em !important;
    }

    h1, h2, h3, h4, h5, h6 {
        ${headingLineHeightDecl}
    }

    p, li, blockquote, dd, div:not(:has(*:not(b, a, em, i, strong, u, span))), font {
        ${paraColorDecl}
        ${paraFontWeightDecl}
        /* !important so publisher rules like "p { text-align: left !important }"
           do not override the user-selected justify. The [align="..."] rules
           below are also bumped to !important so old-school
           "p align=center" chapter titles still center over justify. */
        text-align: var(--readflex-text-align) !important;
        ${paraLayoutDecl}
    }

    .anx-text-center,
    [align="center"],
    [style*="text-align: center"],
    [style*="text-align:center"] {
        text-indent: 0 !important;
    }


    /*  Paragraphs containing only an image — don't change */
    p:has(> img:only-child),
    p:has(> span:only-child > img:only-child),
    p:has(> img:not(.has-text-siblings)),
    p:has(> a:first-child + img:last-child),
    div:has(> img:only-child),
    div:has(> span:only-child > img:only-child),
    div:has(> img:not(.has-text-siblings)),
    div:has(> a:first-child + img:last-child)  {
        text-indent: initial !important;
        font-size: initial !important;
        height: initial !important;
        width: initial !important;
    }

    /*  Paragraphs inside list items — prevent double indentation */
    li > p,
    ol > p,
    ul > p {
        text-indent: 0 !important;
    }
        
    /* Preserve old-school HTML "align" attribute (centered chapter
       titles, dedications). !important so it wins over our paragraph-
       level justify rule above. */
    [align="left"] { text-align: left !important; }
    [align="right"] { text-align: right !important; }
    [align="center"] { text-align: center !important; }
    [align="justify"] { text-align: justify !important; }

    pre {
        white-space: pre-wrap !important;
    }
    aside[epub|type~="endnote"],
    aside[epub|type~="footnote"],
    aside[epub|type~="note"],
    aside[epub|type~="rearnote"] {
        display: none;
    }
    
    ${customCSSEnabled && customCSS ? customCSS : ''}
`]
}

const convertChineseHandler = (mode, doc) => {
  console.log('convertChinese', mode)
  const zh_s = '皑蔼碍爱翱袄奥坝罢摆败颁办绊帮绑镑谤剥饱宝报鲍辈贝钡狈备惫绷笔毕毙闭边编贬变辩辫鳖瘪濒滨宾摈饼拨钵铂驳卜补参蚕残惭惨灿苍舱仓沧厕侧册测层诧搀掺蝉馋谗缠铲产阐颤场尝长偿肠厂畅钞车彻尘陈衬撑称惩诚骋痴迟驰耻齿炽冲虫宠畴踌筹绸丑橱厨锄雏础储触处传疮闯创锤纯绰辞词赐聪葱囱从丛凑窜错达带贷担单郸掸胆惮诞弹当挡党荡档捣岛祷导盗灯邓敌涤递缔点垫电淀钓调迭谍叠钉顶锭订东动栋冻斗犊独读赌镀锻断缎兑队对吨顿钝夺鹅额讹恶饿儿尔饵贰发罚阀珐矾钒烦范贩饭访纺飞废费纷坟奋愤粪丰枫锋风疯冯缝讽凤肤辐抚辅赋复负讣妇缚该钙盖干赶秆赣冈刚钢纲岗皋镐搁鸽阁铬个给龚宫巩贡钩沟构购够蛊顾剐关观馆惯贯广规硅归龟闺轨诡柜贵刽辊滚锅国过骇韩汉阂鹤贺横轰鸿红后壶护沪户哗华画划话怀坏欢环还缓换唤痪焕涣黄谎挥辉毁贿秽会烩汇讳诲绘荤浑伙获货祸击机积饥讥鸡绩缉极辑级挤几蓟剂济计记际继纪夹荚颊贾钾价驾歼监坚笺间艰缄茧检碱硷拣捡简俭减荐槛鉴践贱见键舰剑饯渐溅涧浆蒋桨奖讲酱胶浇骄娇搅铰矫侥脚饺缴绞轿较秸阶节茎惊经颈静镜径痉竞净纠厩旧驹举据锯惧剧鹃绢杰洁结诫届紧锦仅谨进晋烬尽劲荆觉决诀绝钧军骏开凯颗壳课垦恳抠库裤夸块侩宽矿旷况亏岿窥馈溃扩阔蜡腊莱来赖蓝栏拦篮阑兰澜谰揽览懒缆烂滥捞劳涝乐镭垒类泪篱离里鲤礼丽厉励砾历沥隶俩联莲连镰怜涟帘敛脸链恋炼练粮凉两辆谅疗辽镣猎临邻鳞凛赁龄铃凌灵岭领馏刘龙聋咙笼垄拢陇楼娄搂篓芦卢颅庐炉掳卤虏鲁赂禄录陆驴吕铝侣屡缕虑滤绿峦挛孪滦乱抡轮伦仑沦纶论萝罗逻锣箩骡骆络妈玛码蚂马骂吗买麦卖迈脉瞒馒蛮满谩猫锚铆贸么霉没镁门闷们锰梦谜弥觅绵缅庙灭悯闽鸣铭谬谋亩钠纳难挠脑恼闹馁腻撵捻酿鸟聂啮镊镍柠狞宁拧泞钮纽脓浓农疟诺欧鸥殴呕沤盘庞国爱赔喷鹏骗飘频贫苹凭评泼颇扑铺朴谱脐齐骑岂启气弃讫牵扦钎铅迁签谦钱钳潜浅谴堑枪呛墙蔷强抢锹桥乔侨翘窍窃钦亲轻氢倾顷请庆琼穷趋区躯驱龋颧权劝却鹊让饶扰绕热韧认纫荣绒软锐闰润洒萨鳃赛伞丧骚扫涩杀纱筛晒闪陕赡缮伤赏烧绍赊摄慑设绅审婶肾渗声绳胜圣师狮湿诗尸时蚀实识驶势释饰视试寿兽枢输书赎属术树竖数帅双谁税顺说硕烁丝饲耸怂颂讼诵擞苏诉肃虽绥岁孙损笋缩琐锁獭挞抬摊贪瘫滩坛谭谈叹汤烫涛绦腾誊锑题体屉条贴铁厅听烃铜统头图涂团颓蜕脱鸵驮驼椭洼袜弯湾顽万网韦违围为潍维苇伟伪纬谓卫温闻纹稳问瓮挝蜗涡窝呜钨乌诬无芜吴坞雾务误锡牺袭习铣戏细虾辖峡侠狭厦锨鲜纤咸贤衔闲显险现献县馅羡宪线厢镶乡详响项萧销晓啸蝎协挟携胁谐写泻谢锌衅兴汹锈绣虚嘘须许绪续轩悬选癣绚学勋询寻驯训讯逊压鸦鸭哑亚讶阉烟盐严颜阎艳厌砚彦谚验鸯杨扬疡阳痒养样瑶摇尧遥窑谣药爷页业叶医铱颐遗仪彝蚁艺亿忆义诣议谊译异绎荫阴银饮樱婴鹰应缨莹萤营荧蝇颖哟拥佣痈踊咏涌优忧邮铀犹游诱舆鱼渔娱与屿语吁御狱誉预驭鸳渊辕园员圆缘远愿约跃钥岳粤悦阅云郧匀陨运蕴酝晕韵杂灾载攒暂赞赃脏凿枣灶责择则泽贼赠扎札轧铡闸诈斋债毡盏斩辗崭栈战绽张涨帐账胀赵蛰辙锗这贞针侦诊镇阵挣睁狰帧郑证织职执纸挚掷帜质钟终种肿众诌轴皱昼骤猪诸诛烛瞩嘱贮铸筑驻专砖转赚桩庄装妆壮状锥赘坠缀谆浊兹资渍踪综总纵邹诅组钻致钟么为只凶准启板里雳余链泄';
  const zh_t = '皚藹礙愛翺襖奧壩罷擺敗頒辦絆幫綁鎊謗剝飽寶報鮑輩貝鋇狽備憊繃筆畢斃閉邊編貶變辯辮鼈癟瀕濱賓擯餅撥缽鉑駁蔔補參蠶殘慚慘燦蒼艙倉滄廁側冊測層詫攙摻蟬饞讒纏鏟産闡顫場嘗長償腸廠暢鈔車徹塵陳襯撐稱懲誠騁癡遲馳恥齒熾沖蟲寵疇躊籌綢醜櫥廚鋤雛礎儲觸處傳瘡闖創錘純綽辭詞賜聰蔥囪從叢湊竄錯達帶貸擔單鄲撣膽憚誕彈當擋黨蕩檔搗島禱導盜燈鄧敵滌遞締點墊電澱釣調叠諜疊釘頂錠訂東動棟凍鬥犢獨讀賭鍍鍛斷緞兌隊對噸頓鈍奪鵝額訛惡餓兒爾餌貳發罰閥琺礬釩煩範販飯訪紡飛廢費紛墳奮憤糞豐楓鋒風瘋馮縫諷鳳膚輻撫輔賦複負訃婦縛該鈣蓋幹趕稈贛岡剛鋼綱崗臯鎬擱鴿閣鉻個給龔宮鞏貢鈎溝構購夠蠱顧剮關觀館慣貫廣規矽歸龜閨軌詭櫃貴劊輥滾鍋國過駭韓漢閡鶴賀橫轟鴻紅後壺護滬戶嘩華畫劃話懷壞歡環還緩換喚瘓煥渙黃謊揮輝毀賄穢會燴彙諱誨繪葷渾夥獲貨禍擊機積饑譏雞績緝極輯級擠幾薊劑濟計記際繼紀夾莢頰賈鉀價駕殲監堅箋間艱緘繭檢堿鹼揀撿簡儉減薦檻鑒踐賤見鍵艦劍餞漸濺澗漿蔣槳獎講醬膠澆驕嬌攪鉸矯僥腳餃繳絞轎較稭階節莖驚經頸靜鏡徑痙競淨糾廄舊駒舉據鋸懼劇鵑絹傑潔結誡屆緊錦僅謹進晉燼盡勁荊覺決訣絕鈞軍駿開凱顆殼課墾懇摳庫褲誇塊儈寬礦曠況虧巋窺饋潰擴闊蠟臘萊來賴藍欄攔籃闌蘭瀾讕攬覽懶纜爛濫撈勞澇樂鐳壘類淚籬離裏鯉禮麗厲勵礫曆瀝隸倆聯蓮連鐮憐漣簾斂臉鏈戀煉練糧涼兩輛諒療遼鐐獵臨鄰鱗凜賃齡鈴淩靈嶺領餾劉龍聾嚨籠壟攏隴樓婁摟簍蘆盧顱廬爐擄鹵虜魯賂祿錄陸驢呂鋁侶屢縷慮濾綠巒攣孿灤亂掄輪倫侖淪綸論蘿羅邏鑼籮騾駱絡媽瑪碼螞馬罵嗎買麥賣邁脈瞞饅蠻滿謾貓錨鉚貿麽黴沒鎂門悶們錳夢謎彌覓綿緬廟滅憫閩鳴銘謬謀畝鈉納難撓腦惱鬧餒膩攆撚釀鳥聶齧鑷鎳檸獰甯擰濘鈕紐膿濃農瘧諾歐鷗毆嘔漚盤龐國愛賠噴鵬騙飄頻貧蘋憑評潑頗撲鋪樸譜臍齊騎豈啓氣棄訖牽扡釺鉛遷簽謙錢鉗潛淺譴塹槍嗆牆薔強搶鍬橋喬僑翹竅竊欽親輕氫傾頃請慶瓊窮趨區軀驅齲顴權勸卻鵲讓饒擾繞熱韌認紉榮絨軟銳閏潤灑薩鰓賽傘喪騷掃澀殺紗篩曬閃陝贍繕傷賞燒紹賒攝懾設紳審嬸腎滲聲繩勝聖師獅濕詩屍時蝕實識駛勢釋飾視試壽獸樞輸書贖屬術樹豎數帥雙誰稅順說碩爍絲飼聳慫頌訟誦擻蘇訴肅雖綏歲孫損筍縮瑣鎖獺撻擡攤貪癱灘壇譚談歎湯燙濤縧騰謄銻題體屜條貼鐵廳聽烴銅統頭圖塗團頹蛻脫鴕馱駝橢窪襪彎灣頑萬網韋違圍爲濰維葦偉僞緯謂衛溫聞紋穩問甕撾蝸渦窩嗚鎢烏誣無蕪吳塢霧務誤錫犧襲習銑戲細蝦轄峽俠狹廈鍁鮮纖鹹賢銜閑顯險現獻縣餡羨憲線廂鑲鄉詳響項蕭銷曉嘯蠍協挾攜脅諧寫瀉謝鋅釁興洶鏽繡虛噓須許緒續軒懸選癬絢學勳詢尋馴訓訊遜壓鴉鴨啞亞訝閹煙鹽嚴顔閻豔厭硯彥諺驗鴦楊揚瘍陽癢養樣瑤搖堯遙窯謠藥爺頁業葉醫銥頤遺儀彜蟻藝億憶義詣議誼譯異繹蔭陰銀飲櫻嬰鷹應纓瑩螢營熒蠅穎喲擁傭癰踴詠湧優憂郵鈾猶遊誘輿魚漁娛與嶼語籲禦獄譽預馭鴛淵轅園員圓緣遠願約躍鑰嶽粵悅閱雲鄖勻隕運蘊醞暈韻雜災載攢暫贊贓髒鑿棗竈責擇則澤賊贈紮劄軋鍘閘詐齋債氈盞斬輾嶄棧戰綻張漲帳賬脹趙蟄轍鍺這貞針偵診鎮陣掙睜猙幀鄭證織職執紙摯擲幟質鍾終種腫衆謅軸皺晝驟豬諸誅燭矚囑貯鑄築駐專磚轉賺樁莊裝妝壯狀錐贅墜綴諄濁茲資漬蹤綜總縱鄒詛組鑽緻鐘麼為隻兇準啟闆裡靂餘鍊洩';

  const from = mode === 's2t' ? zh_s : zh_t
  const to = mode === 's2t' ? zh_t : zh_s




  const convertTextNode = (node, from, to) => {
    if (node.nodeType === Node.TEXT_NODE) {
      node.textContent = node.textContent.replace(/[\u4e00-\u9fa5]/g, (match) => {
        return to[from.indexOf(match)] ?? match
      });
    } else {
      node.childNodes.forEach(child => convertTextNode(child, from, to));
    }
  };

  doc.body.childNodes.forEach(node => {
    convertTextNode(node, from, to);
  });
}

const bionicReadingHandler = (doc) => {

  return;

};

const applyReaderContrastGuard = doc => {
  applyTextContrastGuard(doc, {
    backgroundColor: style.backgroundColor,
    textColor: style.fontColor,
  })
}

const rendererWritingMode = () => {
  const value = reader?.view?.renderer?.writingMode
  return typeof value === 'string' && value ? value : 'horizontal-tb'
}

const isVerticalWritingMode = value =>
  typeof value === 'string' && value.startsWith('vertical')

const readingFeaturesDocHandler = (doc) => {
  if (readingRules.convertChineseMode !== 'none') {
    convertChineseHandler(readingRules.convertChineseMode, doc)
  }
  if (readingRules.bionicReadingMode) {
    bionicReadingHandler(doc)
  }

  // handle text indent and center alignment
  if (style.textIndent > 0) {
    const elements = doc.querySelectorAll('p, div, li, blockquote, dd, font')
    elements.forEach(el => {
      const computedStyle = window.getComputedStyle(el)
      if (computedStyle.textAlign === 'center') {
        el.classList.add('anx-text-center')
      }
    })
  }

  // handle vertical writing mode, replace “”‘’ with 『』「」
  if (isVerticalWritingMode(style.writingMode) || isVerticalWritingMode(rendererWritingMode())) {
    const replaceQuotes = (node) => {
      if (node.nodeType === Node.TEXT_NODE) {
        node.textContent = node.textContent
          .replace(/“/g, '『')
          .replace(/”/g, '』')
          .replace(/‘/g, '「')
          .replace(/’/g, '」');
      } else {
        node.childNodes.forEach(child => replaceQuotes(child));
      }
    };
    doc.body.childNodes.forEach(node => {
      replaceQuotes(node);
    });
  }
}


const footnoteDialog = document.getElementById('footnote-dialog')
footnoteDialog.style.display = 'none'

const isFootnoteDialogOpen = () =>
  footnoteDialog.style.display === 'block' || footnoteDialog.hasAttribute('open')

const openFootnoteDialog = () => {
  if (typeof footnoteDialog.showModal === 'function') {
    if (!footnoteDialog.open) footnoteDialog.showModal()
  } else {
    footnoteDialog.setAttribute('open', '')
  }
  footnoteDialog.style.display = 'block'
}

const closeFootnoteDialog = () => {
  if (typeof footnoteDialog.close === 'function' && footnoteDialog.open) {
    footnoteDialog.close()
  }
  footnoteDialog.removeAttribute('open')
  footnoteDialog.style.display = 'none'
  callFlutter("onFootnoteClose")
}

footnoteDialog.addEventListener('click', e => {
  if (e.target === footnoteDialog) closeFootnoteDialog()
})

const replaceFootnote = (view) => {
  clearSelection()
  footnoteDialog.querySelector('main').replaceChildren(view)

  view.addEventListener('load', (e) => {
    const { doc, index } = e.detail
    globalThis.footnoteSelection = () => handleSelection(view, doc, index)
    setSelectionHandler(view, doc, index)
    // convertChineseHandler(convertChineseMode, doc)
    readingFeaturesDocHandler(doc)
    applyReaderContrastGuard(doc)
    doc.__isFootNote = true


    setTimeout(() => {
      const dialog = document.getElementById('footnote-dialog')
      const content = document.querySelector("#footnote-dialog > main > foliate-view")
        .shadowRoot.querySelector("foliate-paginator")
        .shadowRoot.querySelector("#container > div > iframe")

      openFootnoteDialog()

      // dialog.style.width = 'auto'
      // dialog.style.height = 'auto'

      // const contentWidth = content.clientWidth
      // const contentHeight = content.clientHeight

      // const squareSize = contentWidth * contentHeight

      // dialog.style.height = 100 + 'px'
      // dialog.style.width = squareSize / 100 + 'px'

      // if (squareSize > window.innerWidth * 100 * 0.8) {
      //   dialog.style.width = window.innerWidth * 0.8 + 'px'
      //   dialog.style.height = squareSize / (window.innerWidth * 3.0) + 'px'
      // }

      //dialog.style.width = `${Math.min(Math.max(contentWidth, 200), window.innerWidth * 0.8)}px`
      //dialog.style.height = `${Math.min(Math.max(contentHeight, 100), window.innerHeight * 0.8)}px`
    }, 0)
  })

  const { renderer } = view
  renderer.setAttribute('flow', 'scrolled')
  renderer.setAttribute('gap', '5%')
  renderer.setAttribute('top-margin', '0px')
  renderer.setAttribute('bottom-margin', '0px')
  const footNoteStyle = {
    fontSize: style.fontSize,
    textScale: style.textScale,
    fontName: style.fontName,
    fontPath: style.fontPath,
    letterSpacing: style.letterSpacing,
    spacing: style.spacing,
    textIndent: style.textIndent,
    fontColor: style.fontColor,
    backgroundColor: 'transparent',
    justify: true,
    textAlign: style.textAlign,
    hyphenate: true,
    customCSS: style.customCSS,
    customCSSEnabled: style.customCSSEnabled,
    writingMode: style.writingMode,
    overrideFont: style.overrideFont,
    overrideColor: style.overrideColor,
    useBookLayout: style.useBookLayout,
  }
  renderer.setStyles(getCSS(footNoteStyle))
  // set background color of dialog
  // if #rrggbbaa, replace aa to ee
  footnoteDialog.style.backgroundColor = style.backgroundColor.slice(0, 7) + '33'
}

class Reader {
  annotations = new Map()
  annotationsByValue = new Map()
  annotationsById = new Map()
  #footnoteHandler = new FootnoteHandler()
  #doc
  #index
  #originalContent
  #bookmarkExistedOnGesture = false
  #upTriggered = false
  #bookmarkInfo = {
    exists: false,
    cfi: null,
    id: null,
  }
  constructor() {
    this.#footnoteHandler.addEventListener('before-render', e => {
      const { view } = e.detail
      this.setView(view)
      replaceFootnote(view)
    })
    this.#footnoteHandler.addEventListener('render', e => {
      const { view } = e.detail
      openFootnoteDialog()
    })
    this.#originalContent = null
  }
  async open(file, cfi, progress) {
    this.view = await getView(file, cfi)

    if (importing) return

    this.view.addEventListener('load', this.#onLoad.bind(this))
    this.view.addEventListener('relocate', this.#onRelocate.bind(this))
    this.view.addEventListener('click-view', this.#onClickView.bind(this))
    this.view.addEventListener('doctouchstart', this.#onTouchStart.bind(this))
    this.view.addEventListener('doctouchmove', this.#onTouchMove.bind(this))
    this.view.addEventListener('doctouchend', this.#onTouchEnd.bind(this))

    setStyle()
    if (!cfi)
      this.view.renderer.next()
    this.setView(this.view)
    await this.view.init({ lastLocation: cfi })
    // iOS fallback path: if restoring by deep CFI crashed the WebContent
    // process, Flutter reloads this page with `cfi=null` but preserves the
    // last known progress fraction. Jump there after init so the book reopens
    // near the saved spot instead of from the cover.
    if (!cfi && Number.isFinite(progress) && progress > 0 && progress <= 1) {
      try {
        await this.view.goToFraction(progress)
      } catch (e) {
        console.warn('goToFraction fallback failed', e)
      }
    }

    // set html bg color to grey 
    document.documentElement.style.backgroundColor = 'grey'
  }

  setView(view) {
    view.addEventListener('create-overlay', e => {
      const { index } = e.detail
      const list = this.annotations.get(index)
      if (list) for (const annotation of list)
        this.view.addAnnotation(annotation)
    })

    view.addEventListener('draw-annotation', e => {
      const { draw, annotation } = e.detail
      const { color, type } = annotation
      const opts = { color, writingMode: rendererWritingMode() }
      if (type === 'highlight') draw(Overlayer.highlight, { ...opts })
      else if (type === 'underline') draw(Overlayer.underline, { ...opts })
    })

    view.addEventListener('show-annotation', e => {
      const annotation = this.annotationsByValue.get(e.detail.value)
      const pos = getPosition(e.detail.range)
      if (window.getSelection()?.toString()) return
      const contextText = buildRangeContextText(e.detail.range)
      onAnnotationClick({ annotation, pos, contextText })
    })
    view.addEventListener('external-link', e => {
      e.preventDefault()
      onExternalLink(e.detail)
    })

    view.addEventListener('link', e =>
      this.#footnoteHandler.handle(this.view.book, e)?.catch(err => {
        console.warn(err)
        this.view.goTo(e.detail.href)
      }))

    view.history.addEventListener('pushstate', e => {
      callFlutter('onPushState', {
        canGoBack: view.history.canGoBack,
        canGoForward: view.history.canGoForward
      })
    })
    view.addEventListener('click-image', async e => {
      // console.log('click-image', e.detail.img.src)
      const blobUrl = e.detail.img.src
      const blob = await fetch(blobUrl).then(r => r.blob())
      const base64 = await new Promise((resolve, reject) => {
        const reader = new FileReader()
        reader.onloadend = () => resolve(reader.result)
        reader.onerror = reject
        reader.readAsDataURL(blob)
      })
      callFlutter('onImageClick', base64)
    })
  }

  renderAnnotation(annotations) {
    const annos = annotations ?? allAnnotations ?? []
    for (const anno of annos) {
      const { value, type, color, note } = anno
      const annotation = {
        id: anno.id,
        value,
        type,
        color,
        note
      }

      this.addAnnotation(annotation)
    }

  }

  showContextMenu() {
    return handleSelection(this.view, this.#doc, this.#index)
  }

  addAnnotation(annotation) {
    annotation = this.#normalizedBookmarkAnnotation(annotation)
    const { value } = annotation
    const spineCode = this.#annotationSpineIndex(annotation)
    if (spineCode == null) return

    const list = this.annotations.get(spineCode)
    if (list) list.push(annotation)
    else this.annotations.set(spineCode, [annotation])

    this.annotationsByValue.set(value, annotation)
    if (annotation.id) this.annotationsById.set(annotation.id, annotation)

    if (annotation.type === 'bookmark') {
      const currentAnchor = this.#bookmarkAnchorFromLocation(this.view.lastLocation)
      if (this.#checkBookmark(annotation, currentAnchor)) {
        this.#bookmarkInfo = {
          exists: true,
          cfi: annotation.value,
          id: annotation.id,
        }
      }
    } else {
      this.view.addAnnotation(annotation)
    }

  }

  #checkCurrentPageBookmark() {
    const currentLocation = this.view.lastLocation
    const currentAnchor = this.#bookmarkAnchorFromLocation(currentLocation)
    const spineCode = this.#isBookmarkAnchorInteger(currentAnchor?.anchorSectionIndex)
      ? Number(currentAnchor.anchorSectionIndex)
      : this.#bookmarkSectionIndexFromLocation(currentLocation)
    const list = spineCode == null ? null : this.annotations.get(spineCode)
    let found = false
    let bookmark = null
    if (list && currentAnchor) {
      for (const bm of list) {
        if (bm.type === 'bookmark') {
          found = this.#checkBookmark(bm, currentAnchor) ? true : found
          if (found) {
            bookmark = bm
            break
          }
        }
      }
    }

    this.#bookmarkInfo = {
      exists: found,
      cfi: found ? bookmark.value : null,
      id: found ? bookmark.id : null,
    }
  }

  #checkBookmark(bookmark, currentAnchor) {
    if (!bookmark || !currentAnchor) return false
    if (this.#hasBookmarkVisualPageAnchor(bookmark)) {
      return this.#sameBookmarkVisualPageAnchor(bookmark, currentAnchor)
    }
    if (this.#sameBookmarkTextAnchor(bookmark, currentAnchor)) return true
    if (this.#hasBookmarkTextAnchor(bookmark)) return false
    if (!this.#isPreciseBookmarkCfi(bookmark.value)) return false
    if (!this.#isPreciseBookmarkCfi(currentAnchor.cfi)) return false
    return this.#sameBookmarkCfi(bookmark.value, currentAnchor.cfi)
  }

  #isPreciseBookmarkCfi(cfi) {
    const unwrapped = unwrapCFI(cfi)
    return Boolean(unwrapped && unwrapped.includes(',') && /:\d+/.test(unwrapped))
  }

  #sameBookmarkCfi(a, b) {
    const left = unwrapCFI(a)
    const right = unwrapCFI(b)
    return Boolean(left && right && left === right)
  }

  #normalizedBookmarkAnnotation(annotation) {
    if (annotation?.type !== 'bookmark') return annotation

    const cfiIndex = this.#annotationCfiSpineIndex(annotation)
    if (cfiIndex == null || !this.#hasBookmarkVisualPageAnchor(annotation)) {
      return annotation
    }

    const anchorIndex = Number(annotation.anchorSectionIndex)
    if (anchorIndex === cfiIndex) return annotation

    const anchorPage = Number(annotation.anchorSectionPage)
    return {
      ...annotation,
      anchorSectionIndex: cfiIndex,
      anchorSectionPage: anchorPage === anchorIndex
        ? cfiIndex
        : annotation.anchorSectionPage,
    }
  }

  #annotationSpineIndex(annotation) {
    const cfiIndex = this.#annotationCfiSpineIndex(annotation)
    if (cfiIndex != null) return cfiIndex

    if (this.#isBookmarkAnchorInteger(annotation?.anchorSectionIndex)) {
      return Number(annotation.anchorSectionIndex)
    }

    return null
  }

  #annotationCfiSpineIndex(annotation) {
    const cfi = unwrapCFI(annotation?.value)
    const match = typeof cfi === 'string' ? cfi.match(/^\/\d+\/(\d+)/) : null
    const spinePosition = match ? Number(match[1]) : NaN
    const index = (spinePosition - 2) / 2
    return Number.isInteger(index) && index >= 0 ? index : null
  }

  #hasBookmarkTextAnchor(bookmark) {
    return Boolean(this.#normalizeBookmarkText(bookmark.anchorExact))
  }

  #hasBookmarkVisualPageAnchor(bookmark) {
    return this.#isBookmarkAnchorInteger(bookmark.anchorSectionIndex) &&
      this.#isBookmarkAnchorInteger(bookmark.anchorSectionPage)
  }

  #sameBookmarkVisualPageAnchor(bookmark, currentAnchor) {
    if (!this.#isBookmarkAnchorInteger(currentAnchor.anchorSectionIndex) ||
      !this.#isBookmarkAnchorInteger(currentAnchor.anchorSectionPage)) {
      return false
    }
    return Number(bookmark.anchorSectionIndex) === currentAnchor.anchorSectionIndex &&
      Number(bookmark.anchorSectionPage) === currentAnchor.anchorSectionPage
  }

  #isBookmarkAnchorInteger(value) {
    return value != null && value !== '' && Number.isInteger(Number(value))
  }

  #sameBookmarkTextAnchor(bookmark, currentAnchor) {
    const exact = this.#normalizeBookmarkText(bookmark.anchorExact)
    if (!exact || exact !== currentAnchor.anchorExact) return false

    const prefix = this.#normalizeBookmarkText(bookmark.anchorPrefix)
    const suffix = this.#normalizeBookmarkText(bookmark.anchorSuffix)
    const currentPrefix = currentAnchor.anchorPrefix
    const currentSuffix = currentAnchor.anchorSuffix
    if (prefix && currentPrefix && prefix !== currentPrefix) return false
    if (suffix && currentSuffix && suffix !== currentSuffix) return false

    const hasMatchingContext =
      (prefix && currentPrefix && prefix === currentPrefix) ||
      (suffix && currentSuffix && suffix === currentSuffix)
    return exact.length >= 12 || hasMatchingContext
  }

  #normalizeBookmarkText(value) {
    return typeof value === 'string'
      ? value.replace(/\s+/g, ' ').trim()
      : ''
  }

  #rangeIsVisibleInViewport(range) {
    if (!range || typeof range.getClientRects !== 'function') return null
    if (!this.#rangeLooksLikeBookmarkAnchor(range)) return false
    const doc = range.startContainer?.ownerDocument ?? this.#doc
    const win = doc?.defaultView
    const width = win?.innerWidth ?? doc?.documentElement?.clientWidth
    const height = win?.innerHeight ?? doc?.documentElement?.clientHeight
    if (!width || !height) return null

    const rects = Array.from(range.getClientRects())
    if (!rects.length) return null

    const tolerance = 1
    const viewportArea = width * height
    let visibleArea = 0
    for (const rect of rects) {
      const visibleWidth =
        Math.min(rect.right, width) - Math.max(rect.left, 0)
      const visibleHeight =
        Math.min(rect.bottom, height) - Math.max(rect.top, 0)
      if (visibleWidth > 0 && visibleHeight > 0) {
        visibleArea += visibleWidth * visibleHeight
      }
    }
    if (visibleArea > viewportArea * 0.2) return false

    return rects.some(rect =>
      rect.bottom > tolerance &&
      rect.top < height - tolerance &&
      rect.right > tolerance &&
      rect.left < width - tolerance
    )
  }

  #rangeLooksLikeBookmarkAnchor(range) {
    const text = range.toString?.().trim() ?? ''
    if (!text || text.length > 240) return false
    const rects = typeof range.getClientRects === 'function'
      ? Array.from(range.getClientRects())
      : []
    return rects.length <= 8
  }

  #bookmarkAnchorFromLocation(location) {
    if (!location) return null
    const sectionIndex = this.#bookmarkSectionIndexFromLocation(location)
    if (sectionIndex == null) return null

    const visibleRange = location.range
    const pageAnchor = this.#bookmarkVisualPageAnchorFromLocation(
      location,
      sectionIndex,
    )
    let cfi = location.cfi
    if (!cfi) {
      cfi = this.view.getCFI(sectionIndex)
    }

    if (!visibleRange || !this.#doc) {
      if (!cfi) return null
      return {
        cfi,
        ...pageAnchor,
        content: this.#bookmarkVisualContentFromLocation(location),
      }
    }

    try {
      // Prefer a word from the visual viewport. The location DOM range can span
      // multiple CSS columns, so its midpoint may belong to a later page.
      const anchorRange = this.#visibleViewportBookmarkRange(visibleRange)
      if (!anchorRange) return null
      try {
        cfi = this.view.getCFI(sectionIndex, anchorRange) ?? cfi
      } catch (_) {
        // Some non-EPUB renderers expose a visual range but cannot produce a
        // precise CFI for it. Keep the page CFI for navigation and rely on the
        // text selector for active-state checks.
      }
      if (!cfi) return null
      const selector = this.#bookmarkSelectorFromRange(anchorRange)
      return {
        cfi,
        ...selector,
        ...pageAnchor,
        content: this.#bookmarkContentFromVisibleRange(visibleRange),
      }
    } catch (_) {
      return null
    }
  }

  #bookmarkSectionIndexFromLocation(location) {
    const index = location?.section?.current
    if (this.#isBookmarkAnchorInteger(index)) return Number(index)
    return Number.isInteger(this.#index) ? this.#index : null
  }

  #bookmarkVisualPageAnchorFromLocation(location, sectionIndex) {
    const page = location?.chapterLocation?.current
    return {
      anchorSectionIndex: Number.isInteger(sectionIndex) ? sectionIndex : null,
      anchorSectionPage: Number.isInteger(page) ? page : null,
    }
  }

  #bookmarkVisualContentFromLocation(location) {
    const page = location?.chapterLocation?.current
    const total = location?.chapterLocation?.total
    if (Number.isInteger(page) && Number.isInteger(total) && total > 0) {
      return `Page ${Math.min(total, Math.max(1, page + 1))} / ${total}`
    }
    return ''
  }

  #visibleViewportBookmarkRange(visibleRange) {
    const wordRange = this.#visibleViewportWordRange(visibleRange)
    return wordRange
      ? this.#expandRangeToBookmarkQuote(wordRange, visibleRange)
      : null
  }

  #visibleViewportWordRange(visibleRange) {
    const doc = this.#doc
    const win = doc?.defaultView
    const width = win?.innerWidth ?? doc?.documentElement?.clientWidth
    const height = win?.innerHeight ?? doc?.documentElement?.clientHeight
    if (!doc || !width || !height) return null

    const yCandidates = [0.5, 0.42, 0.58, 0.33, 0.67, 0.25, 0.75]
    const xCandidates = [0.5, 0.42, 0.58, 0.34, 0.66]

    for (const y of yCandidates) {
      for (const x of xCandidates) {
        const range = this.#wordRangeFromPoint(width * x, height * y, visibleRange)
        if (range && this.#rangeIsVisibleInViewport(range) === true) {
          return range
        }
      }
    }

    return this.#nearestVisibleWordRange(visibleRange, width / 2, height / 2)
  }

  #wordRangeFromPoint(x, y, visibleRange) {
    const caret = this.#caretRangeFromPoint(x, y)
    const position = this.#textPositionFromCaret(caret)
    if (!position) return null

    const slice = this.#visibleTextSlice(visibleRange, position.node)
    if (!slice) return null

    return this.#wordRangeInSlice(slice, position.offset)
  }

  #caretRangeFromPoint(x, y) {
    const doc = this.#doc
    if (!doc) return null

    if (typeof doc.caretRangeFromPoint === 'function') {
      return doc.caretRangeFromPoint(x, y)
    }

    if (typeof doc.caretPositionFromPoint === 'function') {
      const position = doc.caretPositionFromPoint(x, y)
      if (!position?.offsetNode) return null
      const range = doc.createRange()
      range.setStart(position.offsetNode, position.offset)
      range.collapse(true)
      return range
    }

    return null
  }

  #textPositionFromCaret(caret) {
    const container = caret?.startContainer
    if (!container) return null

    const textNodeType =
      this.#doc?.defaultView?.Node?.TEXT_NODE ?? globalThis.Node?.TEXT_NODE ?? 3
    if (container.nodeType === textNodeType) {
      return { node: container, offset: caret.startOffset }
    }

    const children = container.childNodes
    if (!children?.length) return null
    const index = Math.min(Math.max(caret.startOffset, 0), children.length - 1)
    const node =
      this.#firstTextNode(children[index]) ??
      this.#firstTextNode(children[index - 1])
    return node ? { node, offset: 0 } : null
  }

  #firstTextNode(node) {
    if (!node) return null

    const win = node.ownerDocument?.defaultView ?? this.#doc?.defaultView
    const textNodeType = win?.Node?.TEXT_NODE ?? globalThis.Node?.TEXT_NODE ?? 3
    if (node.nodeType === textNodeType && node.nodeValue?.trim()) return node

    const nodeFilter = win?.NodeFilter ?? globalThis.NodeFilter
    if (!nodeFilter || !node.ownerDocument?.createTreeWalker) return null

    const walker = node.ownerDocument.createTreeWalker(
      node,
      nodeFilter.SHOW_TEXT,
      {
        acceptNode: textNode =>
          textNode.nodeValue?.trim()
            ? nodeFilter.FILTER_ACCEPT
            : nodeFilter.FILTER_REJECT,
      },
    )
    return walker.nextNode()
  }

  #nearestVisibleWordRange(visibleRange, centerX, centerY) {
    const doc = this.#doc
    if (!doc?.body) return null
    const nodeFilter = doc.defaultView?.NodeFilter ?? globalThis.NodeFilter
    if (!nodeFilter) return null

    const walker = doc.createTreeWalker(
      doc.body,
      nodeFilter.SHOW_TEXT,
      {
        acceptNode: node => {
          if (!node.nodeValue?.trim()) return nodeFilter.FILTER_REJECT
          try {
            return visibleRange.intersectsNode(node)
              ? nodeFilter.FILTER_ACCEPT
              : nodeFilter.FILTER_REJECT
          } catch (_) {
            return nodeFilter.FILTER_REJECT
          }
        },
      },
    )
    let best = null

    for (let node = walker.nextNode(); node; node = walker.nextNode()) {
      const slice = this.#visibleTextSlice(visibleRange, node)
      if (!slice) continue

      for (const range of this.#wordRangesInSlice(slice)) {
        if (this.#rangeIsVisibleInViewport(range) !== true) continue
        const score = this.#rangeViewportScore(range, centerX, centerY)
        if (score == null) continue
        if (!best || score < best.score) {
          best = { range, score }
        }
      }
    }

    return best?.range ?? null
  }

  #visibleTextSlice(range, node) {
    const text = node.nodeValue ?? ''
    let start = 0
    let end = text.length

    if (node === range.startContainer) {
      start = Math.min(Math.max(range.startOffset, 0), end)
    }
    if (node === range.endContainer) {
      end = Math.min(Math.max(range.endOffset, 0), end)
    }
    if (start >= end || !text.slice(start, end).trim()) return null

    return { node, start, end }
  }

  #wordRangesInSlice(slice) {
    const ranges = []
    const { node, start, end } = slice
    const text = node.nodeValue ?? ''
    const matches = text.slice(start, end).matchAll(/\S+/g)

    for (const match of matches) {
      const wordStart = start + match.index
      const wordEnd = wordStart + match[0].length
      const range = node.ownerDocument.createRange()
      range.setStart(node, wordStart)
      range.setEnd(node, wordEnd)
      ranges.push(range)
    }

    return ranges
  }

  #wordRangeInSlice(slice, offset) {
    const { node, start, end } = slice
    const text = node.nodeValue ?? ''
    let pos = Math.min(Math.max(offset, start), end - 1)

    if (/\s/.test(text[pos])) {
      let left = pos
      let right = pos
      let found = -1
      while (left >= start || right < end) {
        if (right < end && !/\s/.test(text[right])) {
          found = right
          break
        }
        if (left >= start && !/\s/.test(text[left])) {
          found = left
          break
        }
        right++
        left--
      }
      if (found === -1) return null
      pos = found
    }

    let wordStart = pos
    while (wordStart > start && !/\s/.test(text[wordStart - 1])) {
      wordStart--
    }

    let wordEnd = pos + 1
    while (wordEnd < end && !/\s/.test(text[wordEnd])) {
      wordEnd++
    }

    const range = node.ownerDocument.createRange()
    range.setStart(node, wordStart)
    range.setEnd(node, wordEnd)
    return range
  }

  #expandRangeToBookmarkQuote(range, visibleRange) {
    const node = range.startContainer
    if (!node || node !== range.endContainer) return range

    const slice = this.#visibleTextSlice(visibleRange, node)
    if (!slice) return range

    const text = node.nodeValue ?? ''
    const targetSideChars = 60
    let start = Math.max(slice.start, range.startOffset - targetSideChars)
    let end = Math.min(slice.end, range.endOffset + targetSideChars)

    while (start > slice.start && !/\s/.test(text[start - 1])) start--
    while (end < slice.end && !/\s/.test(text[end])) end++
    while (start < end && /\s/.test(text[start])) start++
    while (end > start && /\s/.test(text[end - 1])) end--

    if (start >= end) return range

    const quoteRange = node.ownerDocument.createRange()
    quoteRange.setStart(node, start)
    quoteRange.setEnd(node, end)
    return quoteRange
  }

  #bookmarkSelectorFromRange(range) {
    const exact = this.#normalizeBookmarkText(range.toString())
    const node = range.startContainer === range.endContainer
      ? range.startContainer
      : null
    if (!node?.nodeValue) {
      return {
        anchorExact: exact,
        anchorPrefix: '',
        anchorSuffix: '',
      }
    }

    const text = node.nodeValue
    const prefix = this.#normalizeBookmarkText(
      text.slice(Math.max(0, range.startOffset - 80), range.startOffset),
    )
    const suffix = this.#normalizeBookmarkText(
      text.slice(range.endOffset, Math.min(text.length, range.endOffset + 80)),
    )
    return {
      anchorExact: exact,
      anchorPrefix: prefix.slice(-80),
      anchorSuffix: suffix.slice(0, 80),
    }
  }

  #rangeViewportScore(range, centerX, centerY) {
    const doc = range.startContainer?.ownerDocument ?? this.#doc
    const win = doc?.defaultView
    const width = win?.innerWidth ?? doc?.documentElement?.clientWidth
    const height = win?.innerHeight ?? doc?.documentElement?.clientHeight
    if (!width || !height) return null

    let best = null
    for (const rect of Array.from(range.getClientRects())) {
      const left = Math.max(rect.left, 0)
      const right = Math.min(rect.right, width)
      const top = Math.max(rect.top, 0)
      const bottom = Math.min(rect.bottom, height)
      if (right <= left || bottom <= top) continue
      const x = (left + right) / 2
      const y = (top + bottom) / 2
      const score = (x - centerX) ** 2 + (y - centerY) ** 2
      best = best == null ? score : Math.min(best, score)
    }
    return best
  }

  #bookmarkContentFromVisibleRange(range) {
    const content = this.#normalizeBookmarkText(range.toString())
    return content.length > 200 ? content.slice(0, 200) + '...' : content
  }

  refreshBookmarkState = (reason = 'bookmark-sync') => {
    const lastLocation = this.view.lastLocation
    if (!lastLocation) return
    this.#checkCurrentPageBookmark()
    onRelocated({
      cfi: lastLocation.cfi,
      fraction: lastLocation.fraction,
      loc: lastLocation.pageItem
        ? `Page ${lastLocation.pageItem.label}`
        : `Loc ${lastLocation.location.current}`,
      tocItem: lastLocation.tocItem,
      pageItem: lastLocation.pageItem,
      location: lastLocation.location,
      chapterLocation: lastLocation.chapterLocation,
      reason,
      bookmark: this.#bookmarkInfo,
    })
  }

  removeAnnotation(cfi, notify = true, id = null) {
    const annotation = id
      ? this.annotationsById.get(id)
      : this.annotationsByValue.get(cfi)
    if (!annotation) return
    const { value } = annotation
    const spineCode = this.#annotationSpineIndex(annotation)

    const list = spineCode == null ? null : this.annotations.get(spineCode)
    if (list) {
      const index = list.findIndex(a => a.id === annotation.id)
      if (index !== -1) list.splice(index, 1)
    }

    this.annotationsByValue.delete(value)
    if (annotation.id) this.annotationsById.delete(annotation.id)

    this.view.addAnnotation(annotation, true)

    const currentAnchor = this.#bookmarkAnchorFromLocation(this.view.lastLocation)
    if (
      annotation.type === 'bookmark' &&
      this.#checkBookmark(annotation, currentAnchor)
    ) {
      if (notify) this.handleBookmark(true)
      this.#bookmarkInfo = {
        exists: false,
        cfi: null,
        id: null,
      }
    }

  }

  #onLoad({ detail: { doc, index } }) {
    this.#doc = doc
    this.#index = index
    setSelectionHandler(this.view, doc, index)
    // Wire iframe touch events into the readflex gesture dispatcher so
    // any registered handler (CBZ swipe, future pinch-zoom, etc.) sees
    // them regardless of which renderer (paginator / fixed-layout) loaded
    // the iframe.
    readflexAttachGestures(doc)
    normalizeLoadedDocument(doc)

    // if (!this.#originalContent) {
    // console.log('Saving original content', doc);
    // this.#originalContent = doc.cloneNode(true)
    // console.log('Original content saved', this.#originalContent);
    // }

    this.#saveOriginalContent()

    this.readingFeatures(readingRules)
  }

  #onRelocate({ detail }) {
    const { cfi, fraction, location, tocItem, pageItem, chapterLocation, reason } = detail
    const loc = pageItem
      ? `Page ${pageItem.label}`
      : `Loc ${location.current}`
    this.#checkCurrentPageBookmark()
    onRelocated({
      cfi,
      fraction,
      loc,
      tocItem,
      pageItem,
      location,
      chapterLocation,
      reason,
      bookmark: this.#bookmarkInfo,
    })
  }

  #onClickView({ detail: { x, y } }) {
    const selection = this.#doc?.getSelection?.()
    if (selection && getSelectionRange(selection)) {
      return
    }

    if (this.#doc?.__anxSuppressClick) {
      this.#doc.__anxSuppressClick = false;
      return
    }

    // debounce for 200ms after selection cleared
    const lastClearedAt = this.#doc?.__anxSelectionClearedAt ?? 0
    if (lastClearedAt && Date.now() - lastClearedAt < 200) {
      return
    }

    const coordinatesX = x / window.innerWidth
    const coordinatesY = y / window.innerHeight
    onClickView(coordinatesX, coordinatesY)
  }

  get index() {
    return this.#index
  }

  #saveOriginalContent = () => {
    // this.#originalContent = this.#doc.cloneNode(true)

    // save original content
    this.#originalContent = [];
    const walker = document.createTreeWalker(
      this.#doc.body,
      NodeFilter.SHOW_TEXT,
      null,
      false
    );
    while (walker.nextNode()) {
      this.#originalContent.push(walker.currentNode.textContent);
    }
  }

  #restoreOriginalContent = () => {
    // this.#doc.body.innerHTML = this.#originalContent.body.innerHTML

    const walker = document.createTreeWalker(
      this.#doc.body,
      NodeFilter.SHOW_TEXT,
      null,
      false
    );
    let node;
    let index = 0;
    while (node = walker.nextNode()) {
      node.textContent = this.#originalContent[index++];
    }
  }

  readingFeatures = () => {
    this.#restoreOriginalContent()
    readingFeaturesDocHandler(this.#doc)
    this.applyTextContrastGuard()
  }

  applyTextContrastGuard = () => {
    if (!this.#doc) return
    applyReaderContrastGuard(this.#doc)
  }

  getChapterContent = () => {
    return this.#doc.body.textContent
  }

  getChapterContentByHref = async (target, options = {}) => {
    if (!target) return ''
    if (!this.view?.book?.sections) return ''

    const resolved = this.view.resolveNavigation?.(target)
    if (!resolved || resolved.index == null) return ''

    const section = this.view.book.sections[resolved.index]
    if (!section?.createDocument) return ''

    const doc = await section.createDocument()
    let content = doc?.body?.textContent ?? ''

    if (!content) return ''

    const rawMax = options?.maxChars
    const numericMax = rawMax == null ? null : Number(rawMax)
    const maxChars = Number.isFinite(numericMax) && numericMax > 0
      ? Math.floor(numericMax)
      : null

    if (maxChars != null && content.length > maxChars) {
      content = content.slice(0, maxChars)
    }

    return content
  }

  getPreviousContent = (count = 2000) => {
    let currentContainer = this.view.lastLocation?.range?.endContainer?.parentElement;
    if (!currentContainer) return '';

    let text = '';
    while (text.length < count && currentContainer) {
      text = currentContainer.textContent + text;
      currentContainer = currentContainer.previousSibling;
    }

    return text;

  }

  getSelection = () => {
    const selection = this.#doc.getSelection();
    const range = getSelectionRange(selection);
    return range;
  }

  #ignoreTouch = () => {
    return this.view.renderer.scrollProp === 'scrollTop'
  }


  #onTouchStart = ({ detail: e }) => {
    if (this.#ignoreTouch()) return;

    this.#bookmarkExistedOnGesture = this.#bookmarkInfo.exists;
    this.#upTriggered = false;
  }

  #onTouchMove = ({ detail: e }) => {
    if (this.#ignoreTouch()) return;

    const mainView = this.view.shadowRoot.children[0]
    if (e.touchState.direction === 'vertical') {
      const deltaY = e.touchState.delta.y;

      if (deltaY > 0) {
        mainView.style.transform = `translateY(${Math.sqrt(deltaY * 50)}px)`;
      } else if (deltaY < -60) {
        if (!this.#upTriggered) {
          this.#upTriggered = true;
          window.pullUp()
        }
      }
    }
  }

  #onTouchEnd = ({ detail: e }) => {
    if (this.#ignoreTouch()) return;
    // Readflex patch: paginator's `doctouchend` may dispatch with
    // `touchState: null` if the gesture was cancelled / vertical-locked
    // before lift. Without this guard the bookmark/swipe handler below
    // throws `Cannot read properties of null (reading 'direction')`.
    if (!e?.touchState) return;

    const mainView = this.view.shadowRoot.children[0]
    if (e.touchState.direction === 'vertical') {
      const deltaY = e.touchState.delta.y;

      if (deltaY < -60) {
        // console.log('UP');
      } else if (deltaY > 60) {
        if (this.#bookmarkExistedOnGesture) {
          this.handleBookmark(true, 'pull-down');
        } else {
          this.handleBookmark(false, 'pull-down');
        }
      }

      mainView.style.transition = 'transform 0.3s ease-out';
      mainView.style.transform = 'translateY(0px)';

      setTimeout(() => {
        mainView.style.transition = '';
      }, 300);
    }
  }

  handleBookmark = (remove, source = 'unknown') => {
    const location = this.view.lastLocation
    const anchor = remove ? null : this.#bookmarkAnchorFromLocation(location)
    const cfi = remove ? this.#bookmarkInfo.cfi : anchor?.cfi
    if (!cfi) return

    const container = location?.range?.startContainer
    let content = anchor?.content ?? container?.data ?? container?.innerText ?? ''
    content = content.trim()
    if (content.length > 200) {
      content = content.slice(0, 200) + '...'
    }
    const percentage = location?.fraction ?? 0

    callFlutter('handleBookmark', {
      remove,
      source,
      detail: {
        id: remove ? this.#bookmarkInfo.id : null,
        cfi,
        content,
        percentage,
        anchorExact: anchor?.anchorExact,
        anchorPrefix: anchor?.anchorPrefix,
        anchorSuffix: anchor?.anchorSuffix,
        anchorSectionIndex: anchor?.anchorSectionIndex,
        anchorSectionPage: anchor?.anchorSectionPage,
      }
    })
  }

  goToBookmark = async target => {
    let sectionIndex = target?.anchorSectionIndex
    let sectionPage = target?.anchorSectionPage
    const cfiSectionIndex = this.#annotationCfiSpineIndex({ value: target?.cfi })
    if (cfiSectionIndex != null &&
      this.#isBookmarkAnchorInteger(sectionIndex) &&
      Number(sectionIndex) !== cfiSectionIndex) {
      const previousSectionIndex = Number(sectionIndex)
      sectionIndex = cfiSectionIndex
      if (this.#isBookmarkAnchorInteger(sectionPage) &&
        Number(sectionPage) === previousSectionIndex) {
        sectionPage = cfiSectionIndex
      }
    }

    if (this.#isBookmarkAnchorInteger(sectionIndex) &&
      this.#isBookmarkAnchorInteger(sectionPage)) {
      try {
        const didNavigate = await this.view.goToSectionPage(sectionIndex, sectionPage)
        if (didNavigate) return
      } catch (e) {
        console.warn('goToBookmark visual page fallback failed', e)
      }
    }

    if (target?.cfi) {
      await this.view.goTo(target.cfi)
      return
    }

    const progress = Number(target?.progress)
    if (Number.isFinite(progress) && progress > 0 && progress <= 1) {
      await this.view.goToFraction(progress)
    }
  }

  toggleBookmark = () => {
    if (this.#bookmarkInfo.exists) {
      this.handleBookmark(true, 'chrome')
    } else {
      this.handleBookmark(false, 'chrome')
    }
  }

  get toc() {
    const sectionFractions = this.view.getSectionFractions()
    const currentHref = this.view.lastLocation?.tocItem?.href?.split('#')[0] ?? 'Not Found'
    let currentChapterIndex = sectionFractions.findIndex(s => s.href === currentHref)
    if (currentChapterIndex === -1) {
      currentChapterIndex = 0;
    }
    const currentSectionStart = sectionFractions[currentChapterIndex]?.fraction || 0
    const nextSectionStart = sectionFractions[currentChapterIndex + 1]?.fraction || 1
    const currentSectionPages = this.view.lastLocation?.chapterLocation.total || 1

    const totalPages = currentSectionPages / (nextSectionStart - currentSectionStart)

    const getFractionByHref = (href) => {
      if (typeof href !== 'string' || !href) return null
      href = href.split('#')[0]
      const section = sectionFractions.find(s => s.href === href)
      return section ? section.fraction : null
    }

    const buildItems = (items, level) => {
      return items?.map(item => {
        const startPercentage = getFractionByHref(item.href)
        return {
          label: item.label,
          href: typeof item.href === 'string' ? item.href : '',
          id: item.id,
          level,
          startPercentage,
          startPage: startPercentage == null
            ? null
            : Math.ceil(startPercentage * totalPages),
          subitems: buildItems(item.subitems, level + 1)
        }
      }) || [];
    }
    return buildItems(this.view.book.toc, 1)
  }
}


const open = async (file, cfi, progress) => {
  const reader = new Reader()
  globalThis.reader = reader
  await reader.open(file, cfi, progress)
  if (!importing) {
    callFlutter('onLoadEnd')
    onSetToc()
    scheduleDocumentFeatureDetection()
    callFlutter('renderAnnotations')
  }
  else { getMetadata() }
}


const callFlutter = (name, data) => {
  // console.log('callFlutter', name, data)
  window.flutter_inappwebview.callHandler(name, data)
}

const emitDocumentFeatures = () => {
  const features = reader?.view?.book?.features
  if (!features) return
  callFlutter('onDocumentFeatures', features)
}

const refreshDocumentFeatures = async () => {
  emitDocumentFeatures()
}

const scheduleDocumentFeatureDetection = () => {
  emitDocumentFeatures()
  setTimeout(() => {
    refreshDocumentFeatures()
  }, 250)
}

const readerCSSKeys = [
  'fontSize',
  'textScale',
  'fontName',
  'fontPath',
  'fontWeight',
  'letterSpacing',
  'spacing',
  'paragraphSpacing',
  'textIndent',
  'fontColor',
  'backgroundColor',
  'justify',
  'textAlign',
  'hyphenate',
  'writingMode',
  'backgroundImage',
  'customCSS',
  'customCSSEnabled',
  'overrideFont',
  'overrideColor',
  'useBookLayout',
]

const shouldUpdateReaderCSS = (oldStyle, nextStyle, flow) => {
  if (!oldStyle) return true
  if ((oldStyle.pageTurnStyle === 'scroll') !== flow) return true
  return readerCSSKeys.some(key => oldStyle?.[key] !== nextStyle?.[key])
}

const setRendererAttribute = (renderer, name, value) => {
  const nextValue = `${value ?? ''}`
  if (renderer.getAttribute(name) === nextValue) return
  renderer.setAttribute(name, nextValue)
}

const removeRendererAttribute = (renderer, name) => {
  if (!renderer.hasAttribute(name)) return
  renderer.removeAttribute(name)
}

const setStyle = (oldStyle) => {
  const turn = {
    scroll: false,
    animated: true
  }

  switch (style.pageTurnStyle) {
    case 'slide':
      turn.scroll = false
      turn.animated = true
      break
    case 'scroll':
      turn.scroll = true
      turn.animated = true
      break
    case "noAnimation":
      turn.scroll = false
      turn.animated = false
      break
  }

  const renderer = reader.view.renderer
  setRendererAttribute(renderer, 'flow', turn.scroll ? 'scrolled' : 'paginated')
  setRendererAttribute(renderer, 'top-margin', `${style.topMargin}px`)
  setRendererAttribute(renderer, 'bottom-margin', `${style.bottomMargin}px`)
  setRendererAttribute(renderer, 'gap', `${style.sideMargin}%`)
  setRendererAttribute(renderer, 'background-color', style.backgroundColor)
  setRendererAttribute(renderer, 'max-column-count', style.maxColumnCount)
  setRendererAttribute(renderer, 'bgimg-url', style.backgroundImage)

  turn.animated ? setRendererAttribute(renderer, 'animated', 'true')
    : removeRendererAttribute(renderer, 'animated')

  const newStyle = {
    fontSize: style.fontSize,
    textScale: style.textScale,
    fontName: style.fontName,
    fontPath: style.fontPath,
    fontWeight: style.fontWeight,
    letterSpacing: style.letterSpacing,
    spacing: style.spacing,
    paragraphSpacing: style.paragraphSpacing,
    textIndent: style.textIndent,
    fontColor: style.fontColor,
    backgroundColor: style.backgroundColor,
    justify: style.justify,
    textAlign: style.textAlign,
    hyphenate: style.hyphenate,
    writingMode: style.writingMode,
    backgroundImage: style.backgroundImage,
    flow: turn.scroll,
    customCSS: style.customCSS,
    customCSSEnabled: style.customCSSEnabled,
    overrideFont: style.overrideFont,
    overrideColor: style.overrideColor,
    useBookLayout: style.useBookLayout,
  }
  if (shouldUpdateReaderCSS(oldStyle, newStyle, turn.scroll)) {
    reader.view.renderer.setStyles?.(getCSS(newStyle))
    requestAnimationFrame(() => reader.applyTextContrastGuard?.())
  }

  if (!oldStyle) {
    return
  }

  if (oldStyle?.writingMode !== style.writingMode ||
    oldStyle?.pageTurnStyle !== style.pageTurnStyle && [oldStyle?.pageTurnStyle, style.pageTurnStyle].includes('scroll')
  ) {
    refreshLayout()
  }
}

const refreshLayout = () => {
  const cfi = reader.view.lastLocation?.cfi
  window.nextSection().then(() => {
    if (cfi) {
      setTimeout(() => {
        window.goToCfi(cfi)
      }, 0)
    }
  })
}


const onRelocated = (currentInfo) => {
  const chapterTitle = currentInfo.tocItem?.label
  const chapterHref = currentInfo.tocItem?.href
  const chapterTotalPages = currentInfo.chapterLocation.total
  const chapterCurrentPage = currentInfo.chapterLocation.current
  const bookTotalPages = currentInfo.location.total
  const bookCurrentPage = currentInfo.location.current
  const cfi = currentInfo.cfi
  const percentage = currentInfo.fraction
  // foliate-js's paginator considers the last two trailing columns
  // "blank buffer" (atEnd: page >= pages - 2). On those pages it
  // reports fraction=0 / current=0 even though the user is at the
  // END of the book. Surfacing atEnd lets Dart override the bogus
  // numbers instead of trying to filter the event by heuristics.
  const atEnd = reader.view.renderer.atEnd ?? false
  const atStart = reader.view.renderer.atStart ?? false

  // sizeTotal is the byte length of all linear sections, i.e. what
  // foliate-js itself uses to compute `bookCurrentPage` and
  // `bookTotalPages`. Surfacing it lets Dart reproduce the exact
  // `floor(fraction × sizeTotal / sizePerLoc)` arithmetic for the
  // drag-time slider preview, without the ±1 rounding error that
  // comes from approximating sizeTotal back from bookTotalPages.
  const sizeTotal = reader.view.sizeTotal

  callFlutter('onRelocated', {
    chapterTitle,
    chapterHref,
    chapterTotalPages,
    chapterCurrentPage,
    bookTotalPages,
    bookCurrentPage,
    sizeTotal,
    cfi,
    percentage,
    reason: currentInfo.reason,
    atEnd,
    atStart,
    bookmark: currentInfo.bookmark,
    writingMode: rendererWritingMode(),
    pageProgressionDirection: reader.view.pageProgressionDirection,
  })
}

const onAnnotationClick = (annotation) => callFlutter('onAnnotationClick', annotation)

const onClickView = (x, y) => callFlutter('onClick', { x, y })

const onExternalLink = (link) => callFlutter('onExternalLink', link)

const onSetToc = () => callFlutter('onSetToc', reader.toc)

const getMetadata = async () => {
  const cover = await reader.view.book.getCover()
  if (cover) {
    // cover is a blob, so we need to convert it to base64
    const fileReader = new FileReader()
    fileReader.readAsDataURL(cover)
    fileReader.onloadend = () => {
      callFlutter('onMetadata', {
        ...reader.view.book.metadata,
        cover: fileReader.result
      })
    }
  } else {
    callFlutter('onMetadata', {
      ...reader.view.book.metadata,
      cover: null
    })
  }
}

window.refreshToc = () => onSetToc()

window.changeStyle = (newStyle) => {
  const oldStyle = style
  style = {
    ...style,
    ...newStyle
  }
  setStyle(oldStyle)
}

window.goToHref = href => reader.view.goTo(href)

window.goToCfi = cfi => reader.view.goTo(cfi)

window.goToPercent = percent => reader.view.goToFraction(percent)

window.goToBookmark = target => reader.goToBookmark(target)

window.nextPage = () => reader.view.next()

window.prevPage = () => reader.view.prev()

window.pageLeft = () => reader.view.goLeft()

window.pageRight = () => reader.view.goRight()

window.setScroll = () => {
  style.scroll = true
  style.animated = true
  setStyle()
}

window.setPaginated = () => {
  style.scroll = false
  style.animated = true
  setStyle()
}

window.setNoAnimation = () => {
  style.scroll = false
  style.animated = false
  setStyle()
}

const onSelectionEnd = (selection) => {
  if (window.isFootNoteOpen() || isPdf) {
    callFlutter('onSelectionEnd', { ...selection, footnote: true })
  } else {
    callFlutter('onSelectionEnd', { ...selection, footnote: false })
  }
}

window.showContextMenu = () => {
  if (window.isFootNoteOpen()) {
    footnoteSelection()
  } else {
    reader.showContextMenu()
  }
}

window.getSelection = () => reader.getSelection()

window.clearSelection = () => reader.view.deselect()

window.addAnnotation = (annotation) => reader.addAnnotation(annotation)

window.addBookmarkHere = () => reader.handleBookmark(false, 'chrome')

window.toggleBookmarkHere = () => reader.toggleBookmark()

window.removeAnnotation = (cfi, notify = true, id = null) =>
  reader.removeAnnotation(cfi, notify, id)

window.prevSection = () => reader.view.renderer.prevSection()

window.nextSection = () => reader.view.renderer.nextSection()

window.initTts = () => reader.view.initTTS()

window.ttsStop = () => reader.view.initTTS(true)

window.ttsHere = () => {
  initTts()
  return reader.view.tts.from(reader.view.lastLocation.range)
}

window.ttsCurrentDetail = () => {
  initTts()
  return reader.view.tts.currentDetail()
}

window.ttsCollectDetails = (count = 1, includeCurrent = false, offset = 1) => {
  initTts()
  return reader.view.tts.collectDetails(count, { includeCurrent, offset })
}

window.ttsHighlightByCfi = cfi => {
  initTts()
  return reader.view.tts.highlightCfi(cfi)
}

window.ttsNextSection = async () => {
  await nextSection()
  initTts()
  return ttsNext()
}

window.ttsPrevSection = async (last) => {
  await prevSection()
  initTts()
  return last ? reader.view.tts.end() : ttsNext()
}

window.ttsNext = async () => {
  const result = reader.view.tts.next(true)
  if (result) return result
  return await ttsNextSection()
}

window.ttsPrev = () => {
  const result = reader.view.tts.prev(true)
  if (result) return result
  return ttsPrevSection(true)
}

window.ttsPrepare = () => reader.view.tts.prepare()

let activeSearchToken = 0
let activeSearchRequestId = null

window.clearSearch = () => reader.view.clearSearch()

window.cancelSearch = (requestId = null) => {
  if (requestId != null && activeSearchRequestId !== requestId) return
  activeSearchToken++
  activeSearchRequestId = null
  reader.view.clearSearch()
}

const emitSearchResults = (requestId, result) => {
  const chapterTitle = result.label ?? ''
  if ('subitems' in result) {
    callFlutter('onSearch', {
      requestId,
      type: 'results',
      items: result.subitems.map((item) => ({
        cfi: item.cfi,
        excerpt: item.excerpt,
        chapterTitle,
      })),
    })
  }
  else if (result.cfi) {
    callFlutter('onSearch', {
      requestId,
      type: 'results',
      items: [{
        cfi: result.cfi,
        excerpt: result.excerpt,
        chapterTitle,
      }],
    })
  }
}

window.startSearch = async (requestId, text, opts = {}) => {
  const token = ++activeSearchToken
  activeSearchRequestId = requestId
  opts = {
    'scope': 'book',
    'matchCase': false,
    'matchDiacritics': false,
    'matchWholeWords': false,
    ...opts,
  }

  const query = `${text ?? ''}`.trim()
  if (!query) {
    reader.view.clearSearch()
    activeSearchRequestId = null
    callFlutter('onSearch', { requestId, type: 'done' })
    return
  }

  const index = opts.scope === 'section' ? reader.index : null

  try {
    for await (const result of reader.view.search({ ...opts, query, index })) {
      if (token !== activeSearchToken) return
      if (result === 'done') {
        activeSearchRequestId = null
        callFlutter('onSearch', { requestId, type: 'done' })
      }
      else if ('progress' in result) {
        callFlutter('onSearch', {
          requestId,
          type: 'progress',
          progress: result.progress,
        })
      }
      else {
        emitSearchResults(requestId, result)
      }

      await new Promise((resolve) => setTimeout(resolve, 0))
    }
  } catch (e) {
    if (token !== activeSearchToken) return
    activeSearchRequestId = null
    callFlutter('onSearch', {
      requestId,
      type: 'error',
      message: String(e && e.message || e),
    })
  }
}

window.searchBook = async (text, opts = {}) => {
  opts = {
    'scope': 'book',
    'matchCase': false,
    'matchDiacritics': false,
    'matchWholeWords': false,
    ...opts,
  }
  const query = `${text ?? ''}`.trim()
  if (!query) {
    reader.view.clearSearch()
    return []
  }

  const index = opts.scope === 'section' ? reader.index : null
  const items = []

  for await (const result of reader.view.search({ ...opts, query, index })) {
    if (result === 'done' || 'progress' in result) continue
    if ('subitems' in result) {
      for (const item of result.subitems)
        items.push({
          cfi: item.cfi,
          excerpt: item.excerpt,
          chapterTitle: result.label ?? '',
        })
    }
    else if (result.cfi) {
      items.push({
        cfi: result.cfi,
        excerpt: result.excerpt,
        chapterTitle: '',
      })
    }
  }

  return items
}

window.search = async (text, opts) => {
  opts == null && (opts = {
    'scope': 'book',
    'matchCase': false,
    'matchDiacritics': false,
    'matchWholeWords': false,
  })
  const query = text.trim()
  if (!query) return

  const index = opts.scope === 'section' ? reader.index : null

  for await (const result of reader.view.search({ ...opts, query, index })) {
    if (result === 'done') {
      callFlutter('onSearch', { process: 1.0 })
    }
    else if ('progress' in result)
      callFlutter('onSearch', { process: result.progress })
    else {
      callFlutter('onSearch', result)
    }
  }
}

window.back = () => reader.view.history.back()

window.forward = () => reader.view.history.forward()

window.renderAnnotations = (annotations) => reader.renderAnnotation(annotations)

window.refreshBookmarkState = () => reader.refreshBookmarkState()

window.theChapterContent = () => reader.getChapterContent()

window.previousContent = (count = 2000) => reader.getPreviousContent(count)

window.getChapterContentByHref = async (href, opts) =>
  reader.getChapterContentByHref(href, opts)

// window.convertChinese = (mode) => reader.convertChinese(mode)

// window.bionicReading = (enable) => reader.bionicReading(enable)

window.isFootNoteOpen = () => isFootnoteDialogOpen()

window.closeFootNote = () => closeFootnoteDialog()

window.readingFeatures = (rules) => {
  readingRules = { ...readingRules, ...rules }
  reader.readingFeatures()
}

window.pullUp = () => {
  callFlutter('onPullUp')
}

// Page-flip on horizontal swipe for fixed-layout books (CBZ, fixed-layout
// EPUB). Reflowable formats are excluded — paginator.js' built-in
// touch+snap handler already owns swipes there. Thresholds mirror
// readest's: ≥30px horizontal, dominance over vertical, ≥0.2 px/ms
// release velocity (`apps/readest-app/src/app/reader/hooks/usePagination.ts`).
readflexRegisterGesture(
  'swipe-flip-fixed-layout',
  detail =>
    detail.phase === 'end'
    && globalThis.reader?.view?.isFixedLayout === true,
  detail => {
    const { deltaX, deltaY, deltaT } = detail
    if (Math.abs(deltaX) <= Math.abs(deltaY)) return false
    if (Math.abs(deltaX) < 30) return false
    const vx = Math.abs(deltaX / (deltaT || 1))
    if (vx < 0.2) return false
    const renderer = globalThis.reader?.view?.renderer
    if (!renderer) return false
    // dx > 0 → swipe right → previous page in LTR (next in RTL); the
    // renderer's own next/prev already accounts for the book's reading
    // direction internally.
    if (deltaX > 0) renderer.prev?.()
    else renderer.next?.()
    return true
  },
  100,
)

// get varible from url
var urlParams = new URLSearchParams(window.location.search)
var importing = JSON.parse(urlParams.get('importing'))
var url = JSON.parse(urlParams.get('url'))
var initialCfi = JSON.parse(urlParams.get('initialCfi'))
var initialProgress = JSON.parse(urlParams.get('initialProgress'))
var sourceType = JSON.parse(urlParams.get('sourceType') ?? '"book"')
globalThis.readflexSourceType = sourceType
var pageProgressionDirection = JSON.parse(
  urlParams.get('pageProgressionDirection') ?? 'null'
)
globalThis.readflexPageProgressionDirection =
  pageProgressionDirection === 'rtl' ? 'rtl' : ''
var style = JSON.parse(urlParams.get('style'))
var readingRules = JSON.parse(urlParams.get('readingRules'))
// Optional caller-supplied display name. Used by formats with no embedded
// metadata (e.g. CBZ sets `book.metadata.title = file.name`) so the title
// doesn't fall back to the URL pathname.
var nameParam = urlParams.get('name')
var name = nameParam ? JSON.parse(nameParam)
  : new URL(url, window.location.origin).pathname

// Use a `Range:`-aware loader so foliate-js / zip.js can read just the
// bytes they need rather than downloading the whole book before rendering.
// See ./remote_file.js for the contract this implements.
import('./remote_file.js')
  .then(({ RemoteFile }) =>
    new RemoteFile(url, { name }).open(),
  )
  .then(file => open(file, initialCfi, initialProgress))
  .catch(e => {
    console.error(e)
    // Surface import errors back to Dart immediately. Without this the
    // Dart side has no way to know the JS pipeline failed and falls
    // back to its 30-second extraction timeout, leaving the user
    // staring at a "Uploading…" spinner long after foliate-js has
    // already given up. Only sent during import so it can't interfere
    // with reader-mode error reporting.
    if (importing) {
      callFlutter('onImportError', { message: String(e && e.message || e) })
    }
  })
