import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../repositories/user_repository.dart';
import '../models/user_model.dart';

// ── low-level singletons ─────────────────────────────────────────────────────

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(),
);

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(userRepo: ref.watch(userRepositoryProvider)),
);

// ── auth state ───────────────────────────────────────────────────────────────

/// Raw Firebase auth stream.
final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authServiceProvider).authStateChanges,
);

/// Current Firestore UserModel, updated in real-time.
final currentUserProvider = StreamProvider<UserModel?>(
  (ref) {
    final authState = ref.watch(authStateProvider);
    final uid = authState.valueOrNull?.uid;
    if (uid == null) return Stream.value(null);
    return ref.watch(userRepositoryProvider).watchUser(uid);
  },
);
