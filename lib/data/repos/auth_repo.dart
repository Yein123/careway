import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthRepo {
  /// Signed-in user's uid, or null when signed out.
  Stream<String?> get authState;
  String? get currentUid;
  Future<String> signIn(String email, String password);
  Future<String> signUp(String email, String password);
  Future<void> signOut();
  Future<void> sendPasswordReset(String email);
}

/// Thrown with a user-facing message for sign-in/sign-up failures.
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

String authMessage(String code) => switch (code) {
  'email-already-in-use' =>
    'An account with this email already exists. Try signing in.',
  'weak-password' => 'Choose a password with at least 8 characters.',
  'invalid-email' => 'Enter a valid email address.',
  'wrong-password' ||
  'user-not-found' ||
  'invalid-credential' => 'Email or password is incorrect.',
  'too-many-requests' =>
    'Too many attempts. Please wait a minute and try again.',
  'network-request-failed' =>
    'No internet connection. Check your connection and try again.',
  _ => 'Something went wrong. Please try again.',
};

class FirebaseAuthRepo implements AuthRepo {
  FirebaseAuthRepo(this._auth);
  final FirebaseAuth _auth;

  @override
  Stream<String?> get authState => _auth.authStateChanges().map((u) => u?.uid);

  @override
  String? get currentUid => _auth.currentUser?.uid;

  @override
  Future<String> signIn(String email, String password) async {
    try {
      final c = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return c.user!.uid;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(authMessage(e.code));
    }
  }

  @override
  Future<String> signUp(String email, String password) async {
    try {
      final c = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return c.user!.uid;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(authMessage(e.code));
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(authMessage(e.code));
    }
  }
}
