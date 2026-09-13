import assert from 'node:assert/strict'
import test from 'node:test'

import { sentenceContextForSelection } from '../assets/foliate-js/src/readflex_selection_context.js'

const plain = text => text.replace(/\s+/g, ' ').trim()
const unmark = text => text.replace('[[', '').replace(']]', '')

test('sentence context preserves each selected occurrence across generated passages', () => {
    for (const word of ['energy', 'devices', 'reading', 'mechanics', 'alpha']) {
        for (let sentenceIndex = 0; sentenceIndex < 12; sentenceIndex++) {
            const sentences = Array.from({ length: 12 }, (_, i) =>
                `Section ${i} mentions ${word} twice: ${word}.`)
            const sentence = sentences[sentenceIndex]
            for (const occurrence of [sentence.indexOf(word), sentence.lastIndexOf(word)]) {
                const prefix = sentences.slice(0, sentenceIndex).join('\n')
                const suffix = sentences.slice(sentenceIndex + 1).join('\n')
                const before = `${prefix}\n${sentence.slice(0, occurrence)}`
                const after = `${sentence.slice(occurrence + word.length)}\n${suffix}`
                const result = sentenceContextForSelection(before, word, after)
                assert.equal(result.contextText, sentence)
                assert.equal(result.markedContextText,
                    `${sentence.slice(0, occurrence)}[[${word}]]${sentence.slice(occurrence + word.length)}`)
                assert.equal(unmark(result.markedContextText), result.contextText)
            }
        }
    }
})

test('sentence context handles non-Latin sentence boundaries without added spaces', () => {
    const cases = [
        { locale: 'ru', before: '\u041f\u0435\u0440\u0432\u043e\u0435. \u042d\u0442\u043e ', selected: '\u0441\u043b\u043e\u0432\u043e', after: '. \u0414\u0430\u043b\u0435\u0435.', prefix: '\u042d\u0442\u043e ', suffix: '.' },
        { locale: 'ja', before: '\u524d\u306e\u6587\u3002\u3053\u308c\u306f', selected: '\u5358\u8a9e', after: '\u3067\u3059\u3002\u6b21\u306e\u6587\u3002', prefix: '\u3053\u308c\u306f', suffix: '\u3067\u3059\u3002' },
        { locale: 'zh', before: '\u4e0a\u4e00\u53e5\u3002\u8fd9\u662f', selected: '\u5355\u8bcd', after: '\u3002\u4e0b\u4e00\u53e5\u3002', prefix: '\u8fd9\u662f', suffix: '\u3002' },
        { locale: 'ar', before: '\u0623\u064a\u0646\u061f \u0647\u0630\u0647 ', selected: '\u0643\u0644\u0645\u0629', after: '\u061f \u0645\u0627\u0630\u0627\u061f', prefix: '\u0647\u0630\u0647 ', suffix: '\u061f' },
    ]
    for (const { locale, before, selected, after, prefix, suffix } of cases) {
        assert.deepEqual(sentenceContextForSelection(before, selected, after, { locale }), {
            contextText: `${prefix}${selected}${suffix}`,
            markedContextText: `${prefix}[[${selected}]]${suffix}`,
        })
    }
})

test('sentence context retains decimal punctuation and closing quotation marks', () => {
    const result = sentenceContextForSelection(
        'Earlier. "It costs 3.14 and runs ', 'well', '." Later.',
    )
    assert.deepEqual(result, {
        contextText: '"It costs 3.14 and runs well."',
        markedContextText: '"It costs 3.14 and runs [[well]]."',
    })
})

test('sentence context keeps all sentences touched by a selection', () => {
    const selected = 'first sentence.\nThe second'
    const result = sentenceContextForSelection(
        'Previous. The ', selected, ' sentence ends here. Next.',
    )
    assert.equal(result.contextText, 'The first sentence. The second sentence ends here.')
    assert.equal(result.markedContextText,
        'The [[first sentence. The second]] sentence ends here.')
    assert.equal(unmark(result.markedContextText), result.contextText)
})

test('sentence context keeps partial words and whitespace adjacent to markers', () => {
    const result = sentenceContextForSelection('Earlier. The de', 'vic', 'es work. Next.')
    assert.deepEqual(result, {
        contextText: 'The devices work.',
        markedContextText: 'The de[[vic]]es work.',
    })
    const selected = ' \n power  bank \t '
    const whitespace = sentenceContextForSelection('The', selected, 'works. Next.')
    assert.equal(whitespace.contextText, 'The power bank works.')
    assert.equal(plain(unmark(whitespace.markedContextText)), whitespace.contextText)
})

test('a bounded window only yields context when both sentence boundaries are known', () => {
    const options = { beforeClipped: true, afterClipped: true }
    assert.deepEqual(sentenceContextForSelection(
        'ipped earlier. This ', 'word', ' is selected. A clipped nex', options,
    ), {
        contextText: 'This word is selected.',
        markedContextText: 'This [[word]] is selected.',
    })
    for (const [before, after] of [
        ['ipped earlier. This ', ' is selected without an end'],
        ['ipped sentence with a ', ' here. Later.'],
    ]) {
        assert.deepEqual(sentenceContextForSelection(before, 'word', after, options), {
            contextText: 'word', markedContextText: '[[word]]',
        })
    }
})

test('an invalid document locale does not break context extraction', () => {
    assert.deepEqual(sentenceContextForSelection('Before. A ', 'word', '. After.', {
        locale: 'not_a_valid_locale!',
    }), {
        contextText: 'A word.', markedContextText: 'A [[word]].',
    })
})

test('older runtimes preserve the selection without inventing sentence boundaries', () => {
    const original = Intl.Segmenter
    try {
        Intl.Segmenter = undefined
        assert.deepEqual(sentenceContextForSelection('Before. A ', 'word', '. After.'), {
            contextText: 'word', markedContextText: '[[word]]',
        })
    } finally {
        Intl.Segmenter = original
    }
})
