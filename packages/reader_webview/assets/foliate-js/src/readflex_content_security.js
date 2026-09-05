import DOMPurify from './vendor/purify.js'

// Publisher documents share a DOM with trusted reader code for selection and
// pagination. Sanitize before creating a navigable Blob, never after iframe load.
export function sanitizePublisherDocument(doc) {
    DOMPurify.sanitize(doc.documentElement, {
        IN_PLACE: true,
        WHOLE_DOCUMENT: true,
        ADD_TAGS: ['link', 'meta'],
        ADD_ATTR: ['epub:type'],
        FORBID_TAGS: ['base', 'form', 'input', 'button', 'textarea', 'select'],
        FORBID_ATTR: ['srcset'],
    })
    for (const meta of doc.querySelectorAll('meta[http-equiv]')) meta.remove()
    for (const link of doc.querySelectorAll('link')) {
        if (link.getAttribute('rel')?.toLowerCase() !== 'stylesheet') link.remove()
    }
    // XML processing instructions can import stylesheets outside the loader.
    for (const node of Array.from(doc.childNodes)) {
        if (node.nodeType === Node.PROCESSING_INSTRUCTION_NODE) node.remove()
    }
    const head = doc.querySelector('head')
    if (head) {
        const policy = doc.createElementNS('http://www.w3.org/1999/xhtml', 'meta')
        policy.setAttribute('http-equiv', 'Content-Security-Policy')
        policy.setAttribute('content', "script-src 'none'; object-src 'none'; frame-src 'none'; connect-src 'none'; base-uri 'none'; form-action 'none'")
        head.prepend(policy)
    }
}

export function articleContentFragment(html) {
    const fragment = DOMPurify.sanitize(html, {
        RETURN_DOM_FRAGMENT: true,
        ALLOWED_TAGS: ['p', 'span', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'figure',
            'img', 'figcaption', 'ul', 'ol', 'li', 'blockquote', 'pre', 'code',
            'em', 'strong', 'b', 'i', 'br', 'hr', 'a', 'div', 'table', 'thead',
            'tbody', 'tfoot', 'tr', 'th', 'td', 'caption', 'kbd', 'samp'],
        ALLOWED_ATTR: ['id', 'alt', 'title', 'src', 'href', 'lang', 'dir',
            'class', 'colspan', 'rowspan', 'scope'],
    })
    // Also protects articles saved by older app versions with active remote URLs.
    for (const image of fragment.querySelectorAll('img[src]')) {
        if (!/^images\/[a-zA-Z0-9_-]+\.(?:png|jpe?g|gif|webp|avif)$/.test(image.getAttribute('src'))) {
            image.removeAttribute('src')
        }
    }
    return fragment
}
