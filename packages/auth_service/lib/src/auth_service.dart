import 'dart:async';

/// User authentication state.
enum AuthStatus { unauthenticated, authenticated }

/// Authenticated user data.
class AuthUser {
  const AuthUser({required this.id, required this.email});

  final String id;
  final String email;
}

/// Auth service managing registration, login, token storage.
///
/// Tokens stored in `flutter_secure_storage` (Keychain / EncryptedSharedPreferences).
/// Exposes a [Stream<AuthStatus>] for reactive auth state.
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

/// Stub auth service — always unauthenticated.
class NoopAuthService implements AuthService {
  NoopAuthService();

  final _controller = StreamController<AuthStatus>.broadcast();

  @override
  AuthStatus get status => AuthStatus.unauthenticated;

  @override
  AuthUser? get currentUser => null;

  @override
  Stream<AuthStatus> get statusStream => _controller.stream;

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
  void dispose() => _controller.close();
}
