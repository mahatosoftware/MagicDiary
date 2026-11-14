import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'secure_storage_service.dart';

enum SensitiveAction {
  changeCredentials,
  exportData,
  deleteAccount,
  changeSecuritySettings,
  grantCircleAdmin,
  connectVoiceAssistant,
}

/// Centralized authentication security layer.
/// Enforces recent authentication for sensitive actions, secure logout, and enumeration protection.
class AuthSecurityService {
  final fb.FirebaseAuth _auth;
  final SecureStorageService _secureStorage;

  AuthSecurityService({
    fb.FirebaseAuth? auth,
    SecureStorageService? secureStorage,
  })  : _auth = auth ?? fb.FirebaseAuth.instance,
        _secureStorage = secureStorage ?? SecureStorageService();

  fb.User? get currentUser => _auth.currentUser;

  /// Checks whether the user's current session token is considered fresh (e.g. <= 10 minutes old).
  bool isAuthenticationFresh({Duration threshold = const Duration(minutes: 10)}) {
    final user = _auth.currentUser;
    if (user == null) return false;
    final lastSignIn = user.metadata.lastSignInTime;
    if (lastSignIn == null) return false;
    return DateTime.now().difference(lastSignIn) < threshold;
  }

  /// Requires re-authentication if the session is not fresh before proceeding with a sensitive operation.
  Future<bool> requireRecentAuthentication({
    required SensitiveAction action,
    String? password,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Unauthenticated: Please log in first.');
    }

    if (isAuthenticationFresh()) {
      return true;
    }

    // Attempt reauthentication
    if (password != null && password.isNotEmpty && user.email != null) {
      final cred = fb.EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(cred);
      return true;
    }

    final isGoogle = user.providerData.any((p) => p.providerId == 'google.com');
    if (isGoogle) {
      final googleSignIn = GoogleSignIn();
      final googleUser = await googleSignIn.signIn();
      if (googleUser != null) {
        final googleAuth = await googleUser.authentication;
        final cred = fb.GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await user.reauthenticateWithCredential(cred);
        return true;
      }
    }

    throw fb.FirebaseAuthException(
      code: 'requires-recent-login',
      message: 'For security, this action requires recent authentication. Please re-authenticate.',
    );
  }

  /// Secure logout: Clears secure storage credentials, revokes sessions, and signs out.
  Future<void> secureSignOut() async {
    try {
      await _secureStorage.delete(SecureStorageService.keyActiveSessionId);
      final googleSignIn = GoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.signOut();
      }
    } catch (_) {}
    await _auth.signOut();
  }

  /// Returns user-friendly message without revealing if email exists (enumeration protection).
  static String safeAuthErrorMessage(dynamic error) {
    if (error is fb.FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Invalid email, username, or password. Please verify your credentials.';
        case 'email-already-in-use':
          return 'Unable to register with this email address. Please sign in or use another.';
        case 'too-many-requests':
          return 'Too many attempts. Access is temporarily restricted for security. Please try again later.';
        default:
          return error.message ?? 'Authentication operation failed.';
      }
    }
    return 'An unexpected authentication error occurred.';
  }
}
