import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/task_repository.dart';
import '../models/task_model.dart';
import '../../auth/providers/auth_providers.dart';

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => TaskRepository(),
);

/// All tasks for a given league, streamed in real-time.
final leagueTasksProvider =
    StreamProvider.autoDispose.family<List<TaskModel>, String>((ref, leagueId) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value([]);
  return ref.watch(taskRepositoryProvider).watchTasks(leagueId);
});

/// Unassigned league tasks — excludes occurrence subtasks (parentTaskId != null).
final unassignedTasksProvider =
    Provider.autoDispose.family<AsyncValue<List<TaskModel>>, String>((ref, leagueId) {
  return ref.watch(leagueTasksProvider(leagueId)).whenData(
        (tasks) => tasks
            .where((t) => t.assigneeId == null && t.parentTaskId == null)
            .toList(),
      );
});

/// Tasks assigned to the current user with repeat=none — fixed-date tasks
/// (one-time tasks and occurrence subtasks spawned from recurring templates).
/// Completed when done (deleted).
final myUpcomingTasksProvider =
    Provider.autoDispose.family<AsyncValue<List<TaskModel>>, String>((ref, leagueId) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  return ref.watch(leagueTasksProvider(leagueId)).whenData(
        (tasks) {
          final list = tasks
              .where((t) =>
                  t.assigneeId == uid &&
                  t.repeat == TaskRepeat.none)
              .toList();
          // Sort by effective date ascending
          list.sort((a, b) => _effectiveDate(a).compareTo(_effectiveDate(b)));
          return list;
        },
      );
});

/// Recurring tasks assigned to the current user (templates — date advances on complete).
final myRecurringTasksProvider =
    Provider.autoDispose.family<AsyncValue<List<TaskModel>>, String>((ref, leagueId) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  return ref.watch(leagueTasksProvider(leagueId)).whenData(
        (tasks) => tasks
            .where((t) =>
                t.assigneeId == uid &&
                t.repeat != TaskRepeat.none)
            .toList(),
      );
});

/// Combined: all tasks assigned to the current user (for backwards compat).
final myTasksProvider =
    Provider.autoDispose.family<AsyncValue<List<TaskModel>>, String>((ref, leagueId) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  return ref.watch(leagueTasksProvider(leagueId)).whenData(
        (tasks) => tasks
            .where((t) => t.assigneeId != null && t.assigneeId == uid)
            .toList(),
      );
});

// ─────────────────────────────────────────────────────────────────────────────
// League Tasks filter
// ─────────────────────────────────────────────────────────────────────────────

class LeagueTaskFilter {
  final String searchText;
  final bool showAssigned; // when false: only unassigned tasks
  final String? assigneeId; // null = all assignees (only active when showAssigned)

  const LeagueTaskFilter({
    this.searchText = '',
    this.showAssigned = false,
    this.assigneeId,
  });

  LeagueTaskFilter copyWith({
    String? searchText,
    bool? showAssigned,
    Object? assigneeId = _sentinel,
  }) {
    return LeagueTaskFilter(
      searchText: searchText ?? this.searchText,
      showAssigned: showAssigned ?? this.showAssigned,
      assigneeId:
          assigneeId == _sentinel ? this.assigneeId : assigneeId as String?,
    );
  }

  bool get isActive =>
      searchText.isNotEmpty || showAssigned || assigneeId != null;
}

const _sentinel = Object();

class LeagueTaskFilterNotifier extends StateNotifier<LeagueTaskFilter> {
  LeagueTaskFilterNotifier() : super(const LeagueTaskFilter());

  void setSearch(String text) => state = state.copyWith(searchText: text);
  void setShowAssigned(bool v) => state = state.copyWith(
        showAssigned: v,
        // Clear assignee filter when hiding assigned tasks
        assigneeId: v ? _sentinel : null,
      );
  void setAssignee(String? uid) => state = state.copyWith(assigneeId: uid);
  void reset() => state = const LeagueTaskFilter();
}

final leagueTaskFilterProvider = StateNotifierProvider.family<
    LeagueTaskFilterNotifier, LeagueTaskFilter, String>(
  (ref, leagueId) => LeagueTaskFilterNotifier(),
);

/// Effective date for sorting: earliest of scheduledAt / dueDate, or far future if unset.
DateTime _effectiveDate(TaskModel t) =>
    t.scheduledAt ?? t.dueDate ?? DateTime(9999);

/// Filtered + sorted league tasks.
/// - Excludes tasks assigned to the current user (those live in My Tasks).
/// - Excludes subtasks (parentTaskId != null).
/// - Unassigned always shown first, sorted by date asc.
/// - Assigned-to-others shown only when showAssigned = true.
final filteredLeagueTasksProvider =
    Provider.family<AsyncValue<List<TaskModel>>, String>((ref, leagueId) {
  final allAsync = ref.watch(leagueTasksProvider(leagueId));
  final filter = ref.watch(leagueTaskFilterProvider(leagueId));
  final currentUid = ref.watch(authStateProvider).valueOrNull?.uid;

  return allAsync.whenData((tasks) {
    // Exclude subtasks and tasks assigned to the current user
    var list = tasks
        .where((t) =>
            t.parentTaskId == null && t.assigneeId != currentUid)
        .toList();

    // Unassigned / assigned split
    if (!filter.showAssigned) {
      list = list.where((t) => t.assigneeId == null).toList();
    } else if (filter.assigneeId != null) {
      list = list
          .where((t) =>
              t.assigneeId == null || t.assigneeId == filter.assigneeId)
          .toList();
    }

    // Search by title
    if (filter.searchText.isNotEmpty) {
      final q = filter.searchText.toLowerCase();
      list = list.where((t) => t.title.toLowerCase().contains(q)).toList();
    }

    // Sort: unassigned first (by date asc), then assigned (by date asc)
    list.sort((a, b) {
      final aUnassigned = a.assigneeId == null;
      final bUnassigned = b.assigneeId == null;
      if (aUnassigned != bUnassigned) return aUnassigned ? -1 : 1;
      return _effectiveDate(a).compareTo(_effectiveDate(b));
    });

    return list;
  });
});
