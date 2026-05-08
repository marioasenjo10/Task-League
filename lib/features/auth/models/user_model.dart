import 'package:equatable/equatable.dart';

// ── Game constants ─────────────────────────────────────────────────────────
const kCoinsPerTask  = 1;
const kMaxDailyCoins = 5;
const kMaxDailyAttacks = 5;   // max HP attacks a player can deal per day
const kDamagePerAttack = 1;   // fixed damage per attack
const kWeeklyMaxHp   = 20;    // max HP in a weekly-competition league
const kMonthlyMaxHp  = 100;   // max HP in a monthly-competition league

// ── Shop constants ─────────────────────────────────────────────────────────
/// Cost (coins) to unlock each skin. 0 = free starter skin.
const Map<String, int> kSkinCosts = {
  'warrior':        0,
  'mage':          20,
  'ninja':         20,
  'masked_fighter':30,
  'masked_woman':  30,
  'viking':        40,
  'boxingtiger':   40,
  'doctor':        30,
  'death':         50,
  'thunderman':    50,
};

/// Shield options: display label → {hours, cost}.
const List<Map<String, dynamic>> kShieldOptions = [
  {'label': '4h',  'hours': 4,  'cost': 10},
  {'label': '8h',  'hours': 8,  'cost': 18},
  {'label': '24h', 'hours': 24, 'cost': 40},
];

class UserModel extends Equatable {
  final String id;
  final String name;
  final String email;
  final String avatarUrl;
  final String characterSkin;
  final bool calendarSync;

  // ── Economy ──────────────────────────────────────────────────────────────
  final int coins;           // total accumulated coins
  final int todayCoins;      // coins earned today (resets each day)
  final String lastCoinDate; // ISO-8601 date string "2026-04-14"

  // ── Combat — per-league HP ────────────────────────────────────────────────
  /// { leagueId → currentHp }  — HP is scoped to each league's period
  final Map<String, int> hpByLeague;
  /// { leagueId → "2026-W15" | "2026-04" }  — period key of the last HP reset
  final Map<String, String> lastHpResetByLeague;

  // ── Combat — daily attack cap ─────────────────────────────────────────────
  final int todayAttacks;      // attacks dealt today
  final String lastAttackDate; // ISO-8601 date string "2026-04-14"

  // ── Shop ──────────────────────────────────────────────────────────────────
  /// Set of skin keys that this user has purchased/unlocked.
  /// 'warrior' is always free and implicitly unlocked.
  final Set<String> unlockedSkins;

  /// { leagueId → ISO-8601 datetime string } — active shield expiry per league.
  /// If absent or in the past, no shield is active.
  final Map<String, String> shieldByLeague;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl = '',
    this.characterSkin = 'warrior',
    this.calendarSync = false,
    this.coins = 0,
    this.todayCoins = 0,
    this.lastCoinDate = '',
    this.hpByLeague = const {},
    this.lastHpResetByLeague = const {},
    this.todayAttacks = 0,
    this.lastAttackDate = '',
    this.unlockedSkins = const {'warrior'},
    this.shieldByLeague = const {},
  });

  // ── Convenience helpers ───────────────────────────────────────────────────

  /// Current HP in [leagueId], defaulting to the league's max.
  int currentHp(String leagueId, {required int maxHp}) =>
      hpByLeague[leagueId] ?? maxHp;

  factory UserModel.fromFirestore(Map<String, dynamic> data, String id) {
    return UserModel(
      id: id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      avatarUrl: data['avatarUrl'] ?? '',
      characterSkin: _normalizeSkin(data['characterSkin']),
      calendarSync: data['calendarSync'] ?? false,
      coins: data['coins'] ?? 0,
      todayCoins: data['todayCoins'] ?? 0,
      lastCoinDate: data['lastCoinDate'] ?? '',
      hpByLeague: Map<String, int>.from(data['hpByLeague'] ?? {}),
      lastHpResetByLeague:
          Map<String, String>.from(data['lastHpResetByLeague'] ?? {}),
      todayAttacks: data['todayAttacks'] ?? 0,
      lastAttackDate: data['lastAttackDate'] ?? '',
      unlockedSkins: Set<String>.from(
          (data['unlockedSkins'] as List?)?.cast<String>() ?? ['warrior']),
      shieldByLeague: Map<String, String>.from(data['shieldByLeague'] ?? {}),
    );
  }

  static String _normalizeSkin(dynamic raw) {
    if (raw == null) return 'warrior';
    final normalized =
        raw.toString().toLowerCase().replaceAll(RegExp(r'[\s\-]+'), '_');
    const valid = {
      'warrior', 'mage', 'ninja', 'masked_fighter', 'masked_woman', 'viking',
      'boxingtiger', 'death', 'doctor', 'thunderman',
    };
    return valid.contains(normalized) ? normalized : 'warrior';
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'email': email,
        'avatarUrl': avatarUrl,
        'characterSkin': characterSkin,
        'calendarSync': calendarSync,
        'coins': coins,
        'todayCoins': todayCoins,
        'lastCoinDate': lastCoinDate,
        'hpByLeague': hpByLeague,
        'lastHpResetByLeague': lastHpResetByLeague,
        'todayAttacks': todayAttacks,
        'lastAttackDate': lastAttackDate,
        'unlockedSkins': unlockedSkins.toList(),
        'shieldByLeague': shieldByLeague,
      };

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? avatarUrl,
    String? characterSkin,
    bool? calendarSync,
    int? coins,
    int? todayCoins,
    String? lastCoinDate,
    Map<String, int>? hpByLeague,
    Map<String, String>? lastHpResetByLeague,
    int? todayAttacks,
    String? lastAttackDate,
    Set<String>? unlockedSkins,
    Map<String, String>? shieldByLeague,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      characterSkin: characterSkin ?? this.characterSkin,
      calendarSync: calendarSync ?? this.calendarSync,
      coins: coins ?? this.coins,
      todayCoins: todayCoins ?? this.todayCoins,
      lastCoinDate: lastCoinDate ?? this.lastCoinDate,
      hpByLeague: hpByLeague ?? this.hpByLeague,
      lastHpResetByLeague: lastHpResetByLeague ?? this.lastHpResetByLeague,
      todayAttacks: todayAttacks ?? this.todayAttacks,
      lastAttackDate: lastAttackDate ?? this.lastAttackDate,
      unlockedSkins: unlockedSkins ?? this.unlockedSkins,
      shieldByLeague: shieldByLeague ?? this.shieldByLeague,
    );
  }

  @override
  List<Object?> get props => [
        id, name, email, avatarUrl, characterSkin, calendarSync,
        coins, todayCoins, lastCoinDate,
        hpByLeague, lastHpResetByLeague,
        todayAttacks, lastAttackDate,
        unlockedSkins, shieldByLeague,
      ];
}
