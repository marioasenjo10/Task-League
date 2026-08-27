import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/services/quota_guard.dart';
import '../../../core/services/ads_service.dart';
import '../../../core/widgets/fighter_sprite.dart';
import '../../league/screens/members_screen.dart' show leagueMembersProvider;
import '../../league/providers/league_providers.dart';
import '../../league/models/league_model.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/models/user_model.dart';
import '../../auth/repositories/user_repository.dart';
import '../../tasks/models/task_model.dart';
import '../../tasks/providers/task_service_provider.dart';
import '../../tasks/repositories/task_repository.dart';
import '../../stats/providers/stats_providers.dart'
    show
        periodRankingProvider,
        previousPeriodRankingProvider,
        PeriodRankEntry,
        currentPeriodRange,
        isStartOfPeriod;

// ─────────────────────────────────────────────────────────────────────────────
// Main screen
// ─────────────────────────────────────────────────────────────────────────────

class ArenaScreen extends ConsumerStatefulWidget {
  final String leagueId;
  const ArenaScreen({super.key, required this.leagueId});

  @override
  ConsumerState<ArenaScreen> createState() => _ArenaScreenState();
}

class _ArenaScreenState extends ConsumerState<ArenaScreen>
    with SingleTickerProviderStateMixin {
  final Map<String, GlobalKey<_FighterSlotState>> _fighterKeys = {};
  final Map<String, int> _lastHp = {};
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _checkForHits(List<UserModel> members, String leagueId, int maxHp) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final m in members) {
        final hp = m.currentHp(leagueId, maxHp: maxHp);
        final prev = _lastHp[m.id];
        if (prev != null && hp < prev) {
          _fighterKeys[m.id]?.currentState?.playHit();
        }
        _lastHp[m.id] = hp;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final leagueAsync = ref.watch(leagueProvider(widget.leagueId));

    // Ensure every member's HP is reset when a new period starts, even if the
    // Arena is opened directly without going through the league hub first.
    ref.watch(periodHpResetProvider(widget.leagueId));

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        title: Text(
          context.tr('arena'),
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF6C3CE1),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          tabs: [
            Tab(
              icon: const Icon(Icons.sports_kabaddi, size: 18),
              text: context.tr('arenaTabRing'),
            ),
            Tab(
              icon: const Icon(Icons.people, size: 18),
              text: context.tr('arenaTabPlayers'),
            ),
            Tab(
              icon: const Icon(Icons.emoji_events, size: 18),
              text: context.tr('arenaTabRanking'),
            ),
          ],
        ),
      ),
      body: leagueAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              e.toString(),
              style: const TextStyle(color: Colors.white54),
            ),
          ),
        ),
        data: (league) {
          if (league == null) {
            return Center(
              child: Text(
                context.tr('leagueNotFound'),
                style: const TextStyle(color: Colors.white54),
              ),
            );
          }
          final maxHp = maxHpForType(league.competitionType);
          return TabBarView(
            controller: _tabController,
            children: [
              // ── Tab 1: Ring ───────────────────────────────────────────
              _RingTab(
                leagueId: widget.leagueId,
                maxHp: maxHp,
                fighterKeys: _fighterKeys,
                onCheckHits: (members) =>
                    _checkForHits(members, widget.leagueId, maxHp),
              ),
              // ── Tab 2: Players ────────────────────────────────────────
              _PlayersTab(leagueId: widget.leagueId, maxHp: maxHp),
              // ── Tab 3: Ranking ────────────────────────────────────────
              _RankingTab(
                leagueId: widget.leagueId,
                leagueType: league.competitionType,
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// Tab 1 — Ring view
// ─────────────────────────────────────────────────────────────────────────────

class _RingTab extends ConsumerWidget {
  final String leagueId;
  final int maxHp;
  final Map<String, GlobalKey<_FighterSlotState>> fighterKeys;
  final void Function(List<UserModel> members) onCheckHits;

  const _RingTab({
    required this.leagueId,
    required this.maxHp,
    required this.fighterKeys,
    required this.onCheckHits,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(leagueMembersProvider(leagueId));
    final currentUid = ref.watch(authStateProvider).valueOrNull?.uid;

    return membersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            e.toString(),
            style: const TextStyle(color: Colors.white54),
          ),
        ),
      ),
      data: (members) {
        if (members.isEmpty) {
          return Center(
            child: Text(
              context.tr('noFightersYet'),
              style: const TextStyle(color: Colors.white54),
            ),
          );
        }
        for (final m in members) {
          fighterKeys.putIfAbsent(m.id, () => GlobalKey<_FighterSlotState>());
        }
        onCheckHits(members);

        final sorted = [...members]
          ..sort((a, b) {
            if (a.id == currentUid) return -1;
            if (b.id == currentUid) return 1;
            return b
                .currentHp(leagueId, maxHp: maxHp)
                .compareTo(a.currentHp(leagueId, maxHp: maxHp));
          });

        return _ArenaLayout(
          members: sorted,
          currentUid: currentUid,
          fighterKeys: fighterKeys,
          leagueId: leagueId,
          maxHp: maxHp,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2 — Ranking view
// ─────────────────────────────────────────────────────────────────────────────

class _RankingTab extends ConsumerStatefulWidget {
  final String leagueId;
  final CompetitionType leagueType;

  const _RankingTab({required this.leagueId, required this.leagueType});

  @override
  ConsumerState<_RankingTab> createState() => _RankingTabState();
}

class _RankingTabState extends ConsumerState<_RankingTab> {
  bool _bannerDismissed = false;

  @override
  Widget build(BuildContext context) {
    final rankAsync = ref.watch(
      periodRankingProvider((
        leagueId: widget.leagueId,
        type: widget.leagueType,
      )),
    );
    final prevRankAsync = ref.watch(
      previousPeriodRankingProvider((
        leagueId: widget.leagueId,
        type: widget.leagueType,
      )),
    );
    final currentUid = ref.watch(authStateProvider).valueOrNull?.uid;
    final range = currentPeriodRange(widget.leagueType);
    final periodLabel = widget.leagueType == CompetitionType.weekly
        ? context.tr('periodThisWeek')
        : context.tr('periodThisMonth');
    final startLabel =
        '${range.start.day.toString().padLeft(2, '0')}/${range.start.month.toString().padLeft(2, '0')}';

    final showBanner = !_bannerDismissed && isStartOfPeriod(widget.leagueType);

    return rankAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          e.toString(),
          style: const TextStyle(color: Colors.white54),
        ),
      ),
      data: (ranking) {
        if (ranking.isEmpty) {
          return Center(
            child: Text(
              context.tr('noFightersYet'),
              style: const TextStyle(color: Colors.white54),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            // ── Previous period results banner ────────────────────
            if (showBanner)
              _PreviousPeriodBanner(
                leagueType: widget.leagueType,
                prevRankAsync: prevRankAsync,
                currentUid: currentUid,
                onDismiss: () => setState(() => _bannerDismissed = true),
              ),

            // ── Period header ─────────────────────────────────────
            Row(
              children: [
                const Icon(
                  Icons.emoji_events,
                  color: Color(0xFFFFD700),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  context.trArgs('periodSince', {
                    'label': periodLabel,
                    'date': startLabel,
                  }),
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Podium ────────────────────────────────────────────
            if (ranking.length >= 2)
              _Podium(ranking: ranking, currentUid: currentUid),

            const SizedBox(height: 24),

            // ── Full list (all members, ranked) ───────────────────
            ...ranking.asMap().entries.map(
              (e) => _RankRow(
                entry: e.value,
                rank: e.key + 1,
                isCurrentUser: e.value.member.id == currentUid,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Previous period results banner
// ─────────────────────────────────────────────────────────────────────────────

class _PreviousPeriodBanner extends StatelessWidget {
  final CompetitionType leagueType;
  final AsyncValue<List<PeriodRankEntry>> prevRankAsync;
  final String? currentUid;
  final VoidCallback onDismiss;

  const _PreviousPeriodBanner({
    required this.leagueType,
    required this.prevRankAsync,
    required this.currentUid,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final label = leagueType == CompetitionType.weekly
        ? context.tr('periodResultsLastWeek')
        : context.tr('periodResultsLastMonth');

    return prevRankAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (prev) {
        // Don't show banner if nobody completed any tasks last period
        final anyActivity = prev.any((e) => e.tasks > 0);
        if (!anyActivity) return const SizedBox.shrink();

        final winner = prev[0];
        final second = prev.length > 1 ? prev[1] : null;
        final third = prev.length > 2 ? prev[2] : null;
        final youEntry = prev.firstWhere(
          (e) => e.member.id == currentUid,
          orElse: () => prev.last,
        );
        final yourRank = prev.indexOf(youEntry) + 1;
        final isWinner = youEntry.member.id == currentUid && yourRank == 1;

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isWinner
                    ? [
                        const Color(0xFFFFD700).withAlpha(30),
                        const Color(0xFF6C3CE1).withAlpha(20),
                      ]
                    : [
                        const Color(0xFF6C3CE1).withAlpha(25),
                        Colors.white.withAlpha(8),
                      ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isWinner
                    ? const Color(0xFFFFD700).withAlpha(100)
                    : const Color(0xFF6C3CE1).withAlpha(80),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header bar ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 0),
                  child: Row(
                    children: [
                      const Text('🏆', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white38,
                          size: 16,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: onDismiss,
                      ),
                    ],
                  ),
                ),

                // ── Top 3 mini podium ───────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: Row(
                    children: [
                      _BannerPodiumSlot(
                        entry: winner,
                        rank: 1,
                        medal: '🥇',
                        color: const Color(0xFFFFD700),
                        isCurrentUser: winner.member.id == currentUid,
                      ),
                      if (second != null) ...[
                        const SizedBox(width: 8),
                        _BannerPodiumSlot(
                          entry: second,
                          rank: 2,
                          medal: '🥈',
                          color: const Color(0xFFB0BEC5),
                          isCurrentUser: second.member.id == currentUid,
                        ),
                      ],
                      if (third != null) ...[
                        const SizedBox(width: 8),
                        _BannerPodiumSlot(
                          entry: third,
                          rank: 3,
                          medal: '🥉',
                          color: const Color(0xFFCD7F32),
                          isCurrentUser: third.member.id == currentUid,
                        ),
                      ],
                    ],
                  ),
                ),

                // ── Your result (if not in top 3) ───────────────────
                if (currentUid != null && yourRank > 3) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Divider(color: Colors.white12, height: 20),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C3CE1).withAlpha(80),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'YOU',
                            style: TextStyle(
                              color: Color(0xFFB39DDB),
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '#$yourRank · ${youEntry.tasks} tasks · ${youEntry.damage} dmg',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else
                  const SizedBox(height: 14),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BannerPodiumSlot extends StatelessWidget {
  final PeriodRankEntry entry;
  final int rank;
  final String medal;
  final Color color;
  final bool isCurrentUser;

  const _BannerPodiumSlot({
    required this.entry,
    required this.rank,
    required this.medal,
    required this.color,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    final name = entry.member.name.isNotEmpty
        ? entry.member.name
        : entry.member.email;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(medal, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 6),
        FighterSprite(skin: entry.member.characterSkin, size: 32),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isCurrentUser ? color : Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${entry.tasks} tasks',
              style: const TextStyle(fontSize: 9, color: Colors.white38),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Podium — 2nd | 1st | 3rd layout
// ─────────────────────────────────────────────────────────────────────────────

class _Podium extends StatelessWidget {
  final List<PeriodRankEntry> ranking;
  final String? currentUid;
  const _Podium({required this.ranking, required this.currentUid});

  @override
  Widget build(BuildContext context) {
    final first = ranking[0];
    final second = ranking.length > 1 ? ranking[1] : null;
    final third = ranking.length > 2 ? ranking[2] : null;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (second != null)
            Expanded(
              child: _PodiumSlot(
                entry: second,
                rank: 2,
                blockHeight: 80,
                medal: '🥈',
                color: const Color(0xFFB0BEC5),
                isCurrentUser: second.member.id == currentUid,
              ),
            )
          else
            const Expanded(child: SizedBox()),
          Expanded(
            child: _PodiumSlot(
              entry: first,
              rank: 1,
              blockHeight: 110,
              medal: '🥇',
              color: const Color(0xFFFFD700),
              isCurrentUser: first.member.id == currentUid,
            ),
          ),
          if (third != null)
            Expanded(
              child: _PodiumSlot(
                entry: third,
                rank: 3,
                blockHeight: 60,
                medal: '🥉',
                color: const Color(0xFFCD7F32),
                isCurrentUser: third.member.id == currentUid,
              ),
            )
          else
            const Expanded(child: SizedBox()),
        ],
      ),
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  final PeriodRankEntry entry;
  final int rank;
  final double blockHeight;
  final String medal;
  final Color color;
  final bool isCurrentUser;

  const _PodiumSlot({
    required this.entry,
    required this.rank,
    required this.blockHeight,
    required this.medal,
    required this.color,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    final name = entry.member.name.isNotEmpty
        ? entry.member.name
        : entry.member.email;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(medal, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            FighterSprite(skin: entry.member.characterSkin, size: 52),
            if (isCurrentUser)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C3CE1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'YOU',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 7,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          name,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isCurrentUser ? color : Colors.white70,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          textAlign: TextAlign.center,
        ),
        Text(
          '${entry.tasks} tasks',
          style: const TextStyle(fontSize: 10, color: Colors.white38),
        ),
        const SizedBox(height: 4),
        Container(
          height: blockHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color.withAlpha(80), color.withAlpha(25)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: color.withAlpha(120)),
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color.withAlpha(200),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rank row — full list entry
// ─────────────────────────────────────────────────────────────────────────────

class _RankRow extends StatelessWidget {
  final PeriodRankEntry entry;
  final int rank;
  final bool isCurrentUser;

  const _RankRow({
    required this.entry,
    required this.rank,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    final name = entry.member.name.isNotEmpty
        ? entry.member.name
        : entry.member.email;
    final medalEmoji = rank == 1
        ? '🥇'
        : rank == 2
        ? '🥈'
        : rank == 3
        ? '🥉'
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isCurrentUser
              ? const Color(0xFF6C3CE1).withAlpha(20)
              : Colors.white.withAlpha(8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrentUser
                ? const Color(0xFF6C3CE1).withAlpha(100)
                : Colors.white.withAlpha(12),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: medalEmoji != null
                  ? Text(
                      medalEmoji,
                      style: const TextStyle(fontSize: 20),
                      textAlign: TextAlign.center,
                    )
                  : Text(
                      '#$rank',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white38,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 40,
              height: 40,
              child: FighterSprite(skin: entry.member.characterSkin, size: 40),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isCurrentUser) ...[
                        Container(
                          margin: const EdgeInsets.only(right: 5),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C3CE1).withAlpha(120),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'YOU',
                            style: TextStyle(
                              color: Color(0xFFB39DDB),
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                      Flexible(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${entry.tasks} tasks · ${entry.damage} dmg · 🪙${entry.coins}',
                    style: const TextStyle(fontSize: 10, color: Colors.white38),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF6C3CE1).withAlpha(30),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${entry.tasks}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFB39DDB),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Arena layout
// ─────────────────────────────────────────────────────────────────────────────

class _ArenaLayout extends ConsumerStatefulWidget {
  final List<UserModel> members;
  final String? currentUid;
  final Map<String, GlobalKey<_FighterSlotState>> fighterKeys;
  final String leagueId;
  final int maxHp;

  const _ArenaLayout({
    required this.members,
    required this.currentUid,
    required this.fighterKeys,
    required this.leagueId,
    required this.maxHp,
  });

  @override
  ConsumerState<_ArenaLayout> createState() => _ArenaLayoutState();
}

class _ArenaLayoutState extends ConsumerState<_ArenaLayout> {
  int _opponentIndex = 0;

  void _onFighterTap(UserModel target) {
    if (target.id == widget.currentUid) return;
    if (target.currentHp(widget.leagueId, maxHp: widget.maxHp) <= 0) return;

    // Warn if target has an active shield (damage will be blocked)
    final shieldExpiry = target.shieldByLeague[widget.leagueId];
    if (shieldExpiry != null &&
        DateTime.now().toUtc().isBefore(DateTime.parse(shieldExpiry))) {
      final remaining = DateTime.parse(
        shieldExpiry,
      ).difference(DateTime.now().toUtc());
      final h = remaining.inHours;
      final m = remaining.inMinutes % 60;
      final timeStr = h > 0 ? '${h}h ${m}m' : '${m}m';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.trArgs('shieldBlockedMsg', {
              'name': target.name,
              'time': timeStr,
            }),
          ),
          backgroundColor: const Color(0xFF1565C0),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: context.tr('attackAnyway'),
            textColor: Colors.white,
            onPressed: () => showArenaAttackDialog(
              context,
              ref,
              target,
              widget.leagueId,
              widget.maxHp,
            ),
          ),
        ),
      );
      return;
    }

    showArenaAttackDialog(context, ref, target, widget.leagueId, widget.maxHp);
  }

  /// Called when all opponents are KO — complete a task for XP only, no damage.
  void _onCompleteNoTarget() {
    showArenaAttackDialog(context, ref, null, widget.leagueId, widget.maxHp);
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.members.isNotEmpty ? widget.members[0] : null;
    // All members except current user are potential opponents
    final opponents = widget.members
        .where((m) => m.id != widget.currentUid)
        .toList();

    // Clamp index in case members changed
    if (opponents.isNotEmpty) {
      _opponentIndex = _opponentIndex.clamp(0, opponents.length - 1);
    }

    final opponent = opponents.isNotEmpty ? opponents[_opponentIndex] : null;
    final hasMultipleOpponents = opponents.length > 1;

    // Compute current user's attacks remaining
    int myAttacksLeft = kMaxDailyAttacks;
    if (me != null) {
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final attacksUsed = (me.lastAttackDate == todayStr) ? me.todayAttacks : 0;
      myAttacksLeft = (kMaxDailyAttacks - attacksUsed).clamp(
        0,
        kMaxDailyAttacks,
      );
    }
    final opponentIsAlive =
        opponent != null &&
        opponent.currentHp(widget.leagueId, maxHp: widget.maxHp) > 0;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── My Status Banner ─────────────────────────────────────────────
          if (me != null)
            _MyStatusBanner(
              user: me,
              leagueId: widget.leagueId,
              maxHp: widget.maxHp,
            ),

          // ── Ring image with fighters standing on it ──────────────────────
          Stack(
            children: [
              _RingWithFighters(
                left: me,
                right: opponent,
                currentUid: widget.currentUid,
                fighterKeys: widget.fighterKeys,
                leagueId: widget.leagueId,
                maxHp: widget.maxHp,
                onFighterTap: _onFighterTap,
              ),

              // ── Opponent switcher arrows ─────────────────────────────────
              if (hasMultipleOpponents)
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Align(
                        alignment: Alignment(0, 0.05),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // ← prev opponent
                              _SwitchArrow(
                                icon: Icons.chevron_left,
                                onTap: () => setState(() {
                                  _opponentIndex =
                                      (_opponentIndex - 1 + opponents.length) %
                                      opponents.length;
                                }),
                              ),
                              // opponent counter pill
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(160),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withAlpha(30),
                                  ),
                                ),
                                child: Text(
                                  '${_opponentIndex + 1} / ${opponents.length}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              // → next opponent
                              _SwitchArrow(
                                icon: Icons.chevron_right,
                                onTap: () => setState(() {
                                  _opponentIndex =
                                      (_opponentIndex + 1) % opponents.length;
                                }),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),

          // ── Bench — remaining opponents (excluding current ring opponent) ─
          if (opponents.length > 1) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 14,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C3CE1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.tr('otherFighters'),
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  for (int i = 0; i < opponents.length; i++)
                    if (i != _opponentIndex)
                      _BenchRow(
                        user: opponents[i],
                        rank: i + 2,
                        isCurrentUser: false,
                        leagueId: widget.leagueId,
                        maxHp: widget.maxHp,
                        onTap: () => setState(() => _opponentIndex = i),
                      ),
                ],
              ),
            ),
          ],

          // ── Attack CTA / hint bar ────────────────────────────────────────
          _AttackHintBar(
            attacksLeft: myAttacksLeft,
            opponentIsAlive: opponentIsAlive,
            onAttackTap: myAttacksLeft > 0
                ? () {
                    if (opponentIsAlive) {
                      _onFighterTap(opponent);
                    } else {
                      _onCompleteNoTarget();
                    }
                  }
                : null,
          ),

          // ── Legend ───────────────────────────────────────────────────────
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(
                color: const Color(0xFF4CAF50),
                label: context.tr('hpFull'),
              ),
              const SizedBox(width: 16),
              _LegendDot(
                color: const Color(0xFFFFC107),
                label: context.tr('hpInjured'),
              ),
              const SizedBox(width: 16),
              _LegendDot(
                color: const Color(0xFFE53935),
                label: context.tr('hpCritical'),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Arrow button to switch opponent
// ─────────────────────────────────────────────────────────────────────────────

class _SwitchArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _SwitchArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(160),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF6C3CE1).withAlpha(180)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C3CE1).withAlpha(80),
              blurRadius: 8,
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ring image with fighters overlaid at the bottom (floor level)
// ─────────────────────────────────────────────────────────────────────────────

class _RingWithFighters extends StatelessWidget {
  final UserModel? left;
  final UserModel? right;
  final String? currentUid;
  final Map<String, GlobalKey<_FighterSlotState>> fighterKeys;
  final String leagueId;
  final int maxHp;
  final void Function(UserModel)? onFighterTap;

  const _RingWithFighters({
    required this.left,
    required this.right,
    required this.currentUid,
    required this.fighterKeys,
    required this.leagueId,
    required this.maxHp,
    this.onFighterTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        // h is fixed to the image aspect ratio so the ring floor is always
        // at the same relative position regardless of window width.
        final h = (w * 1.35).clamp(
          0.0,
          MediaQuery.of(context).size.height * 0.80,
        );
        // ringAlign pushes the image down so the canvas floor is visible.
        // Y=0.10 means slightly below centre — tune if needed.
        const ringAlign = Alignment(0.0, 0.10);
        final spriteSize = (h * 0.26).clamp(85.0, 140.0);
        // Fighters stand at ~36% up from the bottom of the container.
        final floorPad = h * 0.36;

        return SizedBox(
          width: w,
          height: h,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // ── Ring background ────────────────────────────────────────
              Positioned.fill(
                child: Image.asset(
                  'assets/images/old_ring.png',
                  fit: BoxFit.cover,
                  alignment: ringAlign,
                ),
              ),
              // Dark vignette: heavier at top (sky) and bottom edge so
              // fighters blend naturally onto the canvas.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.35, 0.70, 1.0],
                      colors: [
                        Colors.black.withAlpha(140),
                        Colors.black.withAlpha(10),
                        Colors.black.withAlpha(30),
                        Colors.black.withAlpha(180),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Left fighter ───────────────────────────────────────────
              if (left != null)
                Positioned(
                  left: w * 0.20,
                  // Subtract the transparent footer so the visible feet land on the floor
                  bottom:
                      floorPad -
                      FighterSprite(
                        skin: left!.characterSkin,
                        size: spriteSize,
                      ).feetPaddingPixels(spriteSize),
                  child: GestureDetector(
                    onTap:
                        (left!.id == currentUid ||
                            left!.currentHp(leagueId, maxHp: maxHp) <= 0)
                        ? null
                        : () => onFighterTap?.call(left!),
                    child: _FighterSlot(
                      key: fighterKeys[left!.id],
                      user: left!,
                      isCurrentUser: left!.id == currentUid,
                      facingRight: true,
                      size: spriteSize,
                      leagueId: leagueId,
                      maxHp: maxHp,
                      isAttackable:
                          left!.id != currentUid &&
                          left!.currentHp(leagueId, maxHp: maxHp) > 0,
                    ),
                  ),
                ),

              // ── Right fighter ──────────────────────────────────────────
              if (right != null)
                Positioned(
                  right: w * 0.20,
                  bottom:
                      floorPad -
                      FighterSprite(
                        skin: right!.characterSkin,
                        size: spriteSize,
                      ).feetPaddingPixels(spriteSize),
                  child: GestureDetector(
                    onTap:
                        (right!.id == currentUid ||
                            right!.currentHp(leagueId, maxHp: maxHp) <= 0)
                        ? null
                        : () => onFighterTap?.call(right!),
                    child: _PulsingGlow(
                      active:
                          right!.id != currentUid &&
                          right!.currentHp(leagueId, maxHp: maxHp) > 0,
                      child: _FighterSlot(
                        key: fighterKeys[right!.id],
                        user: right!,
                        isCurrentUser: right!.id == currentUid,
                        facingRight: false,
                        size: spriteSize,
                        leagueId: leagueId,
                        maxHp: maxHp,
                        isAttackable:
                            right!.id != currentUid &&
                            right!.currentHp(leagueId, maxHp: maxHp) > 0,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Explosion burst — drawn with CustomPaint, no emoji dependency
// ─────────────────────────────────────────────────────────────────────────────

class _ExplosionBurst extends StatelessWidget {
  final double size;
  const _ExplosionBurst({this.size = 36});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(size, size), painter: _ExplosionPainter());
  }
}

class _ExplosionPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    // Core circle — bright yellow-orange
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFFFCC),
          const Color(0xFFFF9800),
          const Color(0xFFE53935),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.55));
    canvas.drawCircle(Offset(cx, cy), r * 0.55, corePaint);

    // Spikes — 8 alternating long/short rays
    final spikePaint = Paint()
      ..color = const Color(0xFFFFCC00)
      ..strokeWidth = size.width * 0.09
      ..strokeCap = StrokeCap.round;

    const spikes = 8;
    for (int i = 0; i < spikes; i++) {
      final angle = (i * 2 * math.pi / spikes) - math.pi / 2;
      final inner = r * 0.45;
      final outer = r * (i % 2 == 0 ? 1.0 : 0.75);
      canvas.drawLine(
        Offset(cx + inner * math.cos(angle), cy + inner * math.sin(angle)),
        Offset(cx + outer * math.cos(angle), cy + outer * math.sin(angle)),
        spikePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ExplosionPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Pulsing glow — wraps an attackable fighter to draw the eye
// ─────────────────────────────────────────────────────────────────────────────

class _PulsingGlow extends StatefulWidget {
  final bool active;
  final Widget child;
  const _PulsingGlow({required this.active, required this.child});

  @override
  State<_PulsingGlow> createState() => _PulsingGlowState();
}

class _PulsingGlowState extends State<_PulsingGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFFE53935,
                ).withAlpha((50 + 90 * _anim.value).round()),
                blurRadius: 18 + 14 * _anim.value,
                spreadRadius: 2 + 4 * _anim.value,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fighter slot — sprite + KO badge + shake/flash animation
// ─────────────────────────────────────────────────────────────────────────────

class _FighterSlot extends StatefulWidget {
  final UserModel user;
  final bool isCurrentUser;
  final bool facingRight;
  final double size;
  final String leagueId;
  final int maxHp;
  final bool isAttackable;

  const _FighterSlot({
    super.key,
    required this.user,
    required this.isCurrentUser,
    required this.facingRight,
    this.size = 100,
    required this.leagueId,
    required this.maxHp,
    this.isAttackable = false,
  });

  @override
  State<_FighterSlot> createState() => _FighterSlotState();
}

class _FighterSlotState extends State<_FighterSlot>
    with TickerProviderStateMixin {
  late AnimationController _hitCtrl;
  late AnimationController _idleCtrl;
  bool _showHitEffect = false;
  bool _isHitPose = false;

  @override
  void initState() {
    super.initState();
    _hitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    // Idle pendulum: one full cycle = 1.4 s, loops forever
    _idleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _hitCtrl.dispose();
    _idleCtrl.dispose();
    super.dispose();
  }

  bool _hasActiveShield(UserModel user) {
    final expiry = user.shieldByLeague[widget.leagueId];
    if (expiry == null) return false;
    return DateTime.now().toUtc().isBefore(DateTime.parse(expiry));
  }

  /// Triggered externally via GlobalKey when HP drops
  void playHit() {
    if (!mounted) return;
    _hitCtrl.stop();
    _idleCtrl.stop(); // pause idle during hit
    setState(() {
      _showHitEffect = true;
      _isHitPose = true;
    });
    _hitCtrl.forward(from: 0).whenComplete(() {
      if (mounted) {
        setState(() {
          _showHitEffect = false;
          _isHitPose = false;
        });
        _idleCtrl.repeat(); // resume idle
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final isKO = user.currentHp(widget.leagueId, maxHp: widget.maxHp) <= 0;
    final s = widget.size;

    return AnimatedBuilder(
      animation: Listenable.merge([_hitCtrl, _idleCtrl]),
      builder: (context, child) {
        final t = _hitCtrl.value;
        final shake = t < 0.7
            ? math.sin(t * math.pi * 10) * 8.0 * (1 - t)
            : 0.0;
        final tintAlpha = (math.sin(t * math.pi) * 160).clamp(0, 160).toInt();

        // ── Idle pendulum (only when not being hit and not KO) ──────────────
        // Two sine waves: vertical bob (full cycle) + lateral lean (half cycle)
        // giving that classic boxing weight-shift footwork feel.
        final idle = _idleCtrl.value * 2 * math.pi; // 0 → 2π per cycle
        final idleBobY = isKO ? 0.0 : math.sin(idle) * 2.8; // ±2.8 px up/down
        final idleLeanX = isKO
            ? 0.0
            : math.sin(idle * 0.5) * 1.6; // ±1.6 px side
        final idleRotZ = isKO
            ? 0.0
            : math.sin(idle * 0.5) * 0.018; // slight tilt

        final totalOffsetX = shake + idleLeanX;
        final totalOffsetY = idleBobY;

        return Transform.translate(
          offset: Offset(totalOffsetX, totalOffsetY),
          child: Transform.rotate(
            angle: idleRotZ,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: s,
                  height: s,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      // ── Ground shadow ellipse — pulses with the bob ──────────
                      Positioned(
                        // Offset the shadow up by the PNG's transparent footer
                        // so it always sits under the visible feet, not the SizedBox edge.
                        bottom:
                            2 +
                            FighterSprite(
                              skin: user.characterSkin,
                              size: s,
                            ).feetPaddingPixels(s),
                        child: Container(
                          // shadow shrinks slightly when fighter bobs up
                          width:
                              s *
                              0.6 *
                              (1.0 - idleBobY * 0.015).clamp(0.85, 1.0),
                          height: 10,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(50),
                            color: Colors.black.withAlpha(80),
                          ),
                        ),
                      ),
                      // ── Sprite ──────────────────────────────────────────────
                      Opacity(
                        opacity: isKO ? 0.35 : 1.0,
                        child: Transform.scale(
                          scaleX: widget.facingRight ? 1.0 : -1.0,
                          child: FighterSprite(
                            skin: user.characterSkin,
                            size: s,
                            isKO: isKO,
                            pose: _isHitPose
                                ? FighterPose.hit
                                : FighterPose.idle,
                          ),
                        ),
                      ),

                      // ── Red flash overlay ────────────────────────────────────
                      if (_showHitEffect)
                        IgnorePointer(
                          child: Container(
                            width: s,
                            height: s,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color.fromARGB(tintAlpha, 255, 50, 50),
                            ),
                          ),
                        ),

                      // ── Floating explosion — shown on hit ───────────────────
                      if (_showHitEffect)
                        Positioned(
                          top: 0,
                          child: Animate(
                            effects: const [
                              MoveEffect(
                                begin: Offset(0, 0),
                                end: Offset(0, -36),
                                duration: Duration(milliseconds: 600),
                                curve: Curves.easeOut,
                              ),
                              FadeEffect(
                                begin: 1,
                                end: 0,
                                delay: Duration(milliseconds: 300),
                                duration: Duration(milliseconds: 300),
                              ),
                            ],
                            child: const _ExplosionBurst(size: 28),
                          ),
                        ),

                      // ── K.O. badge ───────────────────────────────────────────
                      if (isKO)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'K.O.',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 2,
                            ),
                          ),
                        ),

                      // ── Attack indicator (tap to attack) ─────────────────────
                      if (widget.isAttackable && !isKO && !_showHitEffect)
                        Positioned(
                          top: 4,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE53935).withAlpha(200),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFE53935).withAlpha(120),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.bolt,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),

                      // ── Active shield badge ──────────────────────────────────
                      if (!isKO && _hasActiveShield(user))
                        Positioned(
                          top: 4,
                          left: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1565C0).withAlpha(220),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF42A5F5).withAlpha(160),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Text(
                              '🛡️',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // ── HP bar below sprite ──────────────────────────────────
                _InlineHpBar(
                  user: user,
                  leagueId: widget.leagueId,
                  maxHp: widget.maxHp,
                  width: s,
                  isCurrentUser: widget.isCurrentUser,
                ),
              ],
            ), // Column
          ), // Transform.rotate
        ); // Transform.translate
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bench row — compact fighter card for members not in the ring
// ─────────────────────────────────────────────────────────────────────────────

class _BenchRow extends StatelessWidget {
  final UserModel user;
  final int rank;
  final bool isCurrentUser;
  final String leagueId;
  final int maxHp;
  final VoidCallback? onTap;

  const _BenchRow({
    required this.user,
    required this.rank,
    required this.isCurrentUser,
    required this.leagueId,
    required this.maxHp,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hp = user.currentHp(leagueId, maxHp: maxHp);
    final hpRatio = maxHp > 0 ? (hp / maxHp).clamp(0.0, 1.0) : 0.0;
    final hpColor = hpRatio > 0.6
        ? const Color(0xFF4CAF50)
        : hpRatio > 0.3
        ? const Color(0xFFFFC107)
        : const Color(0xFFE53935);
    final isKO = hp <= 0;
    final canAttack = onTap != null && !isCurrentUser && !isKO;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: canAttack ? onTap : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(isCurrentUser ? 18 : 10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isCurrentUser
                    ? const Color(0xFF6C3CE1).withAlpha(120)
                    : Colors.white.withAlpha(15),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Rank number
                SizedBox(
                  width: 22,
                  child: Text(
                    '#$rank',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Fighter sprite thumbnail
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Opacity(
                    opacity: isKO ? 0.35 : 1.0,
                    child: FighterSprite(
                      skin: user.characterSkin,
                      size: 40,
                      isKO: isKO,
                      pose: FighterPose.idle,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Name + YOU badge + HP bar
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isCurrentUser)
                            Container(
                              margin: const EdgeInsets.only(right: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6C3CE1).withAlpha(120),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text(
                                'YOU',
                                style: TextStyle(
                                  color: Color(0xFFB39DDB),
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          Flexible(
                            child: Text(
                              user.name.isNotEmpty ? user.name : user.email,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // HP bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: hpRatio,
                          minHeight: 5,
                          backgroundColor: Colors.white10,
                          valueColor: AlwaysStoppedAnimation<Color>(hpColor),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // HP + coins + attack button
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$hp/$maxHp',
                      style: TextStyle(
                        fontSize: 10,
                        color: hpColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '🪙${user.coins}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white38,
                      ),
                    ),
                    if (canAttack) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53935).withAlpha(180),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.bolt,
                              size: 11,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              context.tr('attackBadge'),
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Inline HP bar — shown below each fighter sprite on the ring
// ─────────────────────────────────────────────────────────────────────────────

class _InlineHpBar extends StatelessWidget {
  final UserModel user;
  final String leagueId;
  final int maxHp;
  final double width;
  final bool isCurrentUser;

  const _InlineHpBar({
    required this.user,
    required this.leagueId,
    required this.maxHp,
    required this.width,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    final hp = user.currentHp(leagueId, maxHp: maxHp);
    final hpRatio = maxHp > 0 ? (hp / maxHp).clamp(0.0, 1.0) : 0.0;
    final hpColor = hpRatio > 0.6
        ? const Color(0xFF4CAF50)
        : hpRatio > 0.3
        ? const Color(0xFFFFC107)
        : const Color(0xFFE53935);
    final name = user.name.isNotEmpty ? user.name : user.email;

    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(140),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isCurrentUser
              ? const Color(0xFF6C3CE1).withAlpha(120)
              : Colors.white.withAlpha(20),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isCurrentUser
                        ? const Color(0xFFB39DDB)
                        : Colors.white70,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              Text(
                '$hp/$maxHp',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: hpColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: hpRatio,
              minHeight: 5,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(hpColor),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2 — Players: full roster with HP, attacks, status
// ─────────────────────────────────────────────────────────────────────────────

class _PlayersTab extends ConsumerWidget {
  final String leagueId;
  final int maxHp;

  const _PlayersTab({required this.leagueId, required this.maxHp});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(leagueMembersProvider(leagueId));
    final currentUid = ref.watch(authStateProvider).valueOrNull?.uid;

    return membersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          e.toString(),
          style: const TextStyle(color: Colors.white54),
        ),
      ),
      data: (members) {
        if (members.isEmpty) {
          return Center(
            child: Text(
              context.tr('noFightersYet'),
              style: const TextStyle(color: Colors.white54),
            ),
          );
        }
        final sorted = [...members]
          ..sort((a, b) {
            if (a.id == currentUid) return -1;
            if (b.id == currentUid) return 1;
            return b
                .currentHp(leagueId, maxHp: maxHp)
                .compareTo(a.currentHp(leagueId, maxHp: maxHp));
          });

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: sorted.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) => _PlayerCard(
            user: sorted[index],
            rank: index + 1,
            leagueId: leagueId,
            maxHp: maxHp,
            isCurrentUser: sorted[index].id == currentUid,
          ),
        );
      },
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final UserModel user;
  final int rank;
  final String leagueId;
  final int maxHp;
  final bool isCurrentUser;

  const _PlayerCard({
    required this.user,
    required this.rank,
    required this.leagueId,
    required this.maxHp,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    final hp = user.currentHp(leagueId, maxHp: maxHp);
    final hpRatio = maxHp > 0 ? (hp / maxHp).clamp(0.0, 1.0) : 0.0;
    final hpColor = hpRatio > 0.6
        ? const Color(0xFF4CAF50)
        : hpRatio > 0.3
        ? const Color(0xFFFFC107)
        : const Color(0xFFE53935);
    final isKO = hp <= 0;
    final name = user.name.isNotEmpty ? user.name : user.email;

    // Attacks remaining today
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final attacksUsed = (user.lastAttackDate == todayStr)
        ? user.todayAttacks
        : 0;
    final attacksLeft = (kMaxDailyAttacks - attacksUsed).clamp(
      0,
      kMaxDailyAttacks,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? const Color(0xFF6C3CE1).withAlpha(22)
            : Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrentUser
              ? const Color(0xFF6C3CE1).withAlpha(100)
              : Colors.white.withAlpha(12),
        ),
      ),
      child: Row(
        children: [
          // ── Rank ────────────────────────────────────────────────────
          SizedBox(
            width: 26,
            child: Text(
              '#$rank',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isKO ? Colors.red.withAlpha(180) : Colors.white38,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // ── Sprite ──────────────────────────────────────────────────
          Opacity(
            opacity: isKO ? 0.40 : 1.0,
            child: FighterSprite(
              skin: user.characterSkin,
              size: 48,
              isKO: isKO,
              pose: FighterPose.idle,
            ),
          ),
          const SizedBox(width: 12),
          // ── Name + HP bar + status ───────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name row
                Row(
                  children: [
                    if (isCurrentUser)
                      Container(
                        margin: const EdgeInsets.only(right: 5),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C3CE1).withAlpha(120),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'YOU',
                          style: TextStyle(
                            color: Color(0xFFB39DDB),
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    if (isKO)
                      Container(
                        margin: const EdgeInsets.only(right: 5),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withAlpha(60),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'K.O.',
                          style: TextStyle(
                            color: Color(0xFFEF9A9A),
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                // HP bar
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: hpRatio,
                          minHeight: 7,
                          backgroundColor: Colors.white10,
                          valueColor: AlwaysStoppedAnimation<Color>(hpColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$hp/$maxHp',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: hpColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Attacks + coins row
                Row(
                  children: [
                    const Icon(Icons.bolt, size: 11, color: Color(0xFFFFC107)),
                    const SizedBox(width: 3),
                    Text(
                      '$attacksLeft attacks left',
                      style: TextStyle(
                        fontSize: 10,
                        color: attacksLeft > 0
                            ? const Color(0xFFFFC107)
                            : Colors.white38,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text('🪙', style: TextStyle(fontSize: 10)),
                    Text(
                      '${user.coins}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// My Status Banner — shown at the top of the Ring tab
// ─────────────────────────────────────────────────────────────────────────────

class _MyStatusBanner extends ConsumerWidget {
  final UserModel user;
  final String leagueId;
  final int maxHp;

  const _MyStatusBanner({
    required this.user,
    required this.leagueId,
    required this.maxHp,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hp = user.currentHp(leagueId, maxHp: maxHp);
    final hpRatio = maxHp > 0 ? (hp / maxHp).clamp(0.0, 1.0) : 0.0;
    final hpColor = hpRatio > 0.6
        ? const Color(0xFF4CAF50)
        : hpRatio > 0.3
        ? const Color(0xFFFFC107)
        : const Color(0xFFE53935);
    final isKO = hp <= 0;

    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final attacksUsed = (user.lastAttackDate == todayStr)
        ? user.todayAttacks
        : 0;
    final attacksLeft = (kMaxDailyAttacks - attacksUsed).clamp(
      0,
      kMaxDailyAttacks,
    );
    final attackColor = attacksLeft == 0
        ? Colors.white24
        : attacksLeft <= 2
        ? const Color(0xFFFFC107)
        : const Color(0xFF69F0AE);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isKO
            ? Colors.redAccent.withAlpha(18)
            : const Color(0xFF6C3CE1).withAlpha(20),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isKO
              ? Colors.redAccent.withAlpha(100)
              : const Color(0xFF6C3CE1).withAlpha(90),
        ),
      ),
      child: Row(
        children: [
          // Fighter sprite
          Opacity(
            opacity: isKO ? 0.45 : 1.0,
            child: FighterSprite(
              skin: user.characterSkin,
              size: 44,
              isKO: isKO,
              pose: FighterPose.idle,
            ),
          ),
          const SizedBox(width: 10),
          // Name + HP bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C3CE1).withAlpha(120),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'YOU',
                        style: TextStyle(
                          color: Color(0xFFB39DDB),
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (isKO)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withAlpha(60),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'K.O.',
                          style: TextStyle(
                            color: Color(0xFFEF9A9A),
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    Flexible(
                      child: Text(
                        user.name.isNotEmpty ? user.name : user.email,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: hpRatio,
                          minHeight: 7,
                          backgroundColor: Colors.white10,
                          valueColor: AlwaysStoppedAnimation<Color>(hpColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$hp/$maxHp',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: hpColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Attacks + coins summary
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dot bar for attacks
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(kMaxDailyAttacks, (i) {
                  final filled = i < attacksUsed;
                  return Container(
                    width: 9,
                    height: 9,
                    margin: const EdgeInsets.only(left: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled
                          ? attackColor.withAlpha(180)
                          : Colors.white12,
                      border: Border.all(
                        color: filled
                            ? attackColor.withAlpha(200)
                            : Colors.white24,
                        width: 1,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 3),
              Text(
                '$attacksLeft left',
                style: TextStyle(
                  fontSize: 10,
                  color: attackColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '🪙${user.coins}',
                style: const TextStyle(fontSize: 10, color: Colors.white38),
              ),
              const SizedBox(height: 4),
              // Shield button / indicator
              _ShieldChip(user: user, leagueId: leagueId, ref: ref),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shield chip — shows active shield timer or buy button
// ─────────────────────────────────────────────────────────────────────────────

class _ShieldChip extends StatelessWidget {
  final UserModel user;
  final String leagueId;
  final WidgetRef ref;
  const _ShieldChip({
    required this.user,
    required this.leagueId,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final expiry = user.shieldByLeague[leagueId];
    final now = DateTime.now().toUtc();
    final isActive = expiry != null && now.isBefore(DateTime.parse(expiry));

    if (isActive) {
      final remaining = DateTime.parse(expiry).difference(now);
      final h = remaining.inHours;
      final m = remaining.inMinutes % 60;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF1565C0).withAlpha(60),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF42A5F5).withAlpha(160)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🛡️', style: TextStyle(fontSize: 10)),
            const SizedBox(width: 3),
            Text(
              h > 0 ? '${h}h ${m}m' : '${m}m',
              style: const TextStyle(
                fontSize: 9,
                color: Color(0xFF90CAF9),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    // No shield — show buy button
    return GestureDetector(
      onTap: () => _showBuyShieldDialog(context, user, leagueId, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(8),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🛡️', style: TextStyle(fontSize: 10)),
            const SizedBox(width: 3),
            Text(
              context.tr('buyShieldShort'),
              style: const TextStyle(fontSize: 9, color: Colors.white38),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showBuyShieldDialog(
  BuildContext context,
  UserModel user,
  String leagueId,
  WidgetRef ref,
) async {
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Text('🛡️', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Text(
            context.tr('buyShieldTitle'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.trArgs('buyShieldDesc', {'coins': '${user.coins}'}),
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ...kShieldOptions.map((opt) {
            final cost = opt['cost'] as int;
            final hours = opt['hours'] as int;
            final label = opt['label'] as String;
            final canAfford = user.coins >= cost;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: canAfford
                    ? () async {
                        Navigator.of(ctx).pop();
                        final ok = await UserRepository().buyShield(
                          uid: user.id,
                          leagueId: leagueId,
                          hours: hours,
                          cost: cost,
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok
                                  ? context.trArgs('shieldActiveFor', {
                                      'duration': label,
                                    })
                                  : context.tr('notEnoughCoins'),
                            ),
                            backgroundColor: ok
                                ? const Color(0xFF1565C0)
                                : Colors.redAccent,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: canAfford
                        ? const Color(0xFF1565C0).withAlpha(30)
                        : Colors.white.withAlpha(5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: canAfford
                          ? const Color(0xFF42A5F5).withAlpha(120)
                          : Colors.white12,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '🛡️ $label',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: canAfford ? Colors.white : Colors.white38,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '🪙$cost',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: canAfford
                              ? const Color(0xFFFFB74D)
                              : Colors.white24,
                        ),
                      ),
                      if (!canAfford) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.lock, size: 13, color: Colors.white24),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(
            context.tr('cancel'),
            style: const TextStyle(color: Colors.white38),
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Attack hint / CTA bar — shown below the ring
// ─────────────────────────────────────────────────────────────────────────────

class _AttackHintBar extends StatelessWidget {
  final int attacksLeft;
  final bool opponentIsAlive;
  final VoidCallback? onAttackTap;

  const _AttackHintBar({
    required this.attacksLeft,
    required this.opponentIsAlive,
    this.onAttackTap,
  });

  @override
  Widget build(BuildContext context) {
    final canAttack = attacksLeft > 0 && opponentIsAlive;
    final allKO = !opponentIsAlive;

    String message;
    IconData icon;
    Color barColor;
    Color iconColor;

    if (allKO) {
      message = context.tr('allKoKeepEarning');
      icon = Icons.emoji_events;
      barColor = const Color(0xFFFFD700).withAlpha(18);
      iconColor = const Color(0xFFFFD700);
    } else if (attacksLeft == 0) {
      message = context.tr('noAttacksComeBack');
      icon = Icons.block;
      barColor = Colors.redAccent.withAlpha(15);
      iconColor = Colors.redAccent;
    } else {
      message = context.tr('attackHintTap');
      icon = Icons.touch_app;
      barColor = const Color(0xFF6C3CE1).withAlpha(18);
      iconColor = const Color(0xFF9575CD);
    }

    final buttonColor = allKO
        ? const Color(0xFFFFD700)
        : const Color(0xFFE53935);
    final buttonTextColor = allKO ? const Color(0xFF1A1A2E) : Colors.white;

    return GestureDetector(
      onTap: onAttackTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: barColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (canAttack || (allKO && onAttackTap != null))
                ? const Color(0xFF6C3CE1).withAlpha(80)
                : Colors.white.withAlpha(15),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 12,
                  color: (canAttack || allKO) ? Colors.white70 : Colors.white38,
                ),
              ),
            ),
            if (onAttackTap != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: buttonColor.withAlpha(220),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(color: buttonColor.withAlpha(80), blurRadius: 6),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      allKO ? Icons.check_circle_outline : Icons.bolt,
                      size: 13,
                      color: buttonTextColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      allKO
                          ? context.tr('completeBadge')
                          : context.tr('attackBadge'),
                      style: TextStyle(
                        fontSize: 10,
                        color: buttonTextColor,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Legend dot
// ─────────────────────────────────────────────────────────────────────────────

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Arena attack flow — task picker dialog + battle animation
// ─────────────────────────────────────────────────────────────────────────────

/// Top-level function: opens the task picker for attacking [target] from Arena.
Future<void> showArenaAttackDialog(
  BuildContext context,
  WidgetRef ref,
  UserModel? target,
  String leagueId,
  int maxHp,
) async {
  final leagueAsync = ref.read(leagueProvider(leagueId));
  final league = leagueAsync.valueOrNull;
  if (league == null) return;

  final currentUid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
  if (currentUid.isEmpty) return;

  // Fetch tasks and current user in parallel — go directly to Firestore so
  // we always get fresh data even if the Tasks screen was never visited.
  final results = await Future.wait([
    TaskRepository().watchTasks(leagueId).first,
    UserRepository().getUser(currentUid),
  ]);
  final allLeagueTasks = results[0] as List<TaskModel>;
  final currentUser = results[1] as UserModel?;

  // Filter to only tasks assigned to current user
  final allTasks =
      allLeagueTasks.where((t) => t.assigneeId == currentUid).toList()
        ..sort((a, b) {
          // One-time tasks first, then recurring
          if (a.repeat == TaskRepeat.none && b.repeat != TaskRepeat.none)
            return -1;
          if (a.repeat != TaskRepeat.none && b.repeat == TaskRepeat.none)
            return 1;
          return 0;
        });

  // Check daily attack cap
  final todayStr = DateTime.now().toIso8601String().substring(0, 10);
  final attacksUsed = (currentUser?.lastAttackDate == todayStr)
      ? (currentUser?.todayAttacks ?? 0)
      : 0;
  final attacksRemaining = (kMaxDailyAttacks - attacksUsed).clamp(
    0,
    kMaxDailyAttacks,
  );

  if (!context.mounted) return;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1A1A2E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _ArenaTaskPickerSheet(
      target: target,
      currentUser: currentUser,
      tasks: allTasks,
      attacksRemaining: attacksRemaining,
      maxHp: maxHp,
      leagueId: leagueId,
      // When there's a real target, offer the "complete without attacking" option
      onCompleteNoTarget: target != null
          ? () async {
              Navigator.of(ctx).pop();
              // Reopen the sheet with target=null (XP/coins only)
              if (!context.mounted) return;
              await showArenaAttackDialog(context, ref, null, leagueId, maxHp);
            }
          : null,
      onTaskSelected: (task) async {
        Navigator.of(ctx).pop();
        if (!context.mounted) return;
        final maxHp = maxHpForType(league.competitionType);
        final attackerIsKO =
            currentUser != null &&
            currentUser.currentHp(leagueId, maxHp: maxHp) <= 0;
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => _ArenaBattleDialog(
            attacker: currentUser,
            target: target,
            task: task,
            attackerIsKO: attackerIsKO,
            noAttacksLeft: attacksRemaining == 0,
            onComplete: () async {
              final event = await ref
                  .read(taskServiceProvider)
                  .completeTask(
                    task: task,
                    doerId: currentUid,
                    targetId: target?.id,
                    leagueType: league.competitionType,
                  );
              return event.coinsEarned;
            },
          ),
        );
      },
    ),
  );
}

/// Variant used from the league hub: the task is already known, so we skip
/// the task picker and show an opponent picker first.
Future<void> showArenaAttackDialogWithTask(
  BuildContext context,
  WidgetRef ref,
  TaskModel task,
  String leagueId,
  int maxHp,
) async {
  final leagueAsync = ref.read(leagueProvider(leagueId));
  final league = leagueAsync.valueOrNull;
  if (league == null) return;

  final currentUid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
  if (currentUid.isEmpty) return;

  final currentUser = await UserRepository().getUser(currentUid);
  // All league members INCLUDING the current user, so the doer can be changed
  // (default: the current user).
  final allMembers = List<UserModel>.from(
    ref.read(leagueMembersProvider(leagueId)).valueOrNull ?? const [],
  );
  if (currentUser != null && !allMembers.any((m) => m.id == currentUid)) {
    allMembers.insert(0, currentUser);
  }

  if (!context.mounted) return;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1A1A2E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _OpponentPickerSheet(
      task: task,
      allMembers: allMembers,
      currentUserId: currentUid,
      leagueId: leagueId,
      maxHp: maxHp,
      onSkip: task.repeat == TaskRepeat.none
          ? null
          : () async {
              final confirmed = await showDialog<bool>(
                context: ctx,
                builder: (dctx) => AlertDialog(
                  backgroundColor: const Color(0xFF1A1A2E),
                  title: Text(
                    context.tr('skipOccurrenceTitle'),
                    style: const TextStyle(color: Colors.white),
                  ),
                  content: Text(
                    context.trArgs('skipOccurrenceMessage', {
                      'title': task.title,
                    }),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dctx, false),
                      child: Text(context.tr('cancel')),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(dctx, true),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFEF9A9A),
                      ),
                      child: Text(context.tr('skipConfirm')),
                    ),
                  ],
                ),
              );
              if (confirmed != true) return;
              try {
                await ref.read(taskServiceProvider).skipOccurrence(task);
              } catch (e) {
                if (isQuotaError(e)) {
                  handleQuotaError(e);
                  return;
                }
              }
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.tr('skippedToast'))),
                );
              }
            },
      onConfirm: (UserModel doer, UserModel? target) async {
        Navigator.of(ctx).pop();
        if (!context.mounted) return;
        final resolvedMaxHp = maxHpForType(league.competitionType);
        final attackerIsKO =
            doer.currentHp(leagueId, maxHp: resolvedMaxHp) <= 0;
        final todayStr = DateTime.now().toIso8601String().substring(0, 10);
        final used = doer.lastAttackDate == todayStr ? doer.todayAttacks : 0;
        final remaining = (kMaxDailyAttacks - used).clamp(0, kMaxDailyAttacks);
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => _ArenaBattleDialog(
            attacker: doer,
            target: target,
            task: task,
            attackerIsKO: attackerIsKO,
            noAttacksLeft: remaining == 0,
            onComplete: () async {
              final event = await ref
                  .read(taskServiceProvider)
                  .completeTask(
                    task: task,
                    doerId: doer.id,
                    targetId: target?.id,
                    leagueType: league.competitionType,
                  );
              return event.coinsEarned;
            },
          ),
        );
      },
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Opponent picker sheet — used from league hub when task is already chosen
// ─────────────────────────────────────────────────────────────────────────────

class _OpponentPickerSheet extends ConsumerStatefulWidget {
  final TaskModel task;
  final List<UserModel> allMembers; // all league members incl. current user
  final String currentUserId;
  final String leagueId;
  final int maxHp;
  final void Function(UserModel doer, UserModel? target) onConfirm;
  final VoidCallback? onSkip; // recurring tasks only: skip this occurrence

  const _OpponentPickerSheet({
    required this.task,
    required this.allMembers,
    required this.currentUserId,
    required this.leagueId,
    required this.maxHp,
    required this.onConfirm,
    this.onSkip,
  });

  @override
  ConsumerState<_OpponentPickerSheet> createState() =>
      _OpponentPickerSheetState();
}

class _OpponentPickerSheetState extends ConsumerState<_OpponentPickerSheet> {
  late String _doerId;
  bool _watchingAd = false;
  // Ad-for-coin rewards claimed in THIS session (applies to current user).
  int _adRewardsClaimed = 0;

  @override
  void initState() {
    super.initState();
    _doerId = widget.currentUserId;
  }

  int _attacksRemainingFor(UserModel doer) {
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final used = doer.lastAttackDate == todayStr ? doer.todayAttacks : 0;
    return (kMaxDailyAttacks - used).clamp(0, kMaxDailyAttacks);
  }

  /// Whether the current user can still claim an ad-for-coin reward today.
  bool _canWatchAdForCoin(UserModel doer) {
    if (doer.id != widget.currentUserId) return false;
    if (!ref.read(adsServiceProvider).canOfferReward) return false;
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final storedClaims = doer.lastBonusAttackDate == todayStr
        ? doer.bonusAttacksToday
        : 0;
    return storedClaims + _adRewardsClaimed < kMaxAdAttacks;
  }

  Future<void> _watchAdForCoin(UserModel doer) async {
    setState(() => _watchingAd = true);
    final ads = ref.read(adsServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final earned = await ads.showRewarded();
      if (!mounted) return;
      if (!earned) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.tr('watchAdNotReady'))),
        );
        return;
      }
      final coins = await ref
          .read(userRepositoryProvider)
          .grantAdAttackCoin(doer.id);
      if (!mounted) return;
      if (coins > 0) {
        setState(() => _adRewardsClaimed += 1);
        messenger.showSnackBar(
          SnackBar(content: Text(context.tr('adAttackUnlocked'))),
        );
      }
    } finally {
      if (mounted) setState(() => _watchingAd = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final leagueId = widget.leagueId;
    final maxHp = widget.maxHp;

    final doer = widget.allMembers.firstWhere(
      (m) => m.id == _doerId,
      orElse: () => widget.allMembers.first,
    );
    final members = widget.allMembers.where((m) => m.id != doer.id).toList();
    final attacksRemaining = _attacksRemainingFor(doer);

    final liveOpponents = members
        .where((m) => m.currentHp(leagueId, maxHp: maxHp) > 0)
        .toList();
    final canAttack = attacksRemaining > 0 && liveOpponents.isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollCtrl) => ListView(
        controller: scrollCtrl,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Task being completed
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF6C3CE1).withAlpha(20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF6C3CE1).withAlpha(80)),
            ),
            child: Row(
              children: [
                const Icon(Icons.task_alt, color: Color(0xFF9575CD), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    task.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Doer selector — who actually did the task (default: current user)
          if (widget.allMembers.length > 1) ...[
            Text(
              context.tr('whoDidIt'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 78,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.allMembers.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final m = widget.allMembers[i];
                  return _DoerChip(
                    member: m,
                    selected: m.id == _doerId,
                    isMe: m.id == widget.currentUserId,
                    onTap: () => setState(() => _doerId = m.id),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // When someone ELSE did the task, no attacking is allowed: it only
          // grants coins/XP to that person and does not consume daily attacks.
          if (doer.id != widget.currentUserId) ...[
            _OpponentRow(
              name: context.trArgs('creditsOnlyFor', {
                'name': doer.name.isNotEmpty ? doer.name : doer.email,
              }),
              subtitle: context.tr('completeNoDamage'),
              icon: Icons.emoji_events_outlined,
              iconColor: const Color(0xFFFFD700),
              hp: null,
              maxHp: maxHp,
              leagueId: leagueId,
              onTap: () => widget.onConfirm(doer, null),
            ),
          ] else ...[
            // Title
            Text(
              context.tr('whoToAttack'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              canAttack
                  ? context.tr('selectOpponentOrComplete')
                  : attacksRemaining == 0
                  ? context.tr('noAttacksLeftEarnCoins')
                  : context.tr('allKoComplete'),
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 16),

            // No-attack option (always shown first)
            _OpponentRow(
              name: context.tr('noOneJustEarn'),
              subtitle: context.tr('completeNoDamage'),
              icon: Icons.monetization_on_outlined,
              iconColor: const Color(0xFFFFD700),
              hp: null,
              maxHp: maxHp,
              leagueId: leagueId,
              onTap: () => widget.onConfirm(doer, null),
            ),
            const SizedBox(height: 8),

            if (liveOpponents.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  context.tr('noLiveOpponents'),
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              )
            else if (!canAttack)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  children: [
                    Text(
                      context.tr('attackCapUnlockTomorrow'),
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_canWatchAdForCoin(doer)) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _watchingAd
                              ? null
                              : () => _watchAdForCoin(doer),
                          icon: _watchingAd
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.play_circle_outline, size: 18),
                          label: Text(context.tr('watchAdToAttack')),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFFFD54F),
                            side: BorderSide(
                              color: const Color(0xFFFFC107).withAlpha(120),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              )
            else ...[
              const Divider(color: Colors.white12),
              const SizedBox(height: 8),
              ...liveOpponents.map((m) {
                final shieldExpiry = m.shieldByLeague[leagueId];
                final hasShield =
                    shieldExpiry != null &&
                    DateTime.now().toUtc().isBefore(
                      DateTime.parse(shieldExpiry),
                    );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _OpponentRow(
                    name: m.name.isNotEmpty ? m.name : m.email,
                    subtitle: hasShield ? context.tr('shieldActive') : null,
                    icon: null,
                    iconColor: null,
                    member: m,
                    hp: m.currentHp(leagueId, maxHp: maxHp),
                    maxHp: maxHp,
                    leagueId: leagueId,
                    onTap: () => widget.onConfirm(doer, m),
                  ),
                );
              }),
            ],
          ],

          // Skip option — recurring tasks only
          if (task.repeat != TaskRepeat.none && widget.onSkip != null) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white12),
            const SizedBox(height: 4),
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.skip_next, size: 18),
                style: TextButton.styleFrom(foregroundColor: Colors.white54),
                label: Text(context.tr('skipOccurrence')),
                onPressed: widget.onSkip,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DoerChip extends StatelessWidget {
  final UserModel member;
  final bool selected;
  final bool isMe;
  final VoidCallback onTap;

  const _DoerChip({
    required this.member,
    required this.selected,
    required this.isMe,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = isMe
        ? context.tr('youTag')
        : (member.name.isNotEmpty ? member.name : member.email);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF6C3CE1).withAlpha(60)
              : Colors.white.withAlpha(10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF9575CD) : Colors.white24,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FighterSprite(skin: member.characterSkin, size: 34),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white60,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpponentRow extends StatelessWidget {
  final String name;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final UserModel? member;
  final int? hp;
  final int maxHp;
  final String leagueId;
  final VoidCallback onTap;

  const _OpponentRow({
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.hp,
    required this.maxHp,
    required this.leagueId,
    required this.onTap,
    this.member,
  });

  @override
  Widget build(BuildContext context) {
    final hpRatio = (hp != null && maxHp > 0)
        ? (hp! / maxHp).clamp(0.0, 1.0)
        : null;
    final hpColor = hpRatio == null
        ? Colors.white38
        : hpRatio > 0.6
        ? const Color(0xFF4CAF50)
        : hpRatio > 0.3
        ? const Color(0xFFFFC107)
        : const Color(0xFFE53935);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withAlpha(25)),
        ),
        child: Row(
          children: [
            if (member != null)
              FighterSprite(skin: member!.characterSkin, size: 40)
            else
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (iconColor ?? Colors.white).withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor ?? Colors.white54, size: 20),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                  if (hpRatio != null) ...[
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: hpRatio,
                              minHeight: 5,
                              backgroundColor: Colors.white10,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                hpColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$hp/$maxHp',
                          style: TextStyle(
                            fontSize: 9,
                            color: hpColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Task picker bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _ArenaTaskPickerSheet extends ConsumerStatefulWidget {
  final UserModel? target;
  final UserModel? currentUser;
  final List<TaskModel> tasks;
  final int attacksRemaining;
  final int maxHp;
  final String leagueId;
  final void Function(TaskModel) onTaskSelected;
  final VoidCallback? onCompleteNoTarget; // complete a task without attacking

  const _ArenaTaskPickerSheet({
    required this.target,
    required this.currentUser,
    required this.tasks,
    required this.attacksRemaining,
    required this.maxHp,
    required this.leagueId,
    required this.onTaskSelected,
    this.onCompleteNoTarget,
  });

  @override
  ConsumerState<_ArenaTaskPickerSheet> createState() =>
      _ArenaTaskPickerSheetState();
}

class _ArenaTaskPickerSheetState extends ConsumerState<_ArenaTaskPickerSheet> {
  bool _watchingAd = false;
  // Ad-for-coin rewards claimed in THIS session.
  int _adRewardsClaimed = 0;

  /// Whether the current user can still claim an ad-for-coin reward today.
  bool _canWatchAdForCoin() {
    final user = widget.currentUser;
    if (user == null) return false;
    if (!ref.read(adsServiceProvider).canOfferReward) return false;
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final storedClaims = user.lastBonusAttackDate == todayStr
        ? user.bonusAttacksToday
        : 0;
    return storedClaims + _adRewardsClaimed < kMaxAdAttacks;
  }

  Future<void> _watchAdForCoin() async {
    final user = widget.currentUser;
    if (user == null) return;
    setState(() => _watchingAd = true);
    final ads = ref.read(adsServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final earned = await ads.showRewarded();
      if (!mounted) return;
      if (!earned) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.tr('watchAdNotReady'))),
        );
        return;
      }
      final coins = await ref
          .read(userRepositoryProvider)
          .grantAdAttackCoin(user.id);
      if (!mounted) return;
      if (coins > 0) {
        setState(() => _adRewardsClaimed += 1);
        messenger.showSnackBar(
          SnackBar(content: Text(context.tr('adAttackUnlocked'))),
        );
      }
    } finally {
      if (mounted) setState(() => _watchingAd = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.target;
    final tasks = widget.tasks;
    final attacksRemaining = widget.attacksRemaining;
    final maxHp = widget.maxHp;
    final leagueId = widget.leagueId;
    final onTaskSelected = widget.onTaskSelected;
    final onCompleteNoTarget = widget.onCompleteNoTarget;
    // target == null means all opponents are KO — completing for XP only
    final noTarget = target == null;
    final targetName = noTarget
        ? ''
        : (target.name.isNotEmpty ? target.name : target.email);
    final hp = noTarget ? 0 : target.currentHp(leagueId, maxHp: maxHp);
    final hpRatio = noTarget || maxHp == 0 ? 0.0 : (hp / maxHp).clamp(0.0, 1.0);
    final hpColor = hpRatio > 0.6
        ? const Color(0xFF4CAF50)
        : hpRatio > 0.3
        ? const Color(0xFFFFC107)
        : const Color(0xFFE53935);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) => ListView(
        controller: scrollCtrl,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header — target fighter card OR "all KO" banner
          if (noTarget)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withAlpha(18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFFD700).withAlpha(80),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.emoji_events,
                    color: Color(0xFFFFD700),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('allKoTitle'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.tr('allKoSubtitle'),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFE53935).withAlpha(180),
                      width: 2,
                    ),
                  ),
                  child: FighterSprite(skin: target.characterSkin, size: 52),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.trArgs('attackFighter', {'name': targetName}),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: hpRatio,
                          minHeight: 7,
                          backgroundColor: Colors.white10,
                          valueColor: AlwaysStoppedAnimation<Color>(hpColor),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$hp/$maxHp HP  ·  🪙${target.coins}',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

          const SizedBox(height: 16),

          // ── "Complete without attacking" option — only when a real target exists
          if (!noTarget && onCompleteNoTarget != null) ...[
            GestureDetector(
              onTap: onCompleteNoTarget,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(8),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: Colors.white54,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.tr('completeWithoutAttacking'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: Colors.white24,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          const Divider(color: Colors.white12),
          const SizedBox(height: 12),

          // Attacks cap warning or remaining indicator
          if (attacksRemaining == 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE53935).withAlpha(25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFE53935).withAlpha(120),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFEF9A9A),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.trArgs('attackCapReached', {
                        'max': '$kMaxDailyAttacks',
                      }),
                      style: const TextStyle(
                        color: Color(0xFFEF9A9A),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_canWatchAdForCoin()) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _watchingAd ? null : _watchAdForCoin,
                  icon: _watchingAd
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_circle_outline, size: 18),
                  label: Text(context.tr('watchAdToAttack')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFFD54F),
                    side: BorderSide(
                      color: const Color(0xFFFFC107).withAlpha(120),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
          ] else ...[
            Row(
              children: [
                Icon(
                  Icons.bolt,
                  size: 14,
                  color: attacksRemaining > 2
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFFFC107),
                ),
                const SizedBox(width: 4),
                Text(
                  context.trArgs('attacksLeft', {'n': '$attacksRemaining'}),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: attacksRemaining > 2
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFFFC107),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Task list label
          Text(
            context.tr('selectTaskToAttack'),
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 10),

          // Task cards or empty state
          if (tasks.isEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.assignment_outlined,
                    color: Colors.white24,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.tr('noTasksToAttack'),
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr('noTasksToAttackSub'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
          ] else
            ...tasks.map(
              (task) => _ArenaTaskCard(
                task: task,
                enabled: true,
                onTap: () => onTaskSelected(task),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single task card in the arena task picker
// ─────────────────────────────────────────────────────────────────────────────

class _ArenaTaskCard extends StatelessWidget {
  final TaskModel task;
  final bool enabled;
  final VoidCallback? onTap;

  const _ArenaTaskCard({required this.task, required this.enabled, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isRecurring = task.repeat != TaskRepeat.none;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: enabled
                  ? const Color(0xFF6C3CE1).withAlpha(15)
                  : Colors.white.withAlpha(5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: enabled
                    ? const Color(0xFF6C3CE1).withAlpha(80)
                    : Colors.white.withAlpha(10),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935).withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '🥊${task.effort}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: enabled ? Colors.white : Colors.white38,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            isRecurring ? Icons.repeat : Icons.event,
                            size: 11,
                            color: const Color(0xFF9575CD),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${task.effort} ${context.tr('statsDmg')}  ·  ${isRecurring ? context.tr('repeat${task.repeat.name[0].toUpperCase()}${task.repeat.name.substring(1)}') : context.tr('oneTime')}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (enabled)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935).withAlpha(180),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt, size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'GO',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Arena battle animation dialog
// ─────────────────────────────────────────────────────────────────────────────

enum _ArenaBattlePhase { idle, attacking, hit, result }

class _ArenaBattleDialog extends StatefulWidget {
  final UserModel? attacker;
  final UserModel? target;
  final TaskModel task;
  final bool attackerIsKO;
  final bool noAttacksLeft;
  final Future<int> Function() onComplete;

  const _ArenaBattleDialog({
    required this.attacker,
    required this.target,
    required this.task,
    required this.attackerIsKO,
    this.noAttacksLeft = false,
    required this.onComplete,
  });

  @override
  State<_ArenaBattleDialog> createState() => _ArenaBattleDialogState();
}

class _ArenaBattleDialogState extends State<_ArenaBattleDialog>
    with SingleTickerProviderStateMixin {
  _ArenaBattlePhase _phase = _ArenaBattlePhase.idle;
  late AnimationController _shakeCtrl;
  String _resultMessage = '';
  bool _loading = false;

  /// True when no damage will be dealt to an opponent — i.e. there is no
  /// target, the attacker is K.O., or the daily attack cap is reached. In
  /// these cases we show a solo "task complete" celebration instead of an
  /// attack-and-hit animation against a placeholder opponent.
  bool get _isSolo =>
      widget.target == null || widget.attackerIsKO || widget.noAttacksLeft;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    Future.delayed(const Duration(milliseconds: 400), _startBattle);
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  Future<void> _startBattle() async {
    if (!mounted) return;
    setState(() => _phase = _ArenaBattlePhase.attacking);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    // Only play the hit/explosion when a real opponent is being damaged.
    if (!_isSolo) {
      setState(() => _phase = _ArenaBattlePhase.hit);
      _shakeCtrl.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
    }
    setState(() => _loading = true);
    try {
      final coinsEarned = await widget.onComplete();
      final targetName = widget.target == null
          ? null
          : (widget.target!.name.isNotEmpty
                ? widget.target!.name
                : widget.target!.email);
      final coinTxt = coinsEarned > 0
          ? context.trArgs('resultCoins', {'coins': '$coinsEarned'})
          : context.tr('resultNoCoinsToday');
      if (widget.attackerIsKO) {
        _resultMessage = context.tr('resultKO');
      } else if (widget.noAttacksLeft) {
        _resultMessage = '$coinTxt  ·  ${context.tr('resultNoDamageCap')}';
      } else if (targetName == null) {
        _resultMessage = coinTxt;
      } else {
        _resultMessage =
            '$coinTxt  ·  ${context.trArgs('resultDamage', {'dmg': '${widget.task.effort}', 'name': targetName})}';
      }
    } catch (e) {
      if (handleQuotaError(e, context: mounted ? context : null)) {
        if (mounted) Navigator.of(context).pop();
        return;
      }
      _resultMessage = 'Error: $e';
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _phase = _ArenaBattlePhase.result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final attackerSkin = widget.attacker?.characterSkin ?? 'warrior';
    final targetSkin = widget.target?.characterSkin ?? 'warrior';
    final targetName = widget.target == null
        ? null
        : (widget.target!.name.isNotEmpty
              ? widget.target!.name
              : widget.target!.email);
    final attackerName = widget.attacker?.name.isNotEmpty == true
        ? widget.attacker!.name
        : 'You';
    final damage = widget.task.effort;

    return Dialog(
      backgroundColor: const Color(0xFF0D0D1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _phase == _ArenaBattlePhase.result
                  ? (widget.attackerIsKO ? '📋 Task Logged' : '🏆 Result')
                  : (widget.attackerIsKO
                        ? '📋 Logging Task...'
                        : _isSolo
                        ? '✅ Completing...'
                        : '🥊 Attacking!'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.task.title,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            if (widget.attackerIsKO) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent.withAlpha(80)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFEF9A9A),
                      size: 13,
                    ),
                    SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        'You are K.O. — no coins or damage',
                        style: TextStyle(
                          color: Color(0xFFEF9A9A),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (widget.noAttacksLeft) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orangeAccent.withAlpha(80)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFFFCC80),
                      size: 13,
                    ),
                    SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        'Attack cap reached — task still counts!',
                        style: TextStyle(
                          color: Color(0xFFFFCC80),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),

            SizedBox(
              height: 140,
              child: _isSolo
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          AnimatedSlide(
                            offset: _phase == _ArenaBattlePhase.attacking
                                ? const Offset(0, -0.15)
                                : Offset.zero,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            child: FighterSprite(
                              skin: attackerSkin,
                              size: 100,
                              pose: _phase == _ArenaBattlePhase.attacking
                                  ? FighterPose.attack
                                  : FighterPose.idle,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            attackerName,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Attacker
                        Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            AnimatedSlide(
                              offset:
                                  (_phase == _ArenaBattlePhase.attacking ||
                                      _phase == _ArenaBattlePhase.hit)
                                  ? const Offset(0.4, 0)
                                  : Offset.zero,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              child: FighterSprite(
                                skin: attackerSkin,
                                size: 90,
                                pose:
                                    (_phase == _ArenaBattlePhase.attacking ||
                                        _phase == _ArenaBattlePhase.hit)
                                    ? FighterPose.attack
                                    : FighterPose.idle,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              attackerName,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),

                        // Impact / VS indicator
                        _phase == _ArenaBattlePhase.hit
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _ExplosionBurst()
                                      .animate()
                                      .fade(begin: 0, end: 1, duration: 80.ms)
                                      .scale(
                                        begin: const Offset(0.3, 0.3),
                                        end: const Offset(1.2, 1.2),
                                        duration: 220.ms,
                                        curve: Curves.elasticOut,
                                      ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '-$damage HP',
                                    style: const TextStyle(
                                      color: Color(0xFFFF5252),
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ).animate().fadeIn(
                                    delay: 80.ms,
                                    duration: 150.ms,
                                  ),
                                ],
                              )
                            : Text(
                                'VS',
                                style: TextStyle(
                                  color: _phase == _ArenaBattlePhase.attacking
                                      ? const Color(0xFFFFD600)
                                      : Colors.white24,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),

                        // Target
                        Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            AnimatedBuilder(
                              animation: _shakeCtrl,
                              builder: (_, child) {
                                final shake = _phase == _ArenaBattlePhase.hit
                                    ? math.sin(
                                            _shakeCtrl.value * math.pi * 10,
                                          ) *
                                          12.0 *
                                          (1 - _shakeCtrl.value)
                                    : 0.0;
                                final tintAlpha =
                                    (math.sin(_shakeCtrl.value * math.pi) * 180)
                                        .clamp(0, 180)
                                        .toInt();
                                return Transform.translate(
                                  offset: Offset(shake, 0),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Transform.scale(
                                        scaleX: -1,
                                        child: FighterSprite(
                                          skin: targetSkin,
                                          size: 90,
                                          pose: _phase == _ArenaBattlePhase.hit
                                              ? FighterPose.hit
                                              : FighterPose.idle,
                                        ),
                                      ),
                                      if (_phase == _ArenaBattlePhase.hit)
                                        Container(
                                          width: 90,
                                          height: 90,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Color.fromARGB(
                                              tintAlpha,
                                              255,
                                              50,
                                              50,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 4),
                            Text(
                              targetName ?? '???',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 24),
            if (_loading)
              const CircularProgressIndicator()
            else if (_phase == _ArenaBattlePhase.result)
              Column(
                children: [
                  Icon(
                    widget.attackerIsKO
                        ? Icons.sentiment_dissatisfied
                        : Icons.check_circle_outline,
                    color: widget.attackerIsKO
                        ? Colors.redAccent
                        : const Color(0xFF69F0AE),
                    size: 36,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _resultMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.tr('continueBtn')),
                  ),
                ],
              )
            else
              Text(
                _phase == _ArenaBattlePhase.idle
                    ? context.tr('preparing')
                    : _phase == _ArenaBattlePhase.attacking
                    ? (_isSolo
                          ? context.tr('completing')
                          : context.tr('attacking'))
                    : context.tr('hit'),
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
          ],
        ),
      ),
    );
  }
}
