import assert from 'node:assert/strict'
import test from 'node:test'

import {
  applyWideTableGestureGuard,
  directionCountsFromText,
  findScrollableWideTable,
  inferDocumentDirection,
  markInlineImages,
  normalizeCodeLikeBlocks,
  normalizeDocumentLanguageAndDirection,
  normalizeLoadedDocument,
  shouldWideTableConsumeTouch,
  shouldWideTableConsumeWheel,
  wrapWideTables,
} from '../assets/foliate-js/src/readflex_document_normalizer.js'

globalThis.Node = {
  ELEMENT_NODE: 1,
  TEXT_NODE: 3,
}

class FakeStyle {
  #values = new Map()
  #priorities = new Map()

  setProperty(name, value, priority = '') {
    this.#values.set(name, value)
    this.#priorities.set(name, priority)
  }

  getPropertyValue(name) {
    return this.#values.get(name) ?? ''
  }

  getPropertyPriority(name) {
    return this.#priorities.get(name) ?? ''
  }
}

class FakeClassList {
  #tokens = new Set()

  add(token) {
    this.#tokens.add(token)
  }

  contains(token) {
    return this.#tokens.has(token)
  }

  toString() {
    return [...this.#tokens].join(' ')
  }
}

class FakeElement {
  constructor(tagName, { text = '', className = '', id = '', computedStyle = {} } = {}) {
    this.tagName = tagName.toUpperCase()
    this.nodeType = Node.ELEMENT_NODE
    this.childNodes = []
    this.parentNode = null
    this.className = className
    this.id = id
    this.dir = ''
    this.lang = ''
    this.dataset = {}
    this.attributes = new Map()
    this.style = new FakeStyle()
    this.classList = new FakeClassList()
    this.computedStyle = {
      display: 'block',
      fontFamily: 'serif',
      whiteSpace: 'normal',
      ...computedStyle,
    }
    if (className) {
      for (const token of className.split(/\s+/).filter(Boolean)) {
        this.classList.add(token)
      }
    }
    if (text) this.append(textNode(text))
  }

  get parentElement() {
    return this.parentNode?.nodeType === Node.ELEMENT_NODE ? this.parentNode : null
  }

  get textContent() {
    return this.childNodes.map(node => node.textContent ?? '').join('')
  }

  set textContent(value) {
    this.childNodes = [textNode(value)]
  }

  setAttribute(name, value = '') {
    this.attributes.set(name, String(value))
  }

  getAttribute(name) {
    return this.attributes.has(name) ? this.attributes.get(name) : null
  }

  hasAttribute(name) {
    return this.attributes.has(name)
  }

  append(child) {
    if (child.parentNode) {
      const siblings = child.parentNode.childNodes
      const index = siblings.indexOf(child)
      if (index >= 0) siblings.splice(index, 1)
    }
    child.parentNode = this
    this.childNodes.push(child)
  }

  contains(node) {
    let current = node
    while (current) {
      if (current === this) return true
      current = current.parentNode
    }
    return false
  }

  before(node) {
    const parent = this.parentNode
    assert.ok(parent, 'node must have a parent before insertion')
    const index = parent.childNodes.indexOf(this)
    assert.notEqual(index, -1)
    node.parentNode = parent
    parent.childNodes.splice(index, 0, node)
  }

  closest(selector) {
    let current = this
    while (current) {
      if (selector.includes('.readflex-wide-table') && current.className === 'readflex-wide-table') {
        return current
      }
      if (selector.includes('.readflex-code-block') && current.classList?.contains('readflex-code-block')) {
        return current
      }
      if (selector.includes('pre') && current.tagName === 'PRE') {
        return current
      }
      current = current.parentNode
    }
    return null
  }

