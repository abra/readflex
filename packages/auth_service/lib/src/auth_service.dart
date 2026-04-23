/// User authentication state exposed by [AuthService].
enum AuthStatus { unauthenticated, authenticated }

/// Identity of the currently signed-in user. `null` when
/// [AuthService.status] is [AuthStatus.unauthenticated].
class AuthUser {
  const AuthUser({required this.id, required this.email});

  final String id;
  final String email;
}

/// Contract for authentication (sign in / sign up / sign out) and
/// reactive auth state.
///
/// Tokens are persisted in `flutter_secure_storage`
/// (Keychain / EncryptedSharedPreferences) by the production
/// implementation. [statusStream] drives [AuthScope] so the widget tree
/// rebuilds when the user signs in or out.
abstract class AuthService {
  /// Current auth status.
  AuthStatus get status;

  /// Current user, or null if unauthenticated.
  AuthUser? get currentUser;

  /// Reactive auth state stream.
  Stream<AuthStatus> get statusStream;

  /// Sign in with email and password.
  Future<void> signIn({required String email, required String password});

  /// Register a new account.
  Future<void> signUp({required String email, required String password});

  /// Sign out and clear stored tokens.
  Future<void> signOut();

  /// Dispose resources.
  void dispose();
}

/// Stub [AuthService] that reports [AuthStatus.unauthenticated] forever
/// and accepts sign-in/sign-up calls as no-ops. Used during development
/// until the real auth backend is wired; swap for a real implementation
/// (Firebase Auth, custom backend) in `DependenciesContainer`.
class NoopAuthService implements AuthService {
  const NoopAuthService();

  @override
  AuthStatus get status => AuthStatus.unauthenticated;

  @override
  AuthUser? get currentUser => null;

  @override
  Stream<AuthStatus> get statusStream => const Stream.empty();

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signUp({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {}

  @override
  void dispose() {}
}
