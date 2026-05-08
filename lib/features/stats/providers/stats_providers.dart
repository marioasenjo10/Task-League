import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../history/providers/history_providers.dart';
import '../../history/models/task_event_model.dart';
import '../../league/screens/members_screen.dart' show leagueMembersProvider;
import '../../league/models/league_model.dart';
import '../../auth/models/user_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Date range helper
// ─────────────────────────────────────────────────────────────────────────────

class StatsDateRange {
  final DateTime start;
  final DateTime end;
  const StatsDateRange({required this.start, required this.end});
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter model
// ─────────────────────────────────────────────────────────────────────────────

/// Base filter.  [year]==null → all time.  Subclass [ThreeMonthFilter] for 3-month windows.
class StatsFilter {
  final int? year;
  final int? month;

  const StatsFilter({this.year, this.month});
  static const allTime = StatsFilter();

  bool get isAllTime => year == null;

  StatsDateRange get range {
    if (isAllTime) return StatsDateRange(start: DateTime(2000), end: DateTime.now());
    final y = year!;
    final m = month!;
    final start = DateTime(y, m, 1);
    final endRaw = DateTime(y, m + 1, 1).subtract(const Duration(milliseconds: 1));
    final end = endRaw.isAfter(DateTime.now()) ? DateTime.now() : endRaw;
    return StatsDateRange(start: start, end: end);
  }

  @override
  bool operator ==(Object other) =>
      other is StatsFilter && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);
}

/// 3-month window starting at [startYear]/[startMonth].
class ThreeMonthFilter extends StatsFilter {
  final int startYear;
  final int startMonth;

  const ThreeMonthFilter({required this.startYear, required this.startMonth})
      : super(year: startYear, month: startMonth);

  @override
  bool get isAllTime => false;

  @override
  StatsDateRange get range {
    final start = DateTime(startYear, startMonth, 1);
    final endRaw = DateTime(startYear, startMonth + 3, 1)
        .subtract(const Duration(milliseconds: 1));
    final end = endRaw.isAfter(DateTime.now()) ? DateTime.now() : endRaw;
    return StatsDateRange(start: start, end: end);
  }
}

/// Arbitrary date range chosen by the user.
class CustomRangeFilter extends StatsFilter {
  final DateTime rangeStart;
  final DateTime rangeEnd;

  CustomRangeFilter({required this.rangeStart, required this.rangeEnd})
      : super(year: rangeStart.year, month: rangeStart.month);

  @override
  bool get isAllTime => false;

  @override
  StatsDateRange get range => StatsDateRange(
        start: DateTime(rangeStart.year, rangeStart.month, rangeStart.day),
        end: DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day, 23, 59, 59),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter notifier
// ─────────────────────────────────────────────────────────────────────────────

class StatsFilterNotifier extends StateNotifier<StatsFilter> {
  StatsFilterNotifier()
      : super(StatsFilter(year: DateTime.now().year, month: DateTime.now().month));

  void setFilter(StatsFilter f) => state = f;

  void setThisMonth() {
    final now = DateTime.now();
    state = StatsFilter(year: now.year, month: now.month);
  }

  void setLastMonth() {
    final now = DateTime.now();
    final m = now.month == 1 ? 12 : now.month - 1;
    final y = now.month == 1 ? now.year - 1 : now.year;
    state = StatsFilter(year: y, month: m);
  }

  void setLast3Months() {
    final now = DateTime.now();
    var m = now.month - 2;
    var y = now.year;
    if (m <= 0) { m += 12; y -= 1; }
    state = ThreeMonthFilter(startYear: y, startMonth: m);
  }

  void setAllTime() => state = StatsFilter.allTime;

  void setCustomRange(DateTime from, DateTime to) =>
      state = CustomRangeFilter(rangeStart: from, rangeEnd: to);

  void previousMonth() {
    if (state.isAllTime) return;
    if (state is ThreeMonthFilter) {
      final s = state as ThreeMonthFilter;
      var m = s.startMonth - 1;
      var y = s.startYear;
      if (m <= 0) { m = 12; y -= 1; }
      state = ThreeMonthFilter(startYear: y, startMonth: m);
      return;
    }
    var m = state.month! - 1;
    var y = state.year!;
    if (m <= 0) { m = 12; y -= 1; }
    state = StatsFilter(year: y, month: m);
  }

  void nextMonth() {
    if (state.isAllTime) return;
    final now = DateTime.now();
    if (state is ThreeMonthFilter) {
      final s = state as ThreeMonthFilter;
      var m = s.startMonth + 1;
      var y = s.startYear;
      if (m > 12) { m = 1; y += 1; }
      if (DateTime(y, m).isAfter(now)) return;
      state = ThreeMonthFilter(startYear: y, startMonth: m);
      return;
    }
    var m = state.month! + 1;
    var y = state.year!;
    if (m > 12) { m = 1; y += 1; }
    if (DateTime(y, m).isAfter(now)) return;
    state = StatsFilter(year: y, month: m);
  }

