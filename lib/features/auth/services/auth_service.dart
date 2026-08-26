import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../repositories/user_repository.dart';
import '../models/user_model.dart';
import '../../../core/services/google_sign_in_client.dart';

class AuthService {
  final FirebaseAuth _auth;
  final UserRepository _userRepo;

  // Use the shared singleton so Calendar scope is always included
  GoogleSignIn get _google => googleSignInClient;

  AuthService({FirebaseAuth? auth, UserRepository? userRepo})
      : _auth = auth ?? FirebaseAuth.instance,
        _userRepo = userRepo ?? UserRepository();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // ── Email / Password ─────────────────────────────────────────────────────

  Future<UserModel> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final firebaseUser = credential.user!;
    await firebaseUser.updateDisplayName(name);

    final newUser = UserModel(
      id: firebaseUser.uid,
      name: name,
      email: email,
    );
    // Fire-and-forget — don't block auth flow on Firestore write
    _userRepo.saveUser(newUser).catchError((_) {});
    return newUser;
  }

  Future<UserModel?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final firebaseUser = credential.user;
    if (firebaseUser == null) return null;
    try {
      return await _userRepo.getUser(firebaseUser.uid);
    } catch (_) {
      return null;
    }
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // ── Google ───────────────────────────────────────────────────────────────

  Future<UserModel?> signInWithGoogle() async {
    final googleUser = await _google.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    final firebaseUser = userCredential.user;
    if (firebaseUser == null) return null;

    UserModel? existing;
    try {
      existing = await _userRepo.getUser(firebaseUser.uid);
    } catch (_) {}

    if (existing == null) {
      final newUser = UserModel(
        id: firebaseUser.uid,
        name: firebaseUser.displayName ?? 'Fighter',
        email: firebaseUser.email ?? '',
        avatarUrl: firebaseUser.photoURL ?? '',
      );
      // Wait for save — if it fails the user still has a valid auth session
      try {
        await _userRepo.saveUser(newUser);
      } catch (_) {}
      return newUser;
    }
    return existing;
  }

  // ── Sign out ─────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _auth.signOut();
    await _google.signOut();
  }

  // ── Delete account ───────────────────────────────────────────────────────

  /// Permanently deletes the user's account and all associated data.
  ///
  /// Removes the user from every league and deletes their Firestore document,
  /// then deletes the Firebase Auth account. May throw a [FirebaseAuthException]
  /// with code `requires-recent-login` if the session is too old; callers should
  /// handle that by asking the user to sign in again.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // 1. Delete Firestore data first (while still authenticated).
    await _userRepo.deleteUserData(user.uid);

    // 2. Delete the Firebase Auth account (may require recent login).
    await user.delete();

    // 3. Clear any lingering Google session.
    try {
      await _google.signOut();
    } catch (_) {}
  }
}