  querySelectorAll(selector) {
    const all = []
    const visit = node => {
      if (node.nodeType !== Node.ELEMENT_NODE) return
      for (const child of node.childNodes) visit(child)
      if (matchesSelector(node, selector)) all.push(node)
    }
    visit(this)
    return all
  }
}

const textNode = text => ({
  nodeType: Node.TEXT_NODE,
  textContent: text,
  parentNode: null,
})

const matchesSelector = (node, selector) => {
  if (selector === '*') return true
  if (selector === 'table') return node.tagName === 'TABLE'
  if (selector === 'img') return node.tagName === 'IMG'
  if (selector === 'div, p, section, article, li') {
    return ['DIV', 'P', 'SECTION', 'ARTICLE', 'LI'].includes(node.tagName)
  }

  return selector
    .split(',')
    .map(part => part.trim().split(':')[0].toUpperCase())
    .some(tag => tag && node.tagName === tag)
}

class FakeDocument {
  constructor(elements = []) {
    this.documentElement = new FakeElement('html')
    this.head = new FakeElement('head')
    this.body = new FakeElement('body')
    this.documentElement.append(this.head)
    this.documentElement.append(this.body)
    for (const element of elements) this.body.append(element)
    this.listeners = new Map()
    this.defaultView = {
      getComputedStyle(element) {
        return element.computedStyle
      },
    }
  }

  addEventListener(type, listener, options) {
    const listeners = this.listeners.get(type) ?? []
    listeners.push({ listener, options })
    this.listeners.set(type, listeners)
  }

  createElement(tagName) {
    return new FakeElement(tagName)
  }

  getElementById(id) {
    const nodes = [this.documentElement, ...this.documentElement.querySelectorAll('*')]
    return nodes.find(node => node.id === id) ?? null
  }

