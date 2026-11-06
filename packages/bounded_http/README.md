# bounded_http

Small Dart transport primitive shared by the backend translation, dictionary
and article-cleaner clients. It has no feature, domain or Flutter dependencies.

`postBoundedResponse` buffers one POST response within a caller-supplied byte
budget and total deadline. It counts actual stream bytes after the HTTP client's
decompression, including error bodies, without trusting `Content-Length`.
Timeout, external cancellation, stream errors and oversized responses abort
that request and cancel its body subscription. Late responses from injected
clients that ignore abort are cancelled when they arrive. The shared HTTP client
is never closed; service owners retain its lifecycle.

The helper returns an `http.Response` and leaves endpoint JSON parsing and typed
error mapping to each service. An oversized response throws
`HttpResponseTooLargeException`; timeouts use `TimeoutException`, cancellation
uses `RequestAbortedException`. An external abort signal that completes with an
error also cancels the request. A cancelled backend connection does not prove
the server stopped its work.

This package does not validate public article URLs, pin DNS, configure TLS,
choose endpoint limits or provide a general application HTTP client. Public
article downloads continue to use `remote_content_policy`.

Run `dart test` for byte-boundary, stream cancellation, deadline, late-response
and decompression coverage.
