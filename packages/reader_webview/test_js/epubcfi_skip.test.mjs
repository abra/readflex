import assert from 'node:assert/strict'
import test from 'node:test'

import * as CFI from '../assets/foliate-js/src/epubcfi.js'

globalThis.NodeFilter = {
  FILTER_ACCEPT: 1,
  FILTER_REJECT: 2,
  FILTER_SKIP: 3,
}

class FakeDocument {
  constructor(root) {
    this.documentElement = root
    assignOwnerDocument(root, this)
  }

  getElementById(id) {
    return collectElements(this.documentElement).find(node => node.id === id) ?? null
  }

  createRange() {
    return new FakeRange()
  }
}

class FakeElement {
  constructor(tagName, { id = '' } = {}) {
    this.nodeType = 1
    this.tagName = tagName.toUpperCase()
    this.id = id
    this.childNodes = []
    this.parentNode = null
    this.attributes = new Set()
  }

  get firstChild() {
    return this.childNodes[0] ?? null
  }

  get lastChild() {
    return this.childNodes[this.childNodes.length - 1] ?? null
  }

  append(...children) {
    for (const child of children) {
      child.parentNode = this
      child.ownerDocument = this.ownerDocument
      this.childNodes.push(child)
      if (child.nodeType === 1) assignOwnerDocument(child, this.ownerDocument)
    }
  }

  setAttribute(name) {
    this.attributes.add(name)
  }

  hasAttribute(name) {
    return this.attributes.has(name)
  }
}

class FakeText {
  constructor(text) {
    this.nodeType = 3
    this.nodeValue = text
    this.textContent = text
    this.parentNode = null
  }
}

class FakeRange {
  setStart(node, offset) {
    this.startContainer = node
    this.startOffset = offset
  }

  setEnd(node, offset) {
    this.endContainer = node
    this.endOffset = offset
    this.collapsed = this.startContainer === node && this.startOffset === offset
  }

  selectNode(node) {
    this.setStart(node.parentNode, node.parentNode.childNodes.indexOf(node))
    this.setEnd(node.parentNode, node.parentNode.childNodes.indexOf(node) + 1)
  }
}

const element = (tagName, options) => new FakeElement(tagName, options)
const text = value => new FakeText(value)

const assignOwnerDocument = (node, doc) => {
  node.ownerDocument = doc
  for (const child of node.childNodes ?? []) assignOwnerDocument(child, doc)
}

const collectElements = root => {
  const elements = []
  const visit = node => {
    if (node.nodeType !== 1) return
    elements.push(node)
    for (const child of node.childNodes) visit(child)
  }
  visit(root)
  return elements
}

const buildDocument = ({ wrapTable }) => {
  const html = element('html')
  const body = element('body')
  const paragraph = element('p')
  const table = element('table')
  const row = element('tr')
  const cell = element('td')
  const cellText = text('cell text')

  html.append(body)
  paragraph.append(text('intro text'))
  cell.append(cellText)
  row.append(cell)
  table.append(row)

  if (wrapTable) {
    const wrapper = element('div')
    wrapper.setAttribute('cfi-skip')
    wrapper.append(table)
    body.append(paragraph, wrapper)
  } else {
    body.append(paragraph, table)
  }

  const doc = new FakeDocument(html)
  return { doc, cellText }
}

const rangeFor = textNode => {
  const range = new FakeRange()
  range.setStart(textNode, 1)
  range.setEnd(textNode, 4)
  return range
}

test('cfi-skip wrappers are transparent when creating and resolving CFIs', () => {
  const plain = buildDocument({ wrapTable: false })
  const wrapped = buildDocument({ wrapTable: true })

  const plainCfi = CFI.fromRange(rangeFor(plain.cellText))
  const wrappedCfi = CFI.fromRange(rangeFor(wrapped.cellText))

  assert.equal(wrappedCfi, plainCfi)

  const resolved = CFI.toRange(wrapped.doc, CFI.parse(plainCfi))
  assert.equal(resolved.startContainer, wrapped.cellText)
  assert.equal(resolved.startOffset, 1)
  assert.equal(resolved.endContainer, wrapped.cellText)
  assert.equal(resolved.endOffset, 4)
})
