import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/league_providers.dart';
import '../models/league_model.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/models/user_model.dart';
import '../../history/providers/history_providers.dart';
import '../../stats/providers/stats_providers.dart'
    show previousPeriodRankingProvider, isStartOfPeriod;
import '../../tasks/models/task_model.dart';
import '../../tasks/providers/task_providers.dart'
    show myUpcomingTasksProvider, myRecurringTasksProvider;
import '../../arena/screens/arena_screen.dart'
    show showArenaAttackDialogWithTask;
import '../../../core/l10n/app_localizations.dart';
import '../../../core/widgets/coins_chip.dart';

class LeagueScreen extends ConsumerWidget {
  final String leagueId;
  const LeagueScreen({super.key, required this.leagueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leagueAsync = ref.watch(leagueProvider(leagueId));
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final unseenAsync = ref.watch(unseenAttackCountProvider(leagueId));
    final unseenCount = unseenAsync.valueOrNull ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: leagueAsync.maybeWhen(
          data: (league) {
            if (league == null) return const Text('League');
            final memberCount = league.memberIds.length;
            final typeLabel = league.competitionType == CompetitionType.weekly
                ? 'Weekly'
                : 'Monthly';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  league.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$memberCount ${memberCount == 1 ? 'fighter' : 'fighters'} · $typeLabel',
                  style: const TextStyle(fontSize: 11, color: Colors.white54),
                ),
              ],
            );
          },
          orElse: () => const Text('League'),
        ),
        actions: [
          // ── Coins chip ──────────────────────────────────────────────
          if (currentUser != null) CoinsChip(coins: currentUser.coins),
          // ── Notification bell ───────────────────────────────────────
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {
              ref.read(notifSeenProvider(leagueId).notifier).markSeen();
              _showNotificationsPanel(context, ref, leagueId);
            },
            icon: Badge(
              label: Text('$unseenCount'),
              isLabelVisible: unseenCount > 0,
              backgroundColor: const Color(0xFFE53935),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
          // ── Profile ─────────────────────────────────────────────────
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: context.tr('profile'),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: leagueAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.redAccent,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  e.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        data: (league) => _MobileFrame(
          child: _LeagueBody(league: league, leagueId: leagueId),
        ),
      ),
    );
  }

  void _showNotificationsPanel(
    BuildContext context,
    WidgetRef ref,
    String leagueId,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _NotificationsSheet(leagueId: leagueId),
    );
  }
}

// ---------------------------------------------------------------------------
// Mobile frame — constrains content to a phone-like max width and centers it
// on wider screens (tablet / desktop / web).
// ---------------------------------------------------------------------------

class _MobileFrame extends StatelessWidget {
  final Widget child;
  const _MobileFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// League body — header + nav grid, fits without scrolling
// ---------------------------------------------------------------------------

class _LeagueBody extends ConsumerStatefulWidget {
  final LeagueModel? league;
  final String leagueId;

  const _LeagueBody({required this.league, required this.leagueId});

