import test from 'node:test'
import assert from 'node:assert/strict'
import { ReaderStartupTrace, markReaderStartup, finishReaderStartup } from '../assets/foliate-js/src/readflex_startup.js'

test('startup reports monotonic stage durations once, without reader content', () => {
    let now = 12
    const reports = []
    const trace = new ReaderStartupTrace({ now: () => now, report: data => reports.push(data) })
    trace.mark('modules-ready')
    now = 42
    trace.mark('format-ready')
    now = 57
    trace.finish('location-ready')
    trace.mark('late-relocation')
    trace.finish('duplicate-ready')
    assert.deepEqual(reports, [{ totalMs: 57, stages: [
        { stage: 'modules-ready', elapsedMs: 12, durationMs: 12 },
        { stage: 'format-ready', elapsedMs: 42, durationMs: 30 },
        { stage: 'location-ready', elapsedMs: 57, durationMs: 15 },
    ] }])
})

test('disabled startup tracing does not read the clock or report', t => {
    t.mock.method(performance, 'now', () => { throw new Error('Clock read while disabled') })
    t.mock.method(console, 'info', () => { throw new Error('Unexpected logging') })
    markReaderStartup('modules-ready')
    finishReaderStartup('location-ready')
})

test('a broken diagnostic sink cannot interrupt startup', () => {
    const trace = new ReaderStartupTrace({ now: () => 1, report: () => { throw new Error('Sink failed') } })
    assert.doesNotThrow(() => trace.finish('location-ready'))
})