  querySelectorAll(selector) {
    return this.body.querySelectorAll(selector)
  }
}

test('wrapWideTables wraps tables once', () => {
  const table = new FakeElement('table')
  const doc = new FakeDocument([table])

  wrapWideTables(doc)
  wrapWideTables(doc)

  assert.equal(table.parentNode.className, 'readflex-wide-table')
  assert.equal(table.parentNode.hasAttribute('cfi-skip'), true)
  assert.equal(doc.body.childNodes.filter(node => node.className === 'readflex-wide-table').length, 1)
})

test('wide table gesture guard only consumes scrollable wrapper gestures', () => {
  const table = new FakeElement('table')
  const doc = new FakeDocument([table])
  wrapWideTables(doc)
  const wrapper = table.parentNode
  wrapper.clientWidth = 100
  wrapper.scrollWidth = 180
  wrapper.clientHeight = 100
  wrapper.scrollHeight = 100

  assert.equal(findScrollableWideTable(table), wrapper)
  assert.equal(shouldWideTableConsumeTouch(wrapper, 12, 2), true)
  assert.equal(shouldWideTableConsumeTouch(wrapper, 2, 12), false)
  assert.equal(shouldWideTableConsumeWheel(wrapper, 9, 1), true)
  assert.equal(shouldWideTableConsumeWheel(wrapper, 1, 9), false)

  wrapper.scrollWidth = 102
  assert.equal(findScrollableWideTable(table), null)
})

test('applyWideTableGestureGuard installs capture listeners once', () => {
  const table = new FakeElement('table')
  const doc = new FakeDocument([table])

  applyWideTableGestureGuard(doc)
  applyWideTableGestureGuard(doc)

  assert.equal(doc.documentElement.getAttribute('data-readflex-wide-table-gesture-guard'), 'true')
  assert.equal(doc.listeners.get('touchstart').length, 1)
  assert.equal(doc.listeners.get('touchmove').length, 1)
  assert.equal(doc.listeners.get('wheel').length, 1)
})

test('markInlineImages preserves inline image paragraphs from image-only CSS', () => {
  const paragraph = new FakeElement('p')
  const image = new FakeElement('img')
  paragraph.append(textNode('Figure '))
  paragraph.append(image)
  paragraph.append(textNode(' appears inline.'))
  const doc = new FakeDocument([paragraph])

  markInlineImages(doc)

  assert.equal(image.classList.contains('has-text-siblings'), true)
})

test('normalizeCodeLikeBlocks marks long code-looking blocks', () => {
  const code = new FakeElement('div', {
    className: 'ProgramCode',
    text: 'public class Example { private final String value; public String value() { return value; } }',
  })
  const doc = new FakeDocument([code])

  normalizeCodeLikeBlocks(doc)

  assert.equal(code.classList.contains('readflex-code-block'), true)
})

test('normalizeLoadedDocument runs the full safe post-load pipeline', () => {
  const table = new FakeElement('table')
  const paragraph = new FakeElement('p')
  const image = new FakeElement('img')
  paragraph.append(textNode('Inline '))
  paragraph.append(image)
  const code = new FakeElement('div', {
    className: 'code-listing',
    text: 'import package.example.Foo; public class Foo { private final String value; public void run() { if (value != null) { return; } } }',
  })
  const doc = new FakeDocument([table, paragraph, code])

  normalizeLoadedDocument(doc)

  assert.equal(table.parentNode.className, 'readflex-wide-table')
  assert.equal(image.classList.contains('has-text-siblings'), true)
  assert.equal(code.classList.contains('readflex-code-block'), true)
})

test('directionCountsFromText counts rtl and ltr scripts', () => {
  const counts = directionCountsFromText(
    'intro text ' + '\u0627\u0644\u0639\u0631\u0628\u064a\u0629'.repeat(3),
  )

  assert.ok(counts.rtl > counts.ltr)
  assert.ok(counts.ltr > 0)
})

test('inferDocumentDirection returns rtl when rtl script dominates', () => {
  const doc = new FakeDocument([
    new FakeElement('p', { text: '\u0645\u0631\u062d\u0628\u0627 \u0647\u0630\u0627 \u0646\u0635 \u0639\u0631\u0628\u064a \u0637\u0648\u064a\u0644' }),
  ])

  assert.equal(inferDocumentDirection(doc), 'rtl')
})

test('normalizeDocumentLanguageAndDirection applies book rtl direction to the document', () => {
  const paragraph = new FakeElement('p', { text: '\u0645\u0631\u062d\u0628\u0627' })
  const doc = new FakeDocument([paragraph])

  normalizeDocumentLanguageAndDirection(doc, {
    language: { canonical: 'ar', isCJK: false, direction: 'rtl' },
    sourceType: 'book',
  })

  assert.equal(doc.documentElement.lang, 'ar')
  assert.equal(doc.documentElement.dir, 'rtl')
  assert.equal(doc.body.dir, 'rtl')
  assert.equal(paragraph.style.getPropertyValue('direction'), '')
})

test('normalizeDocumentLanguageAndDirection infers rtl book sections despite ltr metadata', () => {
  const paragraph = new FakeElement('p', { text: '\u0627\u0644\u062d\u0645\u062f \u0644\u0644\u0647 \u0631\u0628 \u0627\u0644\u0639\u0627\u0644\u0645\u064a\u0646' })
  const doc = new FakeDocument([paragraph])

  normalizeDocumentLanguageAndDirection(doc, {
    language: { canonical: 'ms', isCJK: false, direction: 'ltr' },
    sourceType: 'book',
  })

  assert.equal(doc.documentElement.lang, 'ms')
  assert.equal(doc.documentElement.dir, 'rtl')
  assert.equal(doc.body.dir, 'rtl')
})

test('normalizeDocumentLanguageAndDirection applies rtl article direction', () => {
  const heading = new FakeElement('h1', { text: '\u0639\u0646\u0648\u0627\u0646' })
  const paragraph = new FakeElement('p', { text: '\u0645\u0631\u062d\u0628\u0627' })
  const doc = new FakeDocument([heading, paragraph])

  normalizeDocumentLanguageAndDirection(doc, {
    language: { canonical: 'ar', isCJK: false, direction: 'rtl' },
    sourceType: 'article',
  })

  assert.equal(doc.documentElement.lang, 'ar')
  assert.equal(doc.documentElement.dir, 'rtl')
  assert.equal(doc.body.dir, 'rtl')
  assert.equal(doc.documentElement.dataset.readflexTextDirection, 'rtl')
  assert.equal(paragraph.style.getPropertyValue('direction'), 'rtl')
  assert.equal(paragraph.style.getPropertyPriority('direction'), 'important')
  assert.equal(
    paragraph.style.getPropertyValue('text-align'),
    'var(--readflex-rtl-article-text-align, right)',
  )
  assert.ok(doc.getElementById('readflex-article-text-direction'))
})
