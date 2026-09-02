# remote_content_policy

Shared outbound HTTP safety policy for user-controlled remote URLs.

## Public API

| Symbol | Purpose |
|--------|---------|
| `RemoteUriPolicy` | Validates an HTTP(S) URI before a client connects |
| `RemoteUriPolicyException` | Typed rejection containing a stable reason |
| `RemoteHostAddressResolver` | Injectable DNS boundary used by production code and tests |
| `createPublicRemoteHttpClient()` | Creates a direct client that connects to the validated IP without resolving the hostname again |

## Policy

Validation rejects URL credentials, unsupported schemes, missing hosts,
localhost-style names, private/link-local/loopback/documentation IP ranges, and
hostnames whose DNS answers are empty, unsafe, or mix public and unsafe
addresses. IPv4-mapped IPv6 addresses are evaluated as IPv4.

Callers must validate both the initial URI and every redirect target. For
user-controlled content, the provided HTTP client factory pins each connection
to the exact DNS result accepted by the policy while retaining the original
hostname for TLS certificate validation. This closes the validation/connection
DNS-rebinding window. The package does not perform requests, follow redirects,
or own download limits; those remain with the service or repository that owns
the request lifecycle.

## Consumers

- `article_extraction_service` guards its client-side HTML fallback.
- `article_repository` guards article image and cover downloads.
