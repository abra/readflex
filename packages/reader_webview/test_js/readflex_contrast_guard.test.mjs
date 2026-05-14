import assert from 'node:assert/strict'
import test from 'node:test'

import {
  applyTextContrastGuard,
  contrastRatio,
  parseCssColor,
} from '../assets/foliate-js/src/readflex_contrast_guard.js'

globalThis.Node = {
  ELEMENT_NODE: 1,
  TEXT_NODE: 3,
}

class FakeStyle {
  #values = new Map()
  #priorities = new Map()

  getPropertyValue(name) {
    return this.#values.get(name) ?? ''
  }

  getPropertyPriority(name) {
    return this.#priorities.get(name) ?? ''
  }

  setProperty(name, value, priority = '') {
    this.#values.set(name, value)
    this.#priorities.set(name, priority)
  }

  removeProperty(name) {
    this.#values.delete(name)
    this.#priorities.delete(name)
  }
}

class FakeElement {
  constructor({
    tagName = 'p',
    text = 'Readable text',
    color = 'rgb(0, 0, 0)',
    backgroundColor = 'rgba(0, 0, 0, 0)',
    display = 'block',
    visibility = 'visible',
  } = {}) {
    this.tagName = tagName
    this.nodeType = Node.ELEMENT_NODE
    this.childNodes = text
      ? [{ nodeType: Node.TEXT_NODE, textContent: text }]
      : []
    this.parentElement = null
    this.style = new FakeStyle()
    this.computedStyle = { color, backgroundColor, display, visibility }
    this.attributes = new Map()
  }

  matches(selector) {
    return selector
      .split(',')
      .map(part => part.trim())
      .includes(this.tagName.toLowerCase())
  }

  closest(selector) {
    let current = this
    while (current) {
      if (selector.includes('[hidden]') && current.attributes.has('hidden')) {
        return current
      }
      if (
        selector.includes('[aria-hidden="true"]') &&
        current.attributes.get('aria-hidden') === 'true'
      ) {
        return current
      }
      if (current.matches(selector)) return current
      current = current.parentElement
    }
    return null
  }

  getAttribute(name) {
    return this.attributes.has(name) ? this.attributes.get(name) : null
  }

  setAttribute(name, value) {
    this.attributes.set(name, `${value}`)
  }

  removeAttribute(name) {
    this.attributes.delete(name)
  }
}

const makeDocument = elements => {
  const body = new FakeElement({
    tagName: 'body',
    text: '',
    backgroundColor: 'rgba(0, 0, 0, 0)',
  })

  for (const element of elements) {
    element.parentElement = body
  }

  return {
    body: {
      ...body,
      querySelectorAll(selector) {
        if (selector === '[data-readflex-contrast-guard="true"]') {
          return elements.filter(element =>
            element.getAttribute('data-readflex-contrast-guard') === 'true'
          )
        }
        return elements
      },
    },
    defaultView: {
      getComputedStyle(element) {
        return element.computedStyle
      },
    },
  }
}

test('contrastRatio reports low contrast for dark blue on dark reader background', () => {
  const darkBlue = parseCssColor('rgb(0, 0, 80)')
  const darkBackground = parseCssColor('#0f1115')

  assert.ok(contrastRatio(darkBlue, darkBackground) < 4.5)
})

test('applyTextContrastGuard patches only low-contrast text in dark themes', () => {
  const lowContrast = new FakeElement({ color: 'rgb(0, 0, 80)' })
  const readable = new FakeElement({ color: 'rgb(220, 225, 235)' })
  const doc = makeDocument([lowContrast, readable])

  applyTextContrastGuard(doc, {
    backgroundColor: '#0f1115',
    textColor: '#bcc1ca',
  })

  assert.equal(lowContrast.style.getPropertyValue('color'), '#bcc1ca')
  assert.equal(lowContrast.style.getPropertyPriority('color'), 'important')
  assert.equal(readable.style.getPropertyValue('color'), '')
})

test('applyTextContrastGuard respects local light backgrounds', () => {
  const calloutText = new FakeElement({
    color: 'rgb(20, 20, 20)',
    backgroundColor: '#ffffff',
  })
  const doc = makeDocument([calloutText])

  applyTextContrastGuard(doc, {
    backgroundColor: '#0f1115',
    textColor: '#bcc1ca',
  })

  assert.equal(calloutText.style.getPropertyValue('color'), '')
})

test('applyTextContrastGuard restores previous guard when theme becomes light', () => {
  const element = new FakeElement({ color: 'rgb(0, 0, 80)' })
  const doc = makeDocument([element])

  applyTextContrastGuard(doc, {
    backgroundColor: '#0f1115',
    textColor: '#bcc1ca',
  })
  applyTextContrastGuard(doc, {
    backgroundColor: '#faf8f4',
    textColor: '#2a2723',
  })

  assert.equal(element.style.getPropertyValue('color'), '')
  assert.equal(element.getAttribute('data-readflex-contrast-guard'), null)
})
