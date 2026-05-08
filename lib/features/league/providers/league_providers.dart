import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/league_repository.dart';
import '../models/league_model.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/repositories/user_repository.dart';

final leagueRepositoryProvider = Provider<LeagueRepository>(
  (ref) => LeagueRepository(),
);

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
