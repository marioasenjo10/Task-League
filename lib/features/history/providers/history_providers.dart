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

/// Stream the **entire** event history for a league — UNBOUNDED.
///
/// ⚠️ This performs one Firestore read per event in the league, so it must be
/// used sparingly. It is only consumed by the Statistics screen when the user
/// explicitly selects "All time". Every other feature (history feed,
/// notifications, arena ranking, scoped stats) uses a bounded query instead.
final leagueHistoryProvider =
    StreamProvider.autoDispose.family<List<TaskEventModel>, String>((ref, leagueId) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value([]);
  return ref.watch(taskEventRepositoryProvider).watchEvents(leagueId);
});

// ─────────────────────────────────────────────────────────────────────────────
// Filter state
// ─────────────────────────────────────────────────────────────────────────────

/// Hard ceiling for the History feed — the feed never fetches the whole
/// collection; unbounded reads are reserved for Stats → All time.
const int kMaxHistoryFetch = 200;

/// Look-back window (in days) for the "you were attacked" notifications feed.
const int kNotifWindowDays = 30;

/// Selectable page sizes for the History feed. No "unlimited" option here on
/// purpose — the full history is only reachable from Stats → All time.
const List<int?> kHistoryLimitOptions = [25, 50, 100, kMaxHistoryFetch];


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

/// Bounded stream of events for the History feed. Applies the date range
/// (when set) and a row limit **server-side** so the feed never reads the whole
/// collection. Member/text filtering is done client-side on this reduced set.
final historyEventsProvider =
    StreamProvider.autoDispose.family<List<TaskEventModel>, String>((ref, leagueId) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value([]);
  final filter = ref.watch(historyFilterProvider(leagueId));

  DateTime? start;
  DateTime? end;
  if (filter.dateFrom != null) {
    start = DateTime(
        filter.dateFrom!.year, filter.dateFrom!.month, filter.dateFrom!.day);
  }
  if (filter.dateTo != null) {
    end = DateTime(filter.dateTo!.year, filter.dateTo!.month,
        filter.dateTo!.day, 23, 59, 59);
  }

  final limit = (filter.limit ?? kMaxHistoryFetch).clamp(1, kMaxHistoryFetch);

  return ref.watch(taskEventRepositoryProvider).watchEvents(
        leagueId,
        start: start,
        end: end,
        limit: limit,
      );
});

/// Events already filtered client-side.
final filteredHistoryProvider =
    Provider.autoDispose.family<AsyncValue<List<TaskEventModel>>, String>((ref, leagueId) {
  final allAsync = ref.watch(historyEventsProvider(leagueId));
  final filter = ref.watch(historyFilterProvider(leagueId));

  return allAsync.whenData((events) {
    var list = events;

    if (filter.memberUid != null && filter.memberUid!.isNotEmpty) {
      list = list.where((e) => e.doerId == filter.memberUid).toList();
    }

    // Date range is already applied server-side; the search term is the only
    // remaining client-side filter.
    if (filter.searchText.isNotEmpty) {
      final q = filter.searchText.toLowerCase();
      list = list
          .where((e) => e.taskTitle.toLowerCase().contains(q))
          .toList();
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
///
/// Bounded to the last [kNotifWindowDays] days so it never reads the whole
/// collection — old attacks are not relevant as notifications.
final attackNotificationsProvider =
    StreamProvider.autoDispose.family<List<TaskEventModel>, String>((ref, leagueId) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value([]);
  final since = DateTime.now().subtract(const Duration(days: kNotifWindowDays));
  return ref
      .watch(taskEventRepositoryProvider)
      .watchEvents(leagueId, start: since, limit: kMaxHistoryFetch)
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
    Provider.autoDispose.family<AsyncValue<int>, String>((ref, leagueId) {
  final notifAsync = ref.watch(attackNotificationsProvider(leagueId));
  final seenAt = ref.watch(notifSeenProvider(leagueId));

  return notifAsync.whenData((events) {
    if (seenAt == null) return events.length;
    return events.where((e) => e.completedAt.isAfter(seenAt)).length;
  });
});
