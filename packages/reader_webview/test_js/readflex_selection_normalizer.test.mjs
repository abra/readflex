import assert from 'node:assert/strict'
import test from 'node:test'

import { normalizeTextRange } from '../assets/foliate-js/src/readflex_selection_normalizer.js'

test('expands a partial single-word selection to the full word', () => {
  const text = 'The team will circumvent the restriction.'
  const selected = 'cumven'
  const start = text.indexOf(selected)
  const result = normalizeTextRange(text, start, start + selected.length)

  assert.equal(result.selectedText, selected)
  assert.equal(result.normalizedText, 'circumvent')
  assert.equal(result.selectionKind, 'partial_word')
})

test('expands both edges when selection cuts across two words', () => {
  const text = 'Stakeholders discussed the rollout.'
  const selected = 'holders dis'
  const start = text.indexOf(selected)
  const result = normalizeTextRange(text, start, start + selected.length)

  assert.equal(result.selectedText, selected)
  assert.equal(result.normalizedText, 'Stakeholders discussed')
  assert.equal(result.selectionKind, 'partial_span')
})

test('keeps exact word selections unchanged', () => {
  const text = 'It is time to kick things off.'
  const selected = 'off'
  const start = text.indexOf(selected)
  const result = normalizeTextRange(text, start, start + selected.length)

  assert.equal(result.selectedText, selected)
  assert.equal(result.normalizedText, selected)
  assert.equal(result.selectionKind, 'exact')
})

test('keeps apostrophe and hyphenated words as one lexical unit', () => {
  const text = "The long-term plan isn't final."
  const selected = 'term plan is'
  const start = text.indexOf(selected)
  const result = normalizeTextRange(text, start, start + selected.length)

  assert.equal(result.normalizedText, "long-term plan isn't")
  assert.equal(result.selectionKind, 'partial_span')
})