  bool get canGoNext {
    if (state.isAllTime) return false;
    final now = DateTime.now();
    if (state is ThreeMonthFilter) {
      final s = state as ThreeMonthFilter;
      var m = s.startMonth + 1;
      var y = s.startYear;
      if (m > 12) { m = 1; y += 1; }
      return !DateTime(y, m).isAfter(now);
    }
    var m = state.month! + 1;
    var y = state.year!;
    if (m > 12) { m = 1; y += 1; }
    return !DateTime(y, m).isAfter(now);
  }
}

final statsFilterProvider =
    StateNotifierProvider.family<StatsFilterNotifier, StatsFilter, String>(
  (ref, leagueId) => StatsFilterNotifier(),
);

// ─────────────────────────────────────────────────────────────────────────────
// Computed stats models
// ─────────────────────────────────────────────────────────────────────────────

class MemberStats {
  final UserModel member;
  final int totalTasks;
  final int totalDamage;
  final int totalCoins;
  final Map<String, int> taskFrequency;

  const MemberStats({
    required this.member,
    required this.totalTasks,
    required this.totalDamage,
    required this.totalCoins,
    required this.taskFrequency,
  });
}

class LeagueStats {
  final List<MemberStats> memberStats;
  final Map<String, int> topTasks;
  final int totalEvents;
  final StatsFilter filter;

