# auth_service

Authentication state, token storage, and an `InheritedWidget` scope for the
UI. Readflex has no forced registration — users sign up from Profile when
they want to sync or unlock premium features.

Tokens are stored in `flutter_secure_storage`
(iOS Keychain / Android EncryptedSharedPreferences) — **never** in
`SharedPreferences`, which is plaintext.

## Public API

| Symbol            | Type             | Purpose                                           |
|-------------------|------------------|---------------------------------------------------|
| `AuthService`     | abstract class   | Status, current user, stream, sign-in / sign-up   |
| `NoopAuthService` | concrete         | Stub — always unauthenticated, safe for dev       |
| `AuthScope`       | InheritedWidget  | Exposes `AuthService` to the widget tree          |
| `AuthUser`        | data class       | `{id, email}`                                     |
| `AuthStatus`      | enum             | `unauthenticated` / `authenticated`               |

### Key methods

- `Stream<AuthStatus> get statusStream` — reactive auth state.
- `Future<void> signIn({email, password})`
- `Future<void> signUp({email, password})`
- `Future<void> signOut()` — also clears stored tokens.

## Usage

```dart
// In widget tree (root_context.dart)
AuthScope(
  service: dependencies.authService,
  child: MaterialContext(...),
)

// In a widget
final auth = AuthScope.of(context);
final isSignedIn = auth.status == AuthStatus.authenticated;

// Reactive
StreamBuilder<AuthStatus>(
  stream: auth.statusStream,
  builder: (context, snap) => ...,
);
```

## Where it fits

Registered on `DependenciesContainer.authService` in
`lib/app/composition.dart` (currently `NoopAuthService`) and mounted as
`AuthScope` inside `RootContext`. The real implementation will wrap the
backend auth API and persist tokens via `flutter_secure_storage` — callers
continue to depend only on the `AuthService` interface and `AuthScope.of()`.
