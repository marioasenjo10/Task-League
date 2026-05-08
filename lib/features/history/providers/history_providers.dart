import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/task_event_repository.dart';
import '../models/task_event_model.dart';
import '../../auth/repositories/user_repository.dart';
import '../../auth/providers/auth_providers.dart';

final taskEventRepositoryProvider = Provider<TaskEventRepository>(
  (ref) => TaskEventRepository(),
);

final _userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(),
);

/// Resolves a display name for a given UID (cached via FutureProvider.family).
final userDisplayNameProvider =
    FutureProvider.family<String, String>((ref, uid) async {
  if (uid.isEmpty) return 'Unknown';
  try {
    final user = await ref.watch(_userRepositoryProvider).getUser(uid);
    return user?.name ?? uid;
  } catch (_) {
    return uid;
  }
});

/// Stream all events for a league (full history feed).
final leagueHistoryProvider =
    StreamProvider.family<List<TaskEventModel>, String>((ref, leagueId) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value([]);
  return ref.watch(taskEventRepositoryProvider).watchEvents(leagueId);
});

// ─────────────────────────────────────────────────────────────────────────────
// Filter state
// ─────────────────────────────────────────────────────────────────────────────

/// null limit = show all
const List<int?> kHistoryLimitOptions = [25, 50, 100, null];

class HistoryFilter {
  final String? memberUid;   // null = all members
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String searchText;
  final int? limit;          // null = no limit

  const HistoryFilter({
    this.memberUid,
    this.dateFrom,
    this.dateTo,
    this.searchText = '',
    this.limit = 25,
  });

  HistoryFilter copyWith({
    Object? memberUid = _sentinel,
    Object? dateFrom = _sentinel,
    Object? dateTo = _sentinel,
    Object? limit = _sentinel,
    String? searchText,
  }) {
    return HistoryFilter(
      memberUid: memberUid == _sentinel ? this.memberUid : memberUid as String?,
      dateFrom: dateFrom == _sentinel ? this.dateFrom : dateFrom as DateTime?,
      dateTo: dateTo == _sentinel ? this.dateTo : dateTo as DateTime?,
      searchText: searchText ?? this.searchText,
      limit: limit == _sentinel ? this.limit : limit as int?,
    );
  }

  bool get isActive =>
      memberUid != null ||
      dateFrom != null ||
      dateTo != null ||
      searchText.isNotEmpty;
}

const _sentinel = Object();

class HistoryFilterNotifier extends StateNotifier<HistoryFilter> {
  HistoryFilterNotifier() : super(const HistoryFilter());

  void setMember(String? uid) => state = state.copyWith(memberUid: uid);
  void setDateRange(DateTime? from, DateTime? to) =>
      state = state.copyWith(dateFrom: from, dateTo: to);
  void setSearch(String text) => state = state.copyWith(searchText: text);
  void setLimit(int? limit) => state = state.copyWith(limit: limit);
  void reset() => state = const HistoryFilter();
}

final historyFilterProvider =
    StateNotifierProvider.family<HistoryFilterNotifier, HistoryFilter, String>(
  (ref, leagueId) => HistoryFilterNotifier(),
);

/// Events already filtered client-side.
final filteredHistoryProvider =
    Provider.family<AsyncValue<List<TaskEventModel>>, String>((ref, leagueId) {
  final allAsync = ref.watch(leagueHistoryProvider(leagueId));
  final filter = ref.watch(historyFilterProvider(leagueId));

  return allAsync.whenData((events) {
    var list = events;

    if (filter.memberUid != null && filter.memberUid!.isNotEmpty) {
      list = list.where((e) => e.doerId == filter.memberUid).toList();
    }

    if (filter.dateFrom != null) {
      final from = DateTime(
          filter.dateFrom!.year, filter.dateFrom!.month, filter.dateFrom!.day);
      list = list.where((e) => !e.completedAt.isBefore(from)).toList();
    }

    if (filter.dateTo != null) {
      final to = DateTime(filter.dateTo!.year, filter.dateTo!.month,
          filter.dateTo!.day, 23, 59, 59);
      list = list.where((e) => !e.completedAt.isAfter(to)).toList();
    }

    if (filter.searchText.isNotEmpty) {
      final q = filter.searchText.toLowerCase();
      list = list
          .where((e) => e.taskTitle.toLowerCase().contains(q))
          .toList();
    }

    if (filter.limit != null && list.length > filter.limit!) {
      list = list.sublist(0, filter.limit);
    }

    return list;
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// Attack notifications — "you were attacked" events seen / unseen
// ─────────────────────────────────────────────────────────────────────────────

/// Provider: stream of attack events where the current user is the target.
/// Returns all events where targetId == currentUid and damageDealt > 0,
/// sorted by most recent first (same ordering as the history stream).
final attackNotificationsProvider =
    StreamProvider.family<List<TaskEventModel>, String>((ref, leagueId) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value([]);
  return ref
      .watch(taskEventRepositoryProvider)
      .watchEvents(leagueId)
      .map((events) => events
          .where((e) => e.targetId == uid && e.damageDealt > 0)
          .toList());
});

/// Tracks the timestamp of the last time the user "dismissed" notifications
/// for a given league. Events after this timestamp are "unseen".
class _NotifSeenNotifier extends StateNotifier<DateTime?> {
  _NotifSeenNotifier() : super(null);

  /// Call this when the user opens the notification panel.
  void markSeen() => state = DateTime.now();
}

final notifSeenProvider =
    StateNotifierProvider.family<_NotifSeenNotifier, DateTime?, String>(
  (ref, leagueId) => _NotifSeenNotifier(),
);

/// Count of unseen attack events for the current user in this league.
final unseenAttackCountProvider =
    Provider.family<AsyncValue<int>, String>((ref, leagueId) {
  final notifAsync = ref.watch(attackNotificationsProvider(leagueId));
  final seenAt = ref.watch(notifSeenProvider(leagueId));

  return notifAsync.whenData((events) {
    if (seenAt == null) return events.length;
    return events.where((e) => e.completedAt.isAfter(seenAt)).length;
  });
});