  const LeagueStats({
    required this.memberStats,
    required this.topTasks,
    required this.totalEvents,
    required this.filter,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Main stats provider
// ─────────────────────────────────────────────────────────────────────────────

final leagueStatsProvider =
    Provider.family<AsyncValue<LeagueStats>, String>((ref, leagueId) {
  final allAsync     = ref.watch(leagueHistoryProvider(leagueId));
  final membersAsync = ref.watch(leagueMembersProvider(leagueId));
  final filter       = ref.watch(statsFilterProvider(leagueId));

  if (allAsync.isLoading || membersAsync.isLoading) return const AsyncLoading();
  if (allAsync.hasError)     return AsyncError(allAsync.error!, allAsync.stackTrace!);
  if (membersAsync.hasError) return AsyncError(membersAsync.error!, membersAsync.stackTrace!);

  final events  = allAsync.valueOrNull ?? [];
  final members = membersAsync.valueOrNull ?? [];
  final range   = filter.range;

  final filtered = events.where((e) =>
      !e.completedAt.isBefore(range.start) &&
      !e.completedAt.isAfter(range.end)).toList();

  final Map<String, List<TaskEventModel>> byMember = {};
  for (final e in filtered) {
    byMember.putIfAbsent(e.doerId, () => []).add(e);
  }

  final Map<String, int> topTasks = {};
  for (final e in filtered) {
    topTasks[e.taskTitle] = (topTasks[e.taskTitle] ?? 0) + 1;
  }

  final memberStats = members.map((m) {
    final evts = byMember[m.id] ?? [];
    final freq = <String, int>{};
    for (final e in evts) {
      freq[e.taskTitle] = (freq[e.taskTitle] ?? 0) + 1;
    }
    return MemberStats(
      member: m,
      totalTasks:  evts.length,
      totalDamage: evts.fold(0, (s, e) => s + e.damageDealt),
      totalCoins:  evts.fold(0, (s, e) => s + e.coinsEarned),
      taskFrequency: freq,
    );
  }).toList()
    ..sort((a, b) => b.totalTasks.compareTo(a.totalTasks));

  return AsyncData(LeagueStats(
    memberStats: memberStats,
    topTasks: topTasks,
    totalEvents: filtered.length,
    filter: filter,
  ));
});

// ─────────────────────────────────────────────────────────────────────────────
// Period ranking — used by the Arena Ranking tab
// ─────────────────────────────────────────────────────────────────────────────

/// One entry in the current-period ranking.
class PeriodRankEntry {
  final UserModel member;
  final int tasks;       // tasks completed this period
  final int damage;      // total damage dealt this period
  final int coins;       // coins earned this period

  const PeriodRankEntry({
    required this.member,
    required this.tasks,
    required this.damage,
    required this.coins,
  });
}

/// Returns the date range for the current competition period.
/// Weekly → Monday 00:00 … now
/// Monthly → 1st of month 00:00 … now
StatsDateRange currentPeriodRange(CompetitionType type) {
  final now = DateTime.now();
  if (type == CompetitionType.weekly) {
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final start = DateTime(monday.year, monday.month, monday.day);
    return StatsDateRange(start: start, end: now);
  } else {
    final start = DateTime(now.year, now.month, 1);
    return StatsDateRange(start: start, end: now);
  }
}

/// Returns the date range for the **previous** competition period.
/// Weekly  → last Monday 00:00 … last Sunday 23:59:59
/// Monthly → 1st of previous month … last day 23:59:59
StatsDateRange previousPeriodRange(CompetitionType type) {
  final now = DateTime.now();
  if (type == CompetitionType.weekly) {
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final thisMonday = DateTime(monday.year, monday.month, monday.day);
    final lastMonday = thisMonday.subtract(const Duration(days: 7));
    final lastSunday = thisMonday.subtract(const Duration(milliseconds: 1));
    return StatsDateRange(start: lastMonday, end: lastSunday);
  } else {
    final firstOfThisMonth = DateTime(now.year, now.month, 1);
    final lastOfPrevMonth =
        firstOfThisMonth.subtract(const Duration(milliseconds: 1));
    final firstOfPrevMonth =
        DateTime(lastOfPrevMonth.year, lastOfPrevMonth.month, 1);
    return StatsDateRange(start: firstOfPrevMonth, end: lastOfPrevMonth);
  }
}

/// True during the first 3 days of a new period — when showing last period's
/// results is most relevant (Mon/Tue/Wed for weekly; 1st–3rd for monthly).
bool isStartOfPeriod(CompetitionType type) {
  final now = DateTime.now();
  return type == CompetitionType.weekly ? now.weekday <= 3 : now.day <= 3;
}

/// Provider family — key is leagueId.
/// Returns a ranked list of [PeriodRankEntry] sorted by tasks desc for the
/// current weekly/monthly competition period.
final periodRankingProvider = Provider.family<
    AsyncValue<List<PeriodRankEntry>>, ({String leagueId, CompetitionType type})>(
  (ref, args) {
    final eventsAsync = ref.watch(leagueHistoryProvider(args.leagueId));
    final membersAsync = ref.watch(leagueMembersProvider(args.leagueId));

    if (eventsAsync.isLoading || membersAsync.isLoading) {
      return const AsyncLoading();
    }
    if (eventsAsync.hasError) {
      return AsyncError(eventsAsync.error!, eventsAsync.stackTrace!);
    }
    if (membersAsync.hasError) {
      return AsyncError(membersAsync.error!, membersAsync.stackTrace!);
    }

    final events  = eventsAsync.valueOrNull ?? [];
    final members = membersAsync.valueOrNull ?? [];
    final range   = currentPeriodRange(args.type);

    final filtered = events.where((e) =>
        !e.completedAt.isBefore(range.start) &&
        !e.completedAt.isAfter(range.end)).toList();

    final Map<String, List<TaskEventModel>> byMember = {};
    for (final e in filtered) {
      byMember.putIfAbsent(e.doerId, () => []).add(e);
    }

    final ranked = members.map((m) {
      final evts = byMember[m.id] ?? [];
      return PeriodRankEntry(
        member: m,
        tasks:  evts.length,
        damage: evts.fold(0, (s, e) => s + e.damageDealt),
        coins:  evts.fold(0, (s, e) => s + e.coinsEarned),
      );
    }).toList()
      ..sort((a, b) {
        if (b.tasks != a.tasks) return b.tasks.compareTo(a.tasks);
        return b.damage.compareTo(a.damage); // tie-break by damage
      });

    return AsyncData(ranked);
  },
);

/// Provider family — same shape as [periodRankingProvider] but for the
/// **previous** period. Used to show last week/month's results banner.
final previousPeriodRankingProvider = Provider.family<
    AsyncValue<List<PeriodRankEntry>>, ({String leagueId, CompetitionType type})>(
  (ref, args) {
    final eventsAsync  = ref.watch(leagueHistoryProvider(args.leagueId));
    final membersAsync = ref.watch(leagueMembersProvider(args.leagueId));

    if (eventsAsync.isLoading || membersAsync.isLoading) return const AsyncLoading();
    if (eventsAsync.hasError) return AsyncError(eventsAsync.error!, eventsAsync.stackTrace!);
    if (membersAsync.hasError) return AsyncError(membersAsync.error!, membersAsync.stackTrace!);

    final events  = eventsAsync.valueOrNull ?? [];
    final members = membersAsync.valueOrNull ?? [];
    final range   = previousPeriodRange(args.type);

    final filtered = events.where((e) =>
        !e.completedAt.isBefore(range.start) &&
        !e.completedAt.isAfter(range.end)).toList();

    final Map<String, List<TaskEventModel>> byMember = {};
    for (final e in filtered) {
      byMember.putIfAbsent(e.doerId, () => []).add(e);
    }

    final ranked = members.map((m) {
      final evts = byMember[m.id] ?? [];
      return PeriodRankEntry(
        member: m,
        tasks:  evts.length,
        damage: evts.fold(0, (s, e) => s + e.damageDealt),
        coins:  evts.fold(0, (s, e) => s + e.coinsEarned),
      );
    }).toList()
      ..sort((a, b) {
        if (b.tasks != a.tasks) return b.tasks.compareTo(a.tasks);
        if (b.damage != a.damage) return b.damage.compareTo(a.damage);
        // Final tie-break: fewest coins lost (most resilient — proxy for HP)
        return a.coins.compareTo(b.coins);
      });

    return AsyncData(ranked);
  },
);
