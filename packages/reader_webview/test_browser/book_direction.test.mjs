import test from 'node:test'
import assert from 'node:assert/strict'
import { createHarness } from './harness.mjs'

test('direction inference preserves mixed-language sampling with at most two chapter reads', async t => {
    const { page, origin } = await createHarness(t)
    await page.goto(origin + '/blank')
    const cases = await page.evaluate(async () => {
        await import('/foliate-js/src/view.js')
        const results = []
        for (const config of [
            { count: 30, rtl: false },
            { count: 30, rtl: true },
            { count: 1, rtl: false },
            { count: 0, rtl: false },
            { count: 12, rtl: true, fail: 1 },
            { count: 12, rtl: true, configured: 'ltr' },
            { count: 12, rtl: false, configured: 'rtl' },
            { count: 12, rtl: false, language: 'ar' },
            { count: 12, rtl: false, direction: 'rtl' },
            { count: 12, rtl: true, serial: true },
        ]) {
            globalThis.readflexPageProgressionDirection = config.configured ?? ''
            let active = 0
            let peak = 0
            const reads = []
            const sections = Array.from({ length: config.count }, (_, index) => ({
                id: String(index), size: 1000,
                createDocument: async () => {
                    reads.push(index)
                    peak = Math.max(peak, ++active)
                    try {
                        await new Promise(resolve => setTimeout(resolve, 5))
                        if (index === config.fail) throw new Error('Unreadable chapter')
                        // English front matter must not override an otherwise RTL book
                        // with incorrect LTR metadata.
                        const text = config.rtl && index > 0 ? '\u0627\u0644\u0643\u062a\u0627\u0628 '.repeat(40) : 'English text'
                        return new DOMParser().parseFromString(`<p>${text}</p>`, 'text/html')
                    } finally { --active }
                },
            }))
            const book = { sections, metadata: { language: config.language ?? 'en' }, dir: config.direction ?? 'ltr' }
            if (!config.serial) book.supportsConcurrentDocumentReads = true
            const view = document.createElement('foliate-view')
            document.body.append(view)
            await view.open(book)
            results.push({ config, reads, peak, direction: view.pageProgressionDirection })
            view.remove()
        }
        return results
    })
    for (const { config, reads, peak, direction } of cases) {
        const early = config.configured || config.language === 'ar' || config.direction === 'rtl'
        assert.equal(direction, config.configured || (config.rtl || config.language === 'ar' || config.direction === 'rtl' ? 'rtl' : 'ltr'))
        assert.equal(reads.length, early ? 0 : Math.min(config.count, 12))
        assert.equal(new Set(reads).size, reads.length)
        assert.equal(peak, early ? 0 : Math.min(config.count, config.serial ? 1 : 2))
        if (config.count > 12 && !early) {
            for (const index of [0, 1, 2, 14, 29]) assert.ok(reads.includes(index))
        }
    }
})
