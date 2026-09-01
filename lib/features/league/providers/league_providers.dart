import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/league_repository.dart';
import '../models/league_model.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/repositories/user_repository.dart';
import '../../auth/models/user_model.dart';

final leagueRepositoryProvider = Provider<LeagueRepository>(
  (ref) => LeagueRepository(),
);

// ---------------------------------------------------------------------------
// Provider: fetch all member UserModels for a given leagueId
// ---------------------------------------------------------------------------

final leagueMembersProvider = StreamProvider.family<List<UserModel>, String>(
  (ref, leagueId) async* {
    // Depend on auth state — when the user signs out/in this provider restarts
    final currentUid = ref.watch(authStateProvider).valueOrNull?.uid;
    if (currentUid == null) {
      yield [];
      return;
    }

    final league = await ref.watch(leagueProvider(leagueId).future);
    if (league == null) {
      yield [];
      return;
    }
    final repo = UserRepository();
    // Combine streams of all members into one list stream
    final streams = league.memberIds.map((uid) => repo.watchUser(uid)).toList();
    yield* _mergeUserStreams(streams);
  },
);

/// Merges multiple user streams into a single list stream.
Stream<List<UserModel>> _mergeUserStreams(
    List<Stream<UserModel?>> streams) async* {
  if (streams.isEmpty) {
    yield [];
    return;
  }
  final latest = List<UserModel?>.filled(streams.length, null);
  // Use a broadcast approach: re-emit on any change
  final controller =
      StreamController<List<UserModel>>.broadcast();

  for (int i = 0; i < streams.length; i++) {
    final idx = i;
    streams[idx].listen((user) {
      latest[idx] = user;
      if (!controller.isClosed) {
        controller.add(latest.whereType<UserModel>().toList());
      }
    });
  }

  yield* controller.stream;
}

/// All leagues for the current user.
final userLeaguesProvider = StreamProvider<List<LeagueModel>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value([]);
  return ref.watch(leagueRepositoryProvider).watchUserLeagues(uid);
});

/// A single league by ID.
final leagueProvider =
    StreamProvider.family<LeagueModel?, String>((ref, leagueId) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(null);
  return ref.watch(leagueRepositoryProvider).watchLeague(leagueId);
});

/// Triggers a period HP reset for every member of [leagueId].
/// Returns the number of members whose HP was actually reset.
/// This is a FutureProvider.family — call it with `ref.watch` or `ref.read`
/// from any screen that opens a league.
final periodHpResetProvider =
    FutureProvider.family<int, String>((ref, leagueId) async {
  final league = await ref.watch(leagueProvider(leagueId).future);
  if (league == null) return 0;

  final repo = UserRepository();
  int resetCount = 0;

  await Future.wait(
    league.memberIds.map((uid) async {
      try {
        final user = await repo.getUser(uid);
        if (user == null) return;
        final prevHp =
            user.hpByLeague[leagueId] ?? maxHpForType(league.competitionType);
        final newHp = await repo.getOrResetHp(
          uid: uid,
          leagueId: leagueId,
          leagueType: league.competitionType,
        );
        if (newHp != prevHp || user.lastHpResetByLeague[leagueId] == null) {
          resetCount++;
        }
      } catch (_) {}
    }),
  );

  return resetCount;
});
