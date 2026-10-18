// Readflex: serves pdf.js byte ranges from a File-like object (`size`,
// `slice(start, end).arrayBuffer()`), so pdf.js reads only the parts it needs
// instead of a copy of the whole file. pdf.js reports no transport errors, so
// a failed read rejects `failed` for the caller to race against loading.
export const createFileRangeTransport = (Transport, file) => {
    let fail
    const failed = new Promise((_, reject) => { fail = reject })
    failed.catch(() => {})
    let aborted = false

    class FileRangeTransport extends Transport {
        requestDataRange(begin, end) {
            file.slice(begin, end).arrayBuffer().then(
                buffer => { if (!aborted) this.onDataRange(begin, new Uint8Array(buffer)) },
                error => fail(error))
        }
        abort() {
            aborted = true
        }
    }

    return { transport: new FileRangeTransport(file.size, null), failed }
}
