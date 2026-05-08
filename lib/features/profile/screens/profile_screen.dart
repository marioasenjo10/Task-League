import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/models/user_model.dart';
import '../../league/providers/league_providers.dart';
import '../../../core/widgets/fighter_sprite.dart';
import '../providers/calendar_sync_provider.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/l10n/locale_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('profile'))),
      body: userAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (user) {
          if (user == null) {
            // Firestore doc missing — create it from Firebase Auth data
            return _MissingProfileFallback();
          }
          return _ProfileContent(user: user);
        },
      ),
    );
  }
}

class _ProfileContent extends ConsumerWidget {
  final UserModel user;
  const _ProfileContent({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarState = ref.watch(calendarSyncProvider);
    final calendarLoading = ref.watch(calendarSyncLoadingProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Avatar
          if (user.avatarUrl.isNotEmpty)
            CircleAvatar(
              radius: 48,
              backgroundImage: NetworkImage(user.avatarUrl),
            )
          else
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: const Color(0xFF6C3CE1).withAlpha(30),
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFF6C3CE1).withAlpha(120), width: 2),
              ),
              child: ClipOval(
                child: FighterSprite(skin: user.characterSkin, size: 96),
              ),
            ),
          const SizedBox(height: 12),
          Text(user.name, style: Theme.of(context).textTheme.titleLarge),
          Text(user.email, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 24),

          // Coins + daily cap card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        const Text('🪙', style: TextStyle(fontSize: 22)),
                        const SizedBox(width: 10),
                        Text(
                          '${user.coins}',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFFFB74D)),
                        ),
                        const SizedBox(width: 6),
                        Text(context.tr('profileCoins'),
                            style: Theme.of(context).textTheme.labelSmall),
                      ]),
                      // Daily progress
                      _DailyCoinsChip(user: user),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Daily attacks
                  _DailyAttacksChip(user: user),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Google Calendar sync card
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: SwitchListTile(
                secondary: calendarLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Icons.calendar_month,
                        color: calendarState
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFF6C3CE1),
                      ),
                title: const Text('Google Calendar Sync'),
                subtitle: Text(
                  calendarLoading
                      ? 'Connecting to Google Calendar…'
                      : calendarState
                          ? 'New tasks with a date will be added to your calendar'
                          : 'Enable to auto-sync scheduled tasks',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                value: calendarState,
                // Disabled while OAuth / sync is running
                onChanged: calendarLoading
                    ? null
                    : (enabled) async {
                        await ref
                            .read(calendarSyncProvider.notifier)
                            .toggle(enabled, user);
                      },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Language selector ────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: _LanguageRow(),
            ),
          ),

          const SizedBox(height: 16),

          // Choose / unlock fighter
          Text(context.tr('chooseFighter'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Unlock new fighters with 🪙 coins',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white38,
                  )),
          const SizedBox(height: 12),
          _SkinShop(user: user),
          const SizedBox(height: 32),

          // Sign out
          OutlinedButton.icon(
            icon: const Icon(Icons.logout, color: Colors.red),
            label: Text(context.tr('signOut'),
                style: const TextStyle(color: Colors.red)),
            onPressed: () async {
              await ref.read(authServiceProvider).signOut();
              ref.invalidate(userLeaguesProvider);
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Skin shop — shows all skins with lock/price overlay and equip button
// ---------------------------------------------------------------------------

class _SkinShop extends ConsumerWidget {
  final UserModel user;
  const _SkinShop({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: FighterSprite.skinKeys.map((skin) {
        final def = FighterSprite.skins[skin]!;
        final cost = kSkinCosts[skin] ?? 0;
        final isOwned = cost == 0 || user.unlockedSkins.contains(skin);
        final isEquipped = skin == user.characterSkin;
        final canAfford = user.coins >= cost;

        return GestureDetector(
          onTap: isOwned
              ? () {
                  final updated = user.copyWith(characterSkin: skin);
                  ref.read(userRepositoryProvider).saveUser(updated);
                }
              : canAfford
                  ? () async {
                      final ok = await ref
                          .read(userRepositoryProvider)
                          .unlockSkin(user.id, skin);
                      if (ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${def.label} unlocked! 🎉'),
                            backgroundColor: const Color(0xFF4CAF50),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    }
                  : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 90,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: isEquipped
                  ? Border.all(color: const Color(0xFF6C3CE1), width: 2.5)
                  : isOwned
                      ? Border.all(color: Colors.white24)
                      : Border.all(color: Colors.white12),
              color: isEquipped
                  ? const Color(0xFF6C3CE1).withAlpha(30)
                  : isOwned
                      ? Colors.white.withAlpha(8)
                      : Colors.black.withAlpha(40),
            ),
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Sprite (greyed out if locked)
                    Opacity(
                      opacity: isOwned ? 1.0 : 0.35,
                      child: FighterSprite(skin: skin, size: 56),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      def.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        color: isEquipped
                            ? const Color(0xFFB39DDB)
                            : isOwned
                                ? Colors.white70
                                : Colors.white38,
                        fontWeight: isEquipped
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Status row
                    if (isEquipped)
                      _StatusBadge(
                          label: 'Equipped',
                          color: const Color(0xFF6C3CE1))
                    else if (isOwned)
                      _StatusBadge(
                          label: 'Owned',
                          color: Colors.white24)
                    else
                      _PriceBadge(cost: cost, canAfford: canAfford),
                  ],
                ),
                // Lock icon overlay
                if (!isOwned)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Icon(
                      canAfford ? Icons.lock_open : Icons.lock,
                      size: 14,
                      color: canAfford
                          ? const Color(0xFFFFD600)
                          : Colors.white38,
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(60),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold)),
    );
  }
}

class _PriceBadge extends StatelessWidget {
  final int cost;
  final bool canAfford;
  const _PriceBadge({required this.cost, required this.canAfford});

  @override
  Widget build(BuildContext context) {
    final color = canAfford ? const Color(0xFFFFB74D) : Colors.white38;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: canAfford
            ? const Color(0xFFF57C00).withAlpha(40)
            : Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(120), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🪙', style: const TextStyle(fontSize: 9)),
          const SizedBox(width: 2),
          Text('$cost',
              style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Daily coins chip — shows today's earned / max coins
// ---------------------------------------------------------------------------

class _DailyCoinsChip extends StatelessWidget {
  final UserModel user;
  const _DailyCoinsChip({required this.user});

  @override
  Widget build(BuildContext context) {
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final earned = user.lastCoinDate == todayStr ? user.todayCoins : 0;
    final remaining = (kMaxDailyCoins - earned).clamp(0, kMaxDailyCoins);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: remaining > 0
            ? const Color(0xFFF57C00).withAlpha(25)
            : Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: remaining > 0
              ? const Color(0xFFF57C00).withAlpha(100)
              : Colors.white.withAlpha(20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🪙', style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            '$earned/$kMaxDailyCoins ${context.tr('profileToday')}',
            style: TextStyle(
              fontSize: 11,
              color: remaining > 0
                  ? const Color(0xFFFFB74D)
                  : Colors.white38,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Daily attacks chip
// ---------------------------------------------------------------------------

class _DailyAttacksChip extends StatelessWidget {
  final UserModel user;
  const _DailyAttacksChip({required this.user});

  @override
  Widget build(BuildContext context) {
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final attacks = user.lastAttackDate == todayStr ? user.todayAttacks : 0;
    final remaining = (kMaxDailyAttacks - attacks).clamp(0, kMaxDailyAttacks);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: remaining > 0
            ? const Color(0xFFE53935).withAlpha(25)
            : Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: remaining > 0
              ? const Color(0xFFE53935).withAlpha(100)
              : Colors.white.withAlpha(20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('⚔️', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            '$attacks/$kMaxDailyAttacks attacks today',
            style: TextStyle(
              fontSize: 11,
              color: remaining > 0
                  ? const Color(0xFFEF9A9A)
                  : Colors.white38,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shown when the Firestore document doesn't exist yet (e.g. new Google user).
// Auto-creates the document from Firebase Auth data.
// ---------------------------------------------------------------------------

class _MissingProfileFallback extends ConsumerStatefulWidget {
  @override
  ConsumerState<_MissingProfileFallback> createState() =>
      _MissingProfileFallbackState();
}

class _MissingProfileFallbackState
    extends ConsumerState<_MissingProfileFallback> {
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    // Auto-attempt creation on first render
    WidgetsBinding.instance.addPostFrameCallback((_) => _create());
  }

  Future<void> _create() async {
    if (_creating) return;
    setState(() => _creating = true);
    try {
      final firebaseUser =
          ref.read(authStateProvider).valueOrNull;
      if (firebaseUser == null) return;
      final newUser = UserModel(
        id: firebaseUser.uid,
        name: firebaseUser.displayName ?? 'Fighter',
        email: firebaseUser.email ?? '',
        avatarUrl: firebaseUser.photoURL ?? '',
      );
      await ref.read(userRepositoryProvider).saveUser(newUser);
      // currentUserProvider will automatically update via watchUser stream
    } catch (_) {
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_creating)
            const CircularProgressIndicator()
          else ...[
            const Icon(Icons.person_off_outlined,
                color: Colors.white38, size: 48),
            const SizedBox(height: 12),
            const Text('Setting up your profile...',
                style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _create,
              child: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Language row widget
// ─────────────────────────────────────────────────────────────────────────────

class _LanguageRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final isEs = locale.languageCode == 'es';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [
          const Icon(Icons.language, color: Colors.white54, size: 20),
          const SizedBox(width: 12),
          Text(context.tr('language'),
              style: const TextStyle(fontSize: 14, color: Colors.white70)),
        ]),
        Row(children: [
          _LangBtn(
            label: 'EN',
            selected: !isEs,
            onTap: () => ref
                .read(localeProvider.notifier)
                .setLocale(const Locale('en')),
          ),
          const SizedBox(width: 8),
          _LangBtn(
            label: 'ES',
            selected: isEs,
            onTap: () => ref
                .read(localeProvider.notifier)
                .setLocale(const Locale('es')),
          ),
        ]),
      ],
    );
  }
}

class _LangBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _LangBtn({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF6C3CE1)
              : Colors.white.withAlpha(15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFF6C3CE1)
                : Colors.white.withAlpha(30),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? Colors.white : Colors.white54,
          ),
        ),
      ),
    );
  }
}
