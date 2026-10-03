// Timings use the document navigation clock, not Flutter's monotonic clock.
export class ReaderStartupTrace {
    #now
    #report
    #previous = 0
    #stages = []
    #finished = false

    constructor({ now = () => performance.now(), report } = {}) {
        this.#now = now
        this.#report = report ?? (data => console.info('[reader-startup] ' + JSON.stringify(data)))
    }

    mark(stage) {
        if (this.#finished) return
        const elapsedMs = this.#now()
        this.#stages.push({ stage, elapsedMs, durationMs: elapsedMs - this.#previous })
        this.#previous = elapsedMs
    }

    finish(stage) {
        if (this.#finished) return
        this.mark(stage)
        this.#finished = true
        // Diagnostics must never make a successfully opened book fail.
        try { this.#report({ stages: this.#stages, totalMs: this.#previous }) } catch {}
        this.#stages = []
    }
}

const trace = new URLSearchParams(globalThis.location?.search).get('traceStartup') === 'true'
    ? new ReaderStartupTrace() : null

export const markReaderStartup = stage => trace?.mark(stage)
export const finishReaderStartup = stage => trace?.finish(stage)
