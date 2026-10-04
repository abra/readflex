// Previews are requested by visible Contents tabs, never during book startup.
// Each UI queue serializes decoding; only a small JPEG crosses the Flutter bridge.
export const createComicThumbnail = async blob => {
    if (!blob || blob.size > 16 * 1024 * 1024) return null
    const url = URL.createObjectURL(blob)
    const image = new Image()
    let canvas
    let timeout
    try {
        image.src = url
        await Promise.race([
            image.decode(),
            new Promise((_, reject) => {
                timeout = setTimeout(() => reject(new Error('Thumbnail decode timed out')), 10000)
            }),
        ])
        const { naturalWidth: width, naturalHeight: height } = image
        if (!width || !height || width * height > 40 * 1024 * 1024) return null
        const scale = Math.min(1, 240 / width, 360 / height)
        canvas = document.createElement('canvas')
        canvas.width = Math.max(1, Math.round(width * scale))
        canvas.height = Math.max(1, Math.round(height * scale))
        const context = canvas.getContext('2d', { alpha: false })
        if (!context) return null
        context.fillStyle = '#ffffff'
        context.fillRect(0, 0, canvas.width, canvas.height)
        context.drawImage(image, 0, 0, canvas.width, canvas.height)
        const result = canvas.toDataURL('image/jpeg', 0.72)
        return result.length <= 128 * 1024 ? result : null
    } finally {
        clearTimeout(timeout)
        image.removeAttribute('src')
        URL.revokeObjectURL(url)
        if (canvas) canvas.width = canvas.height = 0
    }
}
