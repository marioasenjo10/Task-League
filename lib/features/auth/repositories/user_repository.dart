import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../../league/models/league_model.dart';

class UserRepository {
  final FirebaseFirestore _db;

  UserRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  /// Fetch a single user by ID.
  Future<UserModel?> getUser(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserModel.fromFirestore(doc.data()!, doc.id);
  }

  /// Stream a user in real-time.
  Stream<UserModel?> watchUser(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return UserModel.fromFirestore(doc.data()!, doc.id);
    });
  }

  /// Create or update a user document.
  Future<void> saveUser(UserModel user) async {
    await _users.doc(user.id).set(user.toFirestore(), SetOptions(merge: true));
  }

  /// Permanently delete all Firestore data belonging to [uid]: removes the user
  /// from every league they are a member of, then deletes the user document.
  /// Best-effort — used by the account deletion flow.
  Future<void> deleteUserData(String uid) async {
    // Remove the user from all leagues they belong to.
    final leagues = await _db
        .collection('leagues')
        .where('memberIds', arrayContains: uid)
        .get();
    for (final doc in leagues.docs) {
      await doc.reference.update({
        'memberIds': FieldValue.arrayRemove([uid]),
      });
    }
    // Delete the user document itself.
    await _users.doc(uid).delete();
  }

  /// Award 1 coin to the doer, respecting the daily cap of [kMaxDailyCoins].
  /// Returns the number of coins actually awarded (0 if cap reached).
  Future<int> addCoins(String uid) async {
    int awarded = 0;
    await _db.runTransaction((tx) async {
      final ref = _users.doc(uid);
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final user = UserModel.fromFirestore(snap.data()!, snap.id);
      final todayStr = _todayStr();
      final dayCoins =
          user.lastCoinDate == todayStr ? user.todayCoins : 0;

      if (dayCoins >= kMaxDailyCoins) return;

      awarded = kCoinsPerTask;
      tx.update(ref, {
        'coins': user.coins + awarded,
        'todayCoins': dayCoins + awarded,
        'lastCoinDate': todayStr,
      });
    });
    return awarded;
  }

  /// Award bonus coins for watching a rewarded ad, respecting a separate daily
  /// cap of [kMaxDailyRewardedAds] ads. These coins are independent of the task
  /// coin cap ([kMaxDailyCoins]).
  ///
  /// Returns the coins awarded (0 if the daily rewarded-ad cap was reached).
  Future<int> addRewardCoins(String uid) async {
    int awarded = 0;
    await _db.runTransaction((tx) async {
      final ref = _users.doc(uid);
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final user = UserModel.fromFirestore(snap.data()!, snap.id);
      final todayStr = _todayStr();
      final adsToday =
          user.lastRewardedDate == todayStr ? user.todayRewardedAds : 0;

      if (adsToday >= kMaxDailyRewardedAds) return;

      awarded = kRewardedAdCoins;
      tx.update(ref, {
        'coins': user.coins + awarded,
        'todayRewardedAds': adsToday + 1,
        'lastRewardedDate': todayStr,
      });
    });
    return awarded;
  }

  /// Reward the user with [kAdAttackCoins] coin(s) for watching an ad when the
  /// daily attack cap is reached. This does NOT deal damage (that would be
  /// unfair pay-to-win) — it only grants coins, up to [kMaxAdAttacks] claims
  /// per day. Coins are independent of the task coin cap ([kMaxDailyCoins]).
  ///
  /// Returns the coins awarded (0 if the daily claim limit was reached).
  Future<int> grantAdAttackCoin(String uid) async {
    int awarded = 0;
    await _db.runTransaction((tx) async {
      final ref = _users.doc(uid);
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final user = UserModel.fromFirestore(snap.data()!, snap.id);
      final todayStr = _todayStr();
      final claimed =
          user.lastBonusAttackDate == todayStr ? user.bonusAttacksToday : 0;

      if (claimed >= kMaxAdAttacks) return;

      awarded = kAdAttackCoins;
      tx.update(ref, {
        'coins': user.coins + awarded,
        'bonusAttacksToday': claimed + 1,
        'lastBonusAttackDate': todayStr,
      });
    });
    return awarded;
  }

  /// Deduct exactly [kDamagePerAttack] HP from [targetUid] in [leagueId],
  /// respecting:
  ///   • Period auto-reset (weekly on Monday, monthly on the 1st).
  ///   • Daily attack cap [kMaxDailyAttacks] on the attacker [attackerUid].
  ///
  /// Returns true if damage was applied, false if the daily cap was reached.
  Future<bool> applyDamage({
    required String attackerUid,
    required String targetUid,
    required String leagueId,
    required CompetitionType leagueType,
  }) async {
    bool applied = false;
    final maxHp = maxHpForType(leagueType);
    final periodKey = currentPeriodKey(leagueType);
    final todayStr = _todayStr();

    await _db.runTransaction((tx) async {
      // ── Check attacker daily attack cap ────────────────────────────────
      final attackerRef = _users.doc(attackerUid);
      final attackerSnap = await tx.get(attackerRef);
      if (!attackerSnap.exists) return;
      final attacker =
          UserModel.fromFirestore(attackerSnap.data()!, attackerSnap.id);

      final attacks = attacker.lastAttackDate == todayStr
          ? attacker.todayAttacks
          : 0;
      if (attacks >= kMaxDailyAttacks) return; // cap reached

      // ── Check if target has an active shield ──────────────────────────
      final targetRef = _users.doc(targetUid);
      final targetSnap = await tx.get(targetRef);
      if (!targetSnap.exists) return;
      final target =
          UserModel.fromFirestore(targetSnap.data()!, targetSnap.id);

      final shieldExpiry = target.shieldByLeague[leagueId];
      if (shieldExpiry != null &&
          DateTime.now().toUtc().isBefore(DateTime.parse(shieldExpiry))) {
        // Shield is active — block damage but still count the attack
        tx.update(attackerRef, {
          'todayAttacks': attacks + 1,
          'lastAttackDate': todayStr,
        });
        applied = false; // damage blocked
        return;
      }

      // ── Apply damage to target ─────────────────────────────────────────

      // Check if target needs a period reset
      final targetPeriod = target.lastHpResetByLeague[leagueId];
      final hpBeforeDamage = (targetPeriod == periodKey)
          ? (target.hpByLeague[leagueId] ?? maxHp)
          : maxHp; // new period → full HP

      final newHp = (hpBeforeDamage - kDamagePerAttack).clamp(0, maxHp);

      // Update target HP
      tx.update(targetRef, {
        'hpByLeague.$leagueId': newHp,
        'lastHpResetByLeague.$leagueId': periodKey,
      });

      // Update attacker attack counter
      tx.update(attackerRef, {
        'todayAttacks': attacks + 1,
        'lastAttackDate': todayStr,
      });

      applied = true;
    });
    return applied;
  }

  /// Ensure [uid]'s HP for [leagueId] is reset if the period has changed.
  /// Call this lazily when reading HP (e.g. Arena screen).
  Future<int> getOrResetHp({
    required String uid,
    required String leagueId,
    required CompetitionType leagueType,
  }) async {
    final maxHp = maxHpForType(leagueType);
    final periodKey = currentPeriodKey(leagueType);
    final user = await getUser(uid);
    if (user == null) return maxHp;

    final storedPeriod = user.lastHpResetByLeague[leagueId];
    if (storedPeriod == periodKey) {
      return user.hpByLeague[leagueId] ?? maxHp;
    }
    // New period — reset HP in Firestore
    await _users.doc(uid).update({
      'hpByLeague.$leagueId': maxHp,
      'lastHpResetByLeague.$leagueId': periodKey,
    });
    return maxHp;
  }

  static String _todayStr() =>
      DateTime.now().toIso8601String().substring(0, 10);

  // ── Shop ──────────────────────────────────────────────────────────────────

  /// Unlock [skin] by deducting its coin cost.
  /// Returns true on success, false if not enough coins or already owned.
  Future<bool> unlockSkin(String uid, String skin) async {
    final cost = kSkinCosts[skin] ?? 0;
    bool ok = false;
    await _db.runTransaction((tx) async {
      final ref = _users.doc(uid);
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final user = UserModel.fromFirestore(snap.data()!, snap.id);
      if (user.unlockedSkins.contains(skin)) { ok = true; return; } // already owned
      if (user.coins < cost) return; // not enough
      final newUnlocked = {...user.unlockedSkins, skin};
      tx.update(ref, {
        'coins': user.coins - cost,
        'unlockedSkins': newUnlocked.toList(),
      });
      ok = true;
    });
    return ok;
  }

  /// Purchase a shield for [leagueId] lasting [hours] hours.
  /// Returns true on success, false if not enough coins.
  Future<bool> buyShield({
    required String uid,
    required String leagueId,
    required int hours,
    required int cost,
  }) async {
    bool ok = false;
    await _db.runTransaction((tx) async {
      final ref = _users.doc(uid);
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final user = UserModel.fromFirestore(snap.data()!, snap.id);
      if (user.coins < cost) return;
      final expiry =
          DateTime.now().add(Duration(hours: hours)).toUtc().toIso8601String();
      tx.update(ref, {
        'coins': user.coins - cost,
        'shieldByLeague.$leagueId': expiry,
      });
      ok = true;
    });
    return ok;
  }

  /// Check whether [uid] has an active shield in [leagueId].
  Future<bool> hasActiveShield(String uid, String leagueId) async {
    final user = await getUser(uid);
    if (user == null) return false;
    final expiry = user.shieldByLeague[leagueId];
    if (expiry == null) return false;
    return DateTime.now().toUtc().isBefore(DateTime.parse(expiry));
  }
}