  @override
  ConsumerState<_LeagueBody> createState() => _LeagueBodyState();
}

class _LeagueBodyState extends ConsumerState<_LeagueBody> {
  @override
  void initState() {
    super.initState();
    // Invalidate on every visit so the HP reset check runs fresh
    // (handles the case where the user opens the app at the start of a new period).
    if (widget.league != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.invalidate(periodHpResetProvider(widget.leagueId));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final league = widget.league;
    final leagueId = widget.leagueId;

    // ── Trigger period HP reset for all members (no-op if already reset) ──
    if (league != null) {
      ref.watch(periodHpResetProvider(leagueId));
    }

    // Precompute attacks remaining
    int attacksLeft = kMaxDailyAttacks;
    if (currentUser != null) {
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final used = currentUser.lastAttackDate == todayStr
          ? currentUser.todayAttacks
          : 0;
      attacksLeft = (kMaxDailyAttacks - used).clamp(0, kMaxDailyAttacks);
    }

    // Shield info
    final shieldExpiry = currentUser?.shieldByLeague[leagueId];
    final hasShield =
        shieldExpiry != null &&
        DateTime.now().toUtc().isBefore(DateTime.parse(shieldExpiry));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Period results banner ───────────────────────────────────────
          if (league != null)
            _LeaguePeriodResultsBanner(
              leagueId: leagueId,
              leagueType: league.competitionType,
            ),

          // ── Navigation grid ─────────────────────────────────────────────
          _NavGrid(
            leagueId: leagueId,
            attacksLeft: attacksLeft,
            hasShield: hasShield,
          ),

          const SizedBox(height: 20),

          // ── My tasks preview ────────────────────────────────────────────
          _MyTasksPreview(leagueId: leagueId),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Nav grid — minimal 2×2 grid: Tasks, Arena, History, Stats
// ---------------------------------------------------------------------------

class _NavGrid extends StatelessWidget {
  final String leagueId;
  final int attacksLeft;
  final bool hasShield;

  const _NavGrid({
    required this.leagueId,
    required this.attacksLeft,
    required this.hasShield,
  });

  @override
  Widget build(BuildContext context) {
    final attackColor = attacksLeft > 2
        ? const Color(0xFF4CAF50)
        : attacksLeft > 0
        ? const Color(0xFFFFC107)
        : Colors.white24;

    return Column(
      children: [
        Row(
          children: [
            // Tasks
            Expanded(
              child: _NavTile(
                icon: Icons.check_circle_outline,
                label: context.tr('tasks'),
                onTap: () => context.push('/league/$leagueId/tasks'),
                badge: null,
              ),
            ),
            const SizedBox(width: 10),
            // Arena
            Expanded(
              child: _NavTile(
                icon: Icons.sports_kabaddi,
                label: 'Arena',
                onTap: () => context.push('/league/$leagueId/arena'),
                badge: _AttacksBadge(
                  count: attacksLeft,
                  color: attackColor,
                  hasShield: hasShield,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // Stats
            Expanded(
              child: _NavTile(
                icon: Icons.bar_chart_outlined,
                label: context.tr('statistics'),
                onTap: () => context.push('/league/$leagueId/stats'),
                badge: null,
              ),
            ),
            const SizedBox(width: 10),
            // History
            Expanded(
              child: _NavTile(
                icon: Icons.history,
                label: context.tr('history'),
                onTap: () => context.push('/league/$leagueId/history'),
                badge: null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? badge;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withAlpha(8),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withAlpha(18)),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white70, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (badge != null)
                badge!
              else
                Icon(
                  Icons.chevron_right,
                  color: Colors.white.withAlpha(50),
                  size: 16,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttacksBadge extends StatelessWidget {
  final int count;
  final Color color;
  final bool hasShield;

  const _AttacksBadge({
    required this.count,
    required this.color,
    required this.hasShield,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasShield) ...[
          const Text('🛡️', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
        ],
        Icon(Icons.bolt, color: color, size: 13),
        const SizedBox(width: 2),
        Text(
          '$count',
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Period results banner — shown in the League hub the first 3 days of a
// new period (Mon–Wed for weekly, 1st–3rd for monthly).
// ---------------------------------------------------------------------------

class _LeaguePeriodResultsBanner extends ConsumerStatefulWidget {
  final String leagueId;
  final CompetitionType leagueType;
  const _LeaguePeriodResultsBanner({
    required this.leagueId,
    required this.leagueType,
  });

  @override
  ConsumerState<_LeaguePeriodResultsBanner> createState() =>
      _LeaguePeriodResultsBannerState();
}

class _LeaguePeriodResultsBannerState
    extends ConsumerState<_LeaguePeriodResultsBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed || !isStartOfPeriod(widget.leagueType)) {
      return const SizedBox.shrink();
    }

    final currentUid = ref.watch(authStateProvider).valueOrNull?.uid;
    final prevAsync = ref.watch(
      previousPeriodRankingProvider((
        leagueId: widget.leagueId,
        type: widget.leagueType,
      )),
    );

    return prevAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (prev) {
        if (prev.isEmpty) return const SizedBox.shrink();
        final anyActivity = prev.any((e) => e.tasks > 0);
        if (!anyActivity) return const SizedBox.shrink();

        final label = widget.leagueType == CompetitionType.weekly
            ? context.tr('periodResultsLastWeek')
            : context.tr('periodResultsLastMonth');
        final winner = prev.first;
        final winnerIsYou = winner.member.id == currentUid;
        final winnerName = winner.member.name.isNotEmpty
            ? winner.member.name
            : winner.member.email;

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => context.push(
                '/league/${widget.leagueId}/arena?tab=ranking&period=last',
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFFFD700).withAlpha(28),
                      const Color(0xFF6C3CE1).withAlpha(20),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFFFD700).withAlpha(90),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                child: Row(
                  children: [
                    const Text('🏆', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Text('🥇', style: TextStyle(fontSize: 12)),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  winnerName,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: winnerIsYou
                                        ? const Color(0xFFFFD700)
                                        : Colors.white70,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: Colors.white38,
                      size: 22,
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white38,
                        size: 16,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      onPressed: () => setState(() => _dismissed = true),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// League info header card
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Notifications bottom sheet — "you were attacked" events
// ---------------------------------------------------------------------------

class _NotificationsSheet extends ConsumerWidget {
  final String leagueId;
  const _NotificationsSheet({required this.leagueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifAsync = ref.watch(attackNotificationsProvider(leagueId));
    final seenAt = ref.watch(notifSeenProvider(leagueId));

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          // ── Drag handle + title ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(
                      Icons.notifications_outlined,
                      color: Color(0xFFB39DDB),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    notifAsync.maybeWhen(
                      data: (events) => events.isNotEmpty
                          ? TextButton(
                              onPressed: () => ref
                                  .read(notifSeenProvider(leagueId).notifier)
                                  .markSeen(),
                              child: const Text(
                                'Mark all read',
                                style: TextStyle(
                                  color: Color(0xFFB39DDB),
                                  fontSize: 11,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(color: Colors.white12),
              ],
            ),
          ),

          // ── List ─────────────────────────────────────────────────
          Expanded(
            child: notifAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  'Error: $e',
                  style: const TextStyle(color: Colors.white54),
                ),
              ),
              data: (events) {
                if (events.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 48,
                          color: Colors.white24,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No attacks received yet',
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: events.length,
                  itemBuilder: (ctx, i) {
                    final e = events[i];
                    final isNew =
                        seenAt == null || e.completedAt.isAfter(seenAt);
                    final timeAgo = _timeAgo(e.completedAt);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isNew
                            ? const Color(0xFFE53935).withAlpha(18)
                            : Colors.white.withAlpha(7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isNew
                              ? const Color(0xFFE53935).withAlpha(80)
                              : Colors.white.withAlpha(10),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE53935).withAlpha(30),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Text('⚔️', style: TextStyle(fontSize: 18)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'You were attacked!',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isNew
                                        ? Colors.white
                                        : Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${e.taskTitle}  -${e.damageDealt} HP',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white54,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (isNew)
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(bottom: 4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE53935),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              Text(
                                timeAgo,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white38,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// My Tasks Preview — shown on the League hub
// Overdue → red, Today → amber, Upcoming → white. Max 5 rows + "See all" link.
// ─────────────────────────────────────────────────────────────────────────────

enum _TaskUrgency { overdue, today, upcoming }

_TaskUrgency _taskUrgency(TaskModel t) {
  final date = t.scheduledAt ?? t.dueDate;
  if (date == null) return _TaskUrgency.upcoming;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final taskDay = DateTime(date.year, date.month, date.day);
  if (taskDay.isBefore(today)) return _TaskUrgency.overdue;
  if (taskDay == today) return _TaskUrgency.today;
  return _TaskUrgency.upcoming;
}

String _taskDateLabel(TaskModel t, BuildContext context) {
  final date = t.scheduledAt ?? t.dueDate;
  if (date == null) return '';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final taskDay = DateTime(date.year, date.month, date.day);
  final diff = taskDay.difference(today).inDays;
  if (diff < 0)
    return context.trArgs('previewOverdueDays', {'days': '${-diff}'});
  if (diff == 0) return context.tr('previewToday');
  if (diff == 1) return context.tr('previewTomorrow');
  return context.trArgs('previewInDays', {'days': '$diff'});
}

class _MyTasksPreview extends ConsumerStatefulWidget {
  final String leagueId;
  const _MyTasksPreview({required this.leagueId});

  @override
  ConsumerState<_MyTasksPreview> createState() => _MyTasksPreviewState();
}

class _MyTasksPreviewState extends ConsumerState<_MyTasksPreview> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final upcomingAsync = ref.watch(myUpcomingTasksProvider(widget.leagueId));
    final recurringAsync = ref.watch(myRecurringTasksProvider(widget.leagueId));
    final leagueAsync = ref.watch(leagueProvider(widget.leagueId));
    final league = leagueAsync.valueOrNull;

    final all = [
      ...upcomingAsync.valueOrNull ?? [],
      ...recurringAsync.valueOrNull ?? [],
    ];
    all.sort((a, b) {
      final ua = _taskUrgency(a).index;
      final ub = _taskUrgency(b).index;
      if (ua != ub) return ua.compareTo(ub);
      final da = a.scheduledAt ?? a.dueDate;
      final db = b.scheduledAt ?? b.dueDate;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });

    final overdueCount = all
        .where((t) => _taskUrgency(t) == _TaskUrgency.overdue)
        .length;
    final todayCount = all
        .where((t) => _taskUrgency(t) == _TaskUrgency.today)
        .length;
    final preview = all.take(3).toList();

    if (all.isEmpty && !upcomingAsync.isLoading && !recurringAsync.isLoading) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header row — collapsible
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(
                    color: overdueCount > 0
                        ? const Color(0xFFE53935)
                        : todayCount > 0
                        ? const Color(0xFFFFC107)
                        : const Color(0xFF6C3CE1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  context.tr('upcomingTasks').toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(width: 8),
                if (overdueCount > 0)
                  _TaskBadge(
                    label: context.trArgs('previewOverdueCount', {
                      'count': '$overdueCount',
                    }),
                    color: const Color(0xFFE53935),
                  ),
                if (todayCount > 0) ...[
                  const SizedBox(width: 4),
                  _TaskBadge(
                    label: context.trArgs('previewTodayCount', {
                      'count': '$todayCount',
                    }),
                    color: const Color(0xFFFFC107),
                  ),
                ],
                const Spacer(),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.white24,
                  size: 18,
                ),
              ],
            ),
          ),
        ),

        if (_expanded) ...[
          const SizedBox(height: 6),
          if (upcomingAsync.isLoading || recurringAsync.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            ...preview.map(
              (task) => _TaskPreviewRow(
                task: task,
                leagueId: widget.leagueId,
                league: league,
                onCompleted: () {
                  ref.invalidate(myUpcomingTasksProvider(widget.leagueId));
                  ref.invalidate(myRecurringTasksProvider(widget.leagueId));
                },
              ),
            ),
          if (all.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: GestureDetector(
                onTap: () => context.push('/league/${widget.leagueId}/tasks'),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      all.length > 3
                          ? context.trArgs('seeAllTasks', {
                              'count': '${all.length}',
                            })
                          : context.tr('goToTasks'),
                      style: const TextStyle(
                        color: Color(0xFF9575CD),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: 4),
      ],
    );
  }
}

class _TaskPreviewRow extends ConsumerWidget {
  final TaskModel task;
  final String leagueId;
  final LeagueModel? league;
  final VoidCallback onCompleted;

  const _TaskPreviewRow({
    required this.task,
    required this.leagueId,
    required this.league,
    required this.onCompleted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urgency = _taskUrgency(task);
    final dateLabel = _taskDateLabel(task, context);
    final isRecurring = task.repeat != TaskRepeat.none;

    final Color urgencyColor;
    final Color bgColor;
    switch (urgency) {
      case _TaskUrgency.overdue:
        urgencyColor = const Color(0xFFE53935);
        bgColor = const Color(0xFFE53935);
      case _TaskUrgency.today:
        urgencyColor = const Color(0xFFFFC107);
        bgColor = const Color(0xFFFFC107);
      case _TaskUrgency.upcoming:
        urgencyColor = Colors.white38;
        bgColor = Colors.white;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
        decoration: BoxDecoration(
          color: bgColor.withAlpha(urgency == _TaskUrgency.upcoming ? 8 : 15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: bgColor.withAlpha(
              urgency == _TaskUrgency.upcoming ? 20 : 60,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 32,
              decoration: BoxDecoration(
                color: urgencyColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (dateLabel.isNotEmpty) ...[
                        Icon(
                          urgency == _TaskUrgency.overdue
                              ? Icons.warning_amber_rounded
                              : Icons.schedule,
                          size: 11,
                          color: urgencyColor,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          dateLabel,
                          style: TextStyle(
                            fontSize: 10,
                            color: urgencyColor,
                            fontWeight: urgency != _TaskUrgency.upcoming
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (isRecurring) ...[
                        const Icon(
                          Icons.repeat,
                          size: 11,
                          color: Colors.white24,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          context.tr(
                            'repeat${task.repeat.name[0].toUpperCase()}${task.repeat.name.substring(1)}',
                          ),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white24,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      const Icon(Icons.bolt, size: 11, color: Colors.white24),
                      Text(
                        '${task.effort}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white24,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _QuickCompleteButton(
              task: task,
              leagueId: leagueId,
              league: league,
              onCompleted: onCompleted,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickCompleteButton extends ConsumerStatefulWidget {
  final TaskModel task;
  final String leagueId;
  final LeagueModel? league;
  final VoidCallback onCompleted;

  const _QuickCompleteButton({
    required this.task,
    required this.leagueId,
    required this.league,
    required this.onCompleted,
  });

  @override
  ConsumerState<_QuickCompleteButton> createState() =>
      _QuickCompleteButtonState();
}

class _QuickCompleteButtonState extends ConsumerState<_QuickCompleteButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    if (widget.league == null) return const SizedBox.shrink();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: () async {
          final maxHp = maxHpForType(widget.league!.competitionType);
          // Open opponent picker → battle animation with this specific task
          await showArenaAttackDialogWithTask(
            context,
            ref,
            widget.task,
            widget.leagueId,
            maxHp,
          );
          widget.onCompleted();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 36,
          margin: const EdgeInsets.only(left: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32).withAlpha(_hovering ? 255 : 180),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFF4CAF50).withAlpha(_hovering ? 220 : 120),
            ),
            boxShadow: _hovering
                ? [
                    BoxShadow(
                      color: const Color(0xFF4CAF50).withAlpha(90),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check, color: Colors.white, size: 18),
              const SizedBox(width: 5),
              Text(
                context.tr('complete'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _TaskBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
