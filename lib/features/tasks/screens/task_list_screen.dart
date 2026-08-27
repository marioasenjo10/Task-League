import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/task_providers.dart';
import '../providers/task_service_provider.dart';
import '../models/task_model.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/models/user_model.dart';
import '../../league/providers/league_providers.dart';
import '../../league/models/league_model.dart';
import '../../league/screens/members_screen.dart' show leagueMembersProvider;
import '../../arena/screens/arena_screen.dart'
    show showArenaAttackDialogWithTask;
import '../../../core/l10n/app_localizations.dart';

// Shared reminder options (used in create + edit sheets) — keys are l10n keys
const _reminderOptions = <String, int?>{
  'reminderNone': null,
  'reminder15': 15,
  'reminder30': 30,
  'reminder60': 60,
  'reminder120': 120,
  'reminder1440': 1440,
  'reminder2880': 2880,
};

enum _DateMode { scheduled, due }

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Human-readable schedule label for a task card.
/// Recurring (scheduled) → "Every Tuesday · at 16:30"
/// Recurring (due)       → "Every Tuesday · due 16:30"
/// One-time              → "Due: 14 Apr 2026 – 16:30" or "Scheduled: 14 Apr 2026 – 16:30"
String _scheduleLine(TaskModel task, BuildContext context) {
  final date = task.scheduledAt ?? task.dueDate;
  if (date == null) return '';

  if (task.repeat != TaskRepeat.none) {
    final timeStr = DateFormat('HH:mm').format(date);
    final isDue = task.dueDate != null;
    final timeLabel = isDue
        ? '${context.tr('scheduleTimeDue')} $timeStr'
        : '${context.tr('scheduleTimeAt')} $timeStr';
    switch (task.repeat) {
      case TaskRepeat.daily:
        return '${context.tr('everyDay')} · $timeLabel';
      case TaskRepeat.weekly:
        final dayName = DateFormat(
          'EEEE',
          context.l10n.locale.languageCode,
        ).format(date);
        return '${context.tr('schedulePrefix')} $dayName · $timeLabel';
      case TaskRepeat.monthly:
        final dayNum = date.day; // e.g. 14
        return '${context.tr('everyMonth')} $dayNum · $timeLabel';
      case TaskRepeat.none:
        break;
    }
  }

  final fmt = DateFormat(
    'dd MMM yyyy – HH:mm',
    context.l10n.locale.languageCode,
  );
  final label = task.dueDate != null
      ? context.tr('scheduleLabelDue')
      : context.tr('scheduleLabelScheduled');
  return '$label: ${fmt.format(date)}';
}

/// Returns the next N occurrences for a recurring task, starting from its
/// actual stored occurrence date. Works for both scheduledAt and dueDate.
List<DateTime> _nextOccurrences(TaskModel task, {int count = 5}) {
  final base = task.scheduledAt ?? task.dueDate;
  if (base == null || task.repeat == TaskRepeat.none) return [];
  final results = <DateTime>[];
  // Start from the actual stored occurrence. The task service advances this
  // date every time the task is completed or skipped, so `base` already
  // represents the true next occurrence. We must NOT reset it to "today",
  // otherwise a task already done this period would keep showing up today.
  var candidate = base;
  // If the stored occurrence is overdue (in the past and never completed or
  // skipped), roll it forward so the calendar shows upcoming dates instead of
  // long-past ones.
  final startOfToday = _dateOnly(DateTime.now());
  while (candidate.isBefore(startOfToday)) {
    candidate = _advance(candidate, task.repeat);
  }
  for (var i = 0; i < count; i++) {
    results.add(candidate);
    candidate = _advance(candidate, task.repeat);
  }
  return results;
}

DateTime _advance(DateTime d, TaskRepeat repeat) {
  switch (repeat) {
    case TaskRepeat.daily:
      return d.add(const Duration(days: 1));
    case TaskRepeat.weekly:
      return d.add(const Duration(days: 7));
    case TaskRepeat.monthly:
      // Advance one month, clamping the day to the last valid day of the
      // target month so a task on the 29/30/31 doesn't overflow into the
      // following month (e.g. Jan 31 → Feb 28/29, not March 3).
      final targetYear = d.month == 12 ? d.year + 1 : d.year;
      final targetMonth = d.month == 12 ? 1 : d.month + 1;
      final lastDayOfTarget = DateTime(targetYear, targetMonth + 1, 0).day;
      final day = d.day < lastDayOfTarget ? d.day : lastDayOfTarget;
      return DateTime(targetYear, targetMonth, day, d.hour, d.minute);
    case TaskRepeat.none:
      return d;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main screen with two tabs
// ─────────────────────────────────────────────────────────────────────────────

class TaskListScreen extends ConsumerWidget {
  final String leagueId;
  const TaskListScreen({super.key, required this.leagueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr('tasks')),
          bottom: TabBar(
            tabs: [
              Tab(icon: const Icon(Icons.person), text: context.tr('myTasks')),
              Tab(
                icon: const Icon(Icons.list_alt),
                text: context.tr('leagueTasks'),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _MyTasksTab(leagueId: leagueId),
            _LeagueTasksTab(leagueId: leagueId),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.add),
          label: Text(context.tr('newTask')),
          onPressed: () => context.push('/league/$leagueId/tasks/create'),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1 — League Tasks (unassigned + optionally assigned to others)
// ─────────────────────────────────────────────────────────────────────────────

class _LeagueTasksTab extends ConsumerStatefulWidget {
  final String leagueId;
  const _LeagueTasksTab({required this.leagueId});

  @override
  ConsumerState<_LeagueTasksTab> createState() => _LeagueTasksTabState();
}

class _LeagueTasksTabState extends ConsumerState<_LeagueTasksTab> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(leagueTaskFilterProvider(widget.leagueId));
    final tasksAsync = ref.watch(filteredLeagueTasksProvider(widget.leagueId));
    final membersAsync = ref.watch(leagueMembersProvider(widget.leagueId));
    final members = membersAsync.valueOrNull ?? [];

    return Column(
      children: [
        // ── Filter bar ────────────────────────────────────────────────────
        _LeagueFilterBar(
          leagueId: widget.leagueId,
          filter: filter,
          members: members,
          searchCtrl: _searchCtrl,
        ),
        // ── Task list ─────────────────────────────────────────────────────
        Expanded(
          child: tasksAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (tasks) => tasks.isEmpty
                ? _EmptyState(
                    icon: Icons.list_alt,
                    message: filter.isActive
                        ? context.tr('noTasksMatch')
                        : context.tr('noUnassignedTasks'),
                    sub: filter.isActive
                        ? context.tr('noTasksMatchSub')
                        : context.tr('noUnassignedTasksSub'),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: tasks.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _LeagueTaskCard(
                      task: tasks[index],
                      leagueId: widget.leagueId,
                      members: members,
                      onEdit: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        backgroundColor: const Color(0xFF1A1A2E),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        builder: (ctx) => _EditTaskSheet(
                          task: tasks[index],
                          leagueId: widget.leagueId,
                        ),
                      ),
                      onDelete: () =>
                          _confirmDelete(context, ref, tasks[index]),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    TaskModel task,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('deleteTask')),
        content: Text(
          context.trArgs('deleteTaskConfirm', {'title': task.title}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: Text(context.tr('delete')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(taskServiceProvider).deleteTask(task);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.trArgs('taskDeleted', {'title': task.title})),
          ),
        );
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter bar widget
// ─────────────────────────────────────────────────────────────────────────────

class _LeagueFilterBar extends ConsumerWidget {
  final String leagueId;
  final LeagueTaskFilter filter;
  final List<UserModel> members;
  final TextEditingController searchCtrl;

  const _LeagueFilterBar({
    required this.leagueId,
    required this.filter,
    required this.members,
    required this.searchCtrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(leagueTaskFilterProvider(leagueId).notifier);

    return Container(
      color: const Color(0xFF12122A),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search field
          TextField(
            controller: searchCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: context.tr('searchTasks'),
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
              prefixIcon: const Icon(
                Icons.search,
                size: 18,
                color: Colors.white38,
              ),
              suffixIcon: filter.searchText.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.clear,
                        size: 16,
                        color: Colors.white38,
                      ),
                      onPressed: () {
                        searchCtrl.clear();
                        notifier.setSearch('');
                      },
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF6C3CE1)),
              ),
            ),
            onChanged: notifier.setSearch,
          ),
          const SizedBox(height: 8),
          // Toggle row + assignee chip
          Row(
            children: [
              // Show assigned toggle
              GestureDetector(
                onTap: () => notifier.setShowAssigned(!filter.showAssigned),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: filter.showAssigned
                        ? const Color(0xFF6C3CE1).withAlpha(50)
                        : Colors.white.withAlpha(10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: filter.showAssigned
                          ? const Color(0xFF6C3CE1)
                          : Colors.white24,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        filter.showAssigned
                            ? Icons.group
                            : Icons.group_outlined,
                        size: 14,
                        color: filter.showAssigned
                            ? const Color(0xFFB39DDB)
                            : Colors.white54,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        context.tr('showAssigned'),
                        style: TextStyle(
                          fontSize: 12,
                          color: filter.showAssigned
                              ? const Color(0xFFB39DDB)
                              : Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Assignee filter — only when showAssigned is on
              if (filter.showAssigned && members.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _AssigneeFilterChip(
                    members: members,
                    selectedId: filter.assigneeId,
                    onSelected: notifier.setAssignee,
                  ),
                ),
              ],
              // Reset button — only when any filter active
              if (filter.isActive) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: context.tr('clearFilters'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  icon: const Icon(
                    Icons.filter_alt_off_outlined,
                    size: 18,
                    color: Colors.white38,
                  ),
                  onPressed: () {
                    searchCtrl.clear();
                    notifier.reset();
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// Assignee dropdown chip
class _AssigneeFilterChip extends StatelessWidget {
  final List<UserModel> members;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  const _AssigneeFilterChip({
    required this.members,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final selected = selectedId != null
        ? members.firstWhere(
            (m) => m.id == selectedId,
            orElse: () => members.first,
          )
        : null;

    return GestureDetector(
      onTap: () async {
        final result = await showMenu<String?>(
          context: context,
          color: const Color(0xFF1A1A2E),
          position: RelativeRect.fromLTRB(
            MediaQuery.of(context).size.width * 0.4,
            120,
            16,
            0,
          ),
          items: [
            PopupMenuItem<String?>(
              value: null,
              child: Text(
                context.tr('allMembers'),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
            ...members.map(
              (m) => PopupMenuItem<String?>(
                value: m.id,
                child: Text(
                  m.name,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
          ],
        );
        if (result != null || selectedId != null) {
          onSelected(result);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected != null
              ? const Color(0xFF6C3CE1).withAlpha(50)
              : Colors.white.withAlpha(10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected != null ? const Color(0xFF6C3CE1) : Colors.white24,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_outline, size: 14, color: Colors.white54),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                selected?.name ?? context.tr('anyAssignee'),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: selected != null
                      ? const Color(0xFFB39DDB)
                      : Colors.white54,
                ),
              ),
            ),
            const SizedBox(width: 3),
            const Icon(Icons.arrow_drop_down, size: 14, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2 — My Tasks: Upcoming (one-time) + Recurring sections
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2 — My Tasks: Upcoming (one-time) + Recurring sections
// ─────────────────────────────────────────────────────────────────────────────

class _MyTasksTab extends ConsumerStatefulWidget {
  final String leagueId;
  const _MyTasksTab({required this.leagueId});

  @override
  ConsumerState<_MyTasksTab> createState() => _MyTasksTabState();
}

enum _ViewMode { list, calendar }

class _MyTasksTabState extends ConsumerState<_MyTasksTab> {
  _ViewMode _viewMode = _ViewMode.calendar;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.week;

  @override
  Widget build(BuildContext context) {
    final upcomingAsync = ref.watch(myUpcomingTasksProvider(widget.leagueId));
    final recurringAsync = ref.watch(myRecurringTasksProvider(widget.leagueId));
    final currentUser = ref.watch(currentUserProvider).valueOrNull;

    final upcoming = upcomingAsync.valueOrNull ?? [];
    final recurring = recurringAsync.valueOrNull ?? [];
    final isLoading = upcomingAsync.isLoading || recurringAsync.isLoading;

    if (isLoading) return const Center(child: CircularProgressIndicator());

    if (upcoming.isEmpty && recurring.isEmpty) {
      return _EmptyState(
        icon: Icons.person_outline,
        message: context.tr('noTasksAssigned'),
        sub: context.tr('noTasksAssignedSub'),
      );
    }

    return Column(
      children: [
        // ── View toggle bar ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: currentUser != null
                    ? _TasksAttacksBanner(user: currentUser)
                    : const SizedBox.shrink(),
              ),
              const SizedBox(width: 8),
              _ViewToggleButton(
                viewMode: _viewMode,
                onToggle: () => setState(() {
                  _viewMode = _ViewMode
                      .values[(_viewMode.index + 1) % _ViewMode.values.length];
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // ── Content ─────────────────────────────────────────────────────
        Expanded(
          child: switch (_viewMode) {
            _ViewMode.list => _ListViewContent(
              leagueId: widget.leagueId,
              upcoming: upcoming,
              recurring: recurring,
            ),
            _ViewMode.calendar => _CalendarView(
              leagueId: widget.leagueId,
              upcoming: upcoming,
              recurring: recurring,
              focusedDay: _focusedDay,
              selectedDay: _selectedDay,
              calendarFormat: _calendarFormat,
              onDaySelected: (selected, focused) => setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              }),
              onFormatChanged: (format) =>
                  setState(() => _calendarFormat = format),
            ),
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers used by _MyTasksTab widgets
// ─────────────────────────────────────────────────────────────────────────────

Future<bool> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  TaskModel task,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(context.tr('deleteTask')),
      content: Text(context.trArgs('deleteTaskConfirm', {'title': task.title})),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(context.tr('cancel')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
          child: Text(context.tr('delete')),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await ref.read(taskServiceProvider).deleteTask(task);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.trArgs('taskDeleted', {'title': task.title})),
        ),
      );
    }
    return true;
  }
  return false;
}

Future<void> _showAttackDialog(
  BuildContext context,
  WidgetRef ref,
  TaskModel task,
  String leagueId,
) async {
  final league = ref.read(leagueProvider(leagueId)).valueOrNull;
  if (league == null) return;
  final maxHp = maxHpForType(league.competitionType);
  // Unified complete/attack flow — shared with the League hub & Arena.
  await showArenaAttackDialogWithTask(context, ref, task, leagueId, maxHp);
}

Future<void> _showEditSheet(
  BuildContext context,
  WidgetRef ref,
  TaskModel task,
  String leagueId,
) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: const Color(0xFF1A1A2E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _EditTaskSheet(task: task, leagueId: leagueId),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// View Toggle Button
// ─────────────────────────────────────────────────────────────────────────────

class _ViewToggleButton extends StatelessWidget {
  final _ViewMode viewMode;
  final VoidCallback onToggle;
  const _ViewToggleButton({required this.viewMode, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (viewMode) {
      _ViewMode.list => (Icons.calendar_month, context.tr('viewCalendar')),
      _ViewMode.calendar => (Icons.view_list, context.tr('viewList')),
    };
    return Tooltip(
      message: context.tr('switchView'),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: viewMode != _ViewMode.list
                ? const Color(0xFF6C3CE1).withAlpha(60)
                : Colors.white.withAlpha(15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: viewMode != _ViewMode.list
                  ? const Color(0xFF9575CD)
                  : Colors.white24,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: viewMode != _ViewMode.list
                    ? const Color(0xFFB39DDB)
                    : Colors.white54,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: viewMode != _ViewMode.list
                      ? const Color(0xFFB39DDB)
                      : Colors.white54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// List View Content (extracted from original _MyTasksTab)
// ─────────────────────────────────────────────────────────────────────────────
class _ListViewContent extends ConsumerWidget {
  final String leagueId;
  final List<TaskModel> upcoming;
  final List<TaskModel> recurring;
  const _ListViewContent({
    required this.leagueId,
    required this.upcoming,
    required this.recurring,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      children: [
        // ── Upcoming section ──────────────────────────────────────────
        if (upcoming.isNotEmpty) ...[
          _SectionHeader(
            icon: Icons.calendar_today,
            label: context.tr('upcoming'),
            count: upcoming.length,
          ),
          const SizedBox(height: 8),
          ...upcoming.map(
            (task) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _MyTaskCard(
                task: task,
                leagueId: leagueId,
                isRecurring: false,
                onComplete: () =>
                    _showAttackDialog(context, ref, task, leagueId),
                onEdit: () => _showEditSheet(context, ref, task, leagueId),
              ),
            ),
          ),
        ],
        // ── Recurring section ─────────────────────────────────────────
        if (recurring.isNotEmpty) ...[
          if (upcoming.isNotEmpty) const SizedBox(height: 8),
          _SectionHeader(
            icon: Icons.repeat,
            label: context.tr('recurring'),
            count: recurring.length,
          ),
          const SizedBox(height: 8),
          ...recurring.map(
            (task) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _MyTaskCard(
                task: task,
                leagueId: leagueId,
                isRecurring: true,
                onComplete: () =>
                    _showAttackDialog(context, ref, task, leagueId),
                onEdit: () => _showEditSheet(context, ref, task, leagueId),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Calendar View
// ─────────────────────────────────────────────────────────────────────────────

/// Returns a normalized date (year/month/day only, time zeroed) for map keys.
DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

class _CalendarView extends ConsumerWidget {
  final String leagueId;
  final List<TaskModel> upcoming;
  final List<TaskModel> recurring;
  final DateTime focusedDay;
  final DateTime selectedDay;
  final CalendarFormat calendarFormat;
  final void Function(DateTime selected, DateTime focused) onDaySelected;
  final void Function(CalendarFormat format) onFormatChanged;

  const _CalendarView({
    required this.leagueId,
    required this.upcoming,
    required this.recurring,
    required this.focusedDay,
    required this.selectedDay,
    required this.calendarFormat,
    required this.onDaySelected,
    required this.onFormatChanged,
  });

  /// Build a map of date → tasks for all tasks (one-time + projected recurring).
  Map<DateTime, List<TaskModel>> _buildEventMap() {
    final map = <DateTime, List<TaskModel>>{};

    void add(DateTime day, TaskModel task) {
      final key = _dateOnly(day);
      (map[key] ??= []).add(task);
    }

    // One-time tasks
    for (final task in upcoming) {
      final date = task.scheduledAt ?? task.dueDate;
      if (date != null) add(date, task);
    }

    // Recurring: project next 60 days
    final now = DateTime.now();
    final horizon = now.add(const Duration(days: 60));
    for (final task in recurring) {
      final occurrences = _nextOccurrences(task, count: 12);
      for (final occ in occurrences) {
        if (occ.isBefore(horizon)) add(occ, task);
      }
    }
    return map;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventMap = _buildEventMap();
    final selectedKey = _dateOnly(selectedDay);
    final tasksForDay = eventMap[selectedKey] ?? [];

    return Column(
      children: [
        // ── Calendar ────────────────────────────────────────────────────
        TableCalendar<TaskModel>(
          locale: Localizations.localeOf(context).languageCode,
          firstDay: DateTime.now().subtract(const Duration(days: 365)),
          lastDay: DateTime.now().add(const Duration(days: 365)),
          focusedDay: focusedDay,
          selectedDayPredicate: (day) => isSameDay(day, selectedDay),
          onDaySelected: onDaySelected,
          eventLoader: (day) => eventMap[_dateOnly(day)] ?? [],
          calendarFormat: calendarFormat,
          onFormatChanged: onFormatChanged,
          availableCalendarFormats: {
            CalendarFormat.week: context.tr('calendarWeek'),
            CalendarFormat.month: context.tr('calendarMonth'),
          },
          startingDayOfWeek: StartingDayOfWeek.monday,
          headerStyle: HeaderStyle(
            titleCentered: true,
            formatButtonVisible: true,
            formatButtonDecoration: BoxDecoration(
              color: const Color(0xFF6C3CE1).withAlpha(60),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF9575CD).withAlpha(120)),
            ),
            formatButtonTextStyle: const TextStyle(
              color: Color(0xFFB39DDB),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
            titleTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            leftChevronIcon: const Icon(
              Icons.chevron_left,
              color: Colors.white70,
            ),
            rightChevronIcon: const Icon(
              Icons.chevron_right,
              color: Colors.white70,
            ),
            decoration: const BoxDecoration(color: Colors.transparent),
          ),
          calendarStyle: CalendarStyle(
            outsideDaysVisible: false,
            defaultTextStyle: const TextStyle(color: Colors.white70),
            weekendTextStyle: const TextStyle(color: Colors.white70),
            selectedDecoration: const BoxDecoration(
              color: Color(0xFF6C3CE1),
              shape: BoxShape.circle,
            ),
            todayDecoration: BoxDecoration(
              color: const Color(0xFF9575CD).withAlpha(100),
              shape: BoxShape.circle,
            ),
            todayTextStyle: const TextStyle(color: Colors.white),
            markerDecoration: const BoxDecoration(
              color: Color(0xFFFFD700),
              shape: BoxShape.circle,
            ),
            markerSize: 5,
            markersMaxCount: 3,
          ),
          daysOfWeekStyle: const DaysOfWeekStyle(
            weekdayStyle: TextStyle(color: Colors.white54, fontSize: 12),
            weekendStyle: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ),
        const Divider(color: Colors.white12, height: 1),
        // ── Tasks for selected day ───────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              const Icon(Icons.event_note, size: 14, color: Color(0xFF9575CD)),
              const SizedBox(width: 6),
              Text(
                DateFormat(
                  'EEE, dd MMM yyyy',
                  Localizations.localeOf(context).languageCode,
                ).format(selectedDay),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF9575CD),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 6),
              if (tasksForDay.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C3CE1).withAlpha(50),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${tasksForDay.length}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFFB39DDB),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: tasksForDay.isEmpty
              ? Center(
                  child: Text(
                    context.tr('noTasksForDay'),
                    style: const TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                  itemCount: tasksForDay.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final task = tasksForDay[index];
                    final isRecurring = task.repeat != TaskRepeat.none;
                    return _MyTaskCard(
                      task: task,
                      leagueId: leagueId,
                      isRecurring: isRecurring,
                      onComplete: () =>
                          _showAttackDialog(context, ref, task, leagueId),
                      onEdit: () =>
                          _showEditSheet(context, ref, task, leagueId),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// Section header widget
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF9575CD)),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: Color(0xFF9575CD),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: const Color(0xFF6C3CE1).withAlpha(50),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: const TextStyle(fontSize: 10, color: Color(0xFFB39DDB)),
          ),
        ),
        const Expanded(child: Divider(indent: 8, color: Colors.white12)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit task bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _EditTaskSheet extends ConsumerStatefulWidget {
  final TaskModel task;
  final String leagueId;
  const _EditTaskSheet({required this.task, required this.leagueId});

  @override
  ConsumerState<_EditTaskSheet> createState() => _EditTaskSheetState();
}

class _EditTaskSheetState extends ConsumerState<_EditTaskSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late int _effort;
  late TaskRepeat _repeat;
  late _DateMode _dateMode;
  late DateTime? _pickedDate;
  late int? _reminderMinutes;
  late String? _assigneeId;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.task.title);
    _descCtrl = TextEditingController(text: widget.task.description);
    _effort = widget.task.effort;
    _repeat = widget.task.repeat;
    _assigneeId = widget.task.assigneeId;
    // Determine date mode from existing data — works for all repeat modes
    final hasDueDate = widget.task.dueDate != null;
    _dateMode = hasDueDate ? _DateMode.due : _DateMode.scheduled;

    final storedDate = hasDueDate
        ? widget.task.dueDate
        : widget.task.scheduledAt;

    // For recurring tasks: if the stored date is in the past (already advanced
    // by a previous completion), show the next future occurrence instead so the
    // editor never shows a stale past date.
    if (widget.task.repeat != TaskRepeat.none &&
        storedDate != null &&
        storedDate.isBefore(DateTime.now())) {
      final next = _nextOccurrences(widget.task, count: 1);
      _pickedDate = next.isNotEmpty ? next.first : storedDate;
    } else {
      _pickedDate = storedDate;
    }

    _reminderMinutes = widget.task.reminderMinutesBefore;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Widget Function(BuildContext, Widget?) get _darkTheme =>
      (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF6C3CE1),
            onPrimary: Colors.white,
            surface: Color(0xFF1A1A2E),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      );

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _pickedDate ?? now.add(const Duration(days: 1)),
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 2)),
      builder: _darkTheme,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_pickedDate ?? now),
      builder: _darkTheme,
    );
    if (time == null || !mounted) return;
    setState(() {
      _pickedDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final updated = widget.task.copyWith(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        effort: _effort,
        repeat: _repeat,
        assigneeId: _assigneeId,
        // Store in the correct field based on chosen mode
        scheduledAt: _dateMode == _DateMode.scheduled ? _pickedDate : null,
        dueDate: _dateMode == _DateMode.due ? _pickedDate : null,
        reminderMinutesBefore: _reminderMinutes,
      );
      await ref.read(taskServiceProvider).updateTask(updated);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat(
      'dd MMM yyyy – HH:mm',
      context.l10n.locale.languageCode,
    );
    final currentUid = ref.watch(authStateProvider).valueOrNull?.uid;
    final membersAsync = ref.watch(leagueMembersProvider(widget.leagueId));
    final members = membersAsync.valueOrNull ?? [];

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              children: [
                const Icon(Icons.edit_outlined, color: Color(0xFFB39DDB)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr('editTask'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white38),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),

            // Title
            TextField(
              controller: _titleCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: context.tr('taskTitle'),
                prefixIcon: const Icon(Icons.task_alt),
              ),
            ),
            const SizedBox(height: 12),

            // Description
            TextField(
              controller: _descCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: context.tr('description'),
                prefixIcon: const Icon(Icons.notes),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Effort
            Text(
              '⚔️ ${context.tr('effortDamage')}: $_effort',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Slider(
              value: _effort.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              label: '$_effort',
              onChanged: (v) => setState(() => _effort = v.round()),
            ),
            const SizedBox(height: 4),

            // Repeat
            DropdownButtonFormField<TaskRepeat>(
              initialValue: _repeat,
              decoration: InputDecoration(labelText: context.tr('repeat')),
              items: TaskRepeat.values
                  .map(
                    (r) => DropdownMenuItem(
                      value: r,
                      child: Text(
                        context.tr(
                          'repeat${r.name[0].toUpperCase()}${r.name.substring(1)}',
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _repeat = v);
              },
            ),
            const SizedBox(height: 16),

            // Assignee
            if (members.isNotEmpty)
              DropdownButtonFormField<String?>(
                initialValue: _assigneeId,
                decoration: InputDecoration(
                  labelText: context.tr('assignedToLabel'),
                  prefixIcon: const Icon(Icons.person_pin),
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(context.tr('noAssignee')),
                  ),
                  ...members.map(
                    (m) => DropdownMenuItem<String?>(
                      value: m.id,
                      child: Text(
                        m.id == currentUid ? '${m.name} (me)' : m.name,
                      ),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _assigneeId = v),
              ),
            const SizedBox(height: 16),

            // Date mode toggle
            SegmentedButton<_DateMode>(
              segments: [
                ButtonSegment(
                  value: _DateMode.scheduled,
                  label: Text(context.tr('scheduled')),
                  icon: const Icon(Icons.schedule, size: 16),
                ),
                ButtonSegment(
                  value: _DateMode.due,
                  label: Text(context.tr('dueDate')),
                  icon: const Icon(Icons.event, size: 16),
                ),
              ],
              selected: {_dateMode},
              onSelectionChanged: (s) => setState(() {
                _dateMode = s.first;
                // Keep the picked date — just changing the label.
              }),
            ),
            const SizedBox(height: 12),

            // Date picker
            InkWell(
              onTap: _pickDateTime,
              borderRadius: BorderRadius.circular(10),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: _dateMode == _DateMode.scheduled
                      ? context.tr('scheduledDateTime')
                      : context.tr('dueDateDateTime'),
                  prefixIcon: Icon(
                    _dateMode == _DateMode.scheduled
                        ? Icons.schedule
                        : Icons.event,
                  ),
                  suffixIcon: _pickedDate != null
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setState(() => _pickedDate = null),
                        )
                      : const Icon(Icons.chevron_right),
                  border: const OutlineInputBorder(),
                ),
                child: Text(
                  _pickedDate != null
                      ? fmt.format(_pickedDate!)
                      : context.tr('tapToSelect'),
                  style: TextStyle(
                    color: _pickedDate != null ? Colors.white : Colors.white38,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Reminder
            DropdownButtonFormField<int?>(
              initialValue: _reminderMinutes,
              decoration: InputDecoration(
                labelText: context.tr('reminder'),
                prefixIcon: const Icon(Icons.notifications_outlined),
              ),
              items: _reminderOptions.entries
                  .map(
                    (e) => DropdownMenuItem<int?>(
                      value: e.value,
                      child: Text(context.tr(e.key)),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _reminderMinutes = v),
            ),
            const SizedBox(height: 24),

            // Save button
            ElevatedButton.icon(
              icon: const Icon(Icons.save_outlined),
              label: Text(context.tr('saveChanges')),
              onPressed: _loading ? null : _save,
            ),
            const SizedBox(height: 10),

            // Delete task
            OutlinedButton.icon(
              icon: const Icon(Icons.delete_outline, size: 18),
              label: Text(context.tr('deleteTask')),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: BorderSide(color: Colors.redAccent.withAlpha(120)),
              ),
              onPressed: _loading
                  ? null
                  : () async {
                      final deleted = await _confirmDelete(
                        context,
                        ref,
                        widget.task,
                      );
                      if (deleted && context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}

class _LeagueTaskCard extends ConsumerWidget {
  final TaskModel task;
  final String leagueId;
  final List<UserModel> members;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _LeagueTaskCard({
    required this.task,
    required this.leagueId,
    required this.members,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUid = ref.watch(authStateProvider).valueOrNull?.uid;
    final scheduleText = _scheduleLine(task, context);
    final isRecurring = task.repeat != TaskRepeat.none;
    final isAssigned = task.assigneeId != null;
    final assigneeName = isAssigned
        ? (members.where((m) => m.id == task.assigneeId).firstOrNull?.name ??
              task.assigneeId!)
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: isAssigned
                      ? const Color(0xFF6C3CE1).withAlpha(30)
                      : const Color(0xFFE53935).withAlpha(30),
                  child: Text(
                    '⚔️${task.effort}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '⚔️ ${task.effort} ${context.tr('statsDmg')}  •  ${isRecurring ? task.repeat.name[0].toUpperCase() + task.repeat.name.substring(1) : context.tr('oneTime')}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: Color(0xFFB39DDB),
                  ),
                  tooltip: 'Edit task',
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white38),
                  onPressed: onDelete,
                ),
              ],
            ),
            // Assignee badge (when task is assigned to someone else)
            if (isAssigned) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.person, size: 13, color: Color(0xFF9575CD)),
                  const SizedBox(width: 4),
                  Text(
                    '${context.tr('assignedTo')} $assigneeName',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9575CD),
                    ),
                  ),
                ],
              ),
            ],
            // Schedule / due line
            if (scheduleText.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    isRecurring ? Icons.repeat : Icons.event,
                    size: 14,
                    color: const Color(0xFF6C3CE1),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    scheduleText,
                    style: const TextStyle(fontSize: 11, color: Colors.white54),
                  ),
                ],
              ),
            ],
            if (task.reminderMinutesBefore != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    const Icon(
                      Icons.notifications_outlined,
                      size: 13,
                      color: Colors.white38,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _reminderLabel(task.reminderMinutesBefore!, context),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
            // Only show "Assign to me" when unassigned
            if (!isAssigned) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.person_add_alt_1, size: 16),
                  label: Text(
                    isRecurring
                        ? '${context.tr('assignToMeA')} ${context.tr('repeat${task.repeat.name[0].toUpperCase()}${task.repeat.name.substring(1)}')}'
                        : context.tr('assignToMe'),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF6C3CE1)),
                    foregroundColor: const Color(0xFFB39DDB),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                  ),
                  onPressed: currentUid == null
                      ? null
                      : () => isRecurring
                            ? _showOccurrencePicker(context, ref, currentUid)
                            : _assignDirectly(context, ref, currentUid),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Non-recurring: assign directly (existing behaviour)
  Future<void> _assignDirectly(
    BuildContext context,
    WidgetRef ref,
    String uid,
  ) async {
    await ref.read(taskServiceProvider).assignTask(task: task, assigneeId: uid);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.trArgs('taskMoved', {'title': task.title})),
        ),
      );
    }
  }

  // Recurring: show occurrence picker popup
  Future<void> _showOccurrencePicker(
    BuildContext context,
    WidgetRef ref,
    String uid,
  ) async {
    final occurrences = _nextOccurrences(task, count: 6);
    if (occurrences.isEmpty) return;

    final fmt = DateFormat(
      'EEE, dd MMM yyyy · HH:mm',
      context.l10n.locale.languageCode,
    );
    final isDue = task.dueDate != null;
    final occIcon = isDue ? Icons.event : Icons.calendar_today;
    final repeatLabel = context
        .tr(
          'repeat${task.repeat.name[0].toUpperCase()}${task.repeat.name.substring(1)}',
        )
        .toLowerCase();

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            Text(
              '📅 ${context.trArgs(isDue ? 'whichDueDate' : 'whichOccurrence', {'repeat': repeatLabel})}',
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              context.trArgs('oneTimeCopyOf', {'title': task.title}),
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ...occurrences.map(
              (occ) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  occIcon,
                  color: const Color(0xFF6C3CE1),
                  size: 20,
                ),
                title: Text(
                  fmt.format(occ),
                  style: const TextStyle(fontSize: 14),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Colors.white38,
                ),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await ref
                      .read(taskServiceProvider)
                      .assignOccurrence(
                        recurringTask: task,
                        assigneeId: uid,
                        occurrenceDate: occ,
                        isDue: isDue,
                      );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          context.trArgs('occurrenceAdded', {
                            'title': task.title,
                            'date': DateFormat(
                              'EEE dd MMM',
                              context.l10n.locale.languageCode,
                            ).format(occ),
                          }),
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// My task card — shows due date + Done button
// ─────────────────────────────────────────────────────────────────────────────

class _MyTaskCard extends ConsumerWidget {
  final TaskModel task;
  final String leagueId;
  final bool isRecurring;
  final VoidCallback onComplete;
  final VoidCallback onEdit;

  const _MyTaskCard({
    required this.task,
    required this.leagueId,
    required this.isRecurring,
    required this.onComplete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleText = _scheduleLine(task, context);
    final due = task.dueDate ?? task.scheduledAt;
    final isOverdue =
        !isRecurring && due != null && due.isBefore(DateTime.now());

    // For recurring: show the current occurrence date clearly, with due/scheduled label
    final isDue = isRecurring && task.dueDate != null;
    final occurrencePrefix = isDue
        ? context.tr('scheduleLabelDue')
        : context.tr('scheduleLabelScheduled');
    final occurrenceLabel = isRecurring && due != null
        ? '$occurrencePrefix: ${DateFormat('EEE dd MMM · HH:mm', context.l10n.locale.languageCode).format(due)}'
        : null;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isRecurring
              ? const Color(0xFF9575CD)
              : const Color(0xFF6C3CE1),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.title,
                style: Theme.of(context).textTheme.bodyLarge,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '⚔️ ${task.effort} ${context.tr('statsDmg')}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        // For recurring: next occurrence chip
                        if (occurrenceLabel != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.repeat,
                                size: 13,
                                color: Color(0xFF9575CD),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                scheduleText,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white54,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(
                                isDue ? Icons.event : Icons.calendar_today,
                                size: 11,
                                color: const Color(0xFF9575CD),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                occurrenceLabel,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFCE93D8),
                                ),
                              ),
                            ],
                          ),
                        ] else if (scheduleText.isNotEmpty) ...[
                          // One-time: normal due/scheduled line
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.event,
                                size: 14,
                                color: isOverdue
                                    ? Colors.redAccent
                                    : const Color(0xFF6C3CE1),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  scheduleText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isOverdue
                                        ? Colors.redAccent
                                        : Colors.white54,
                                    fontWeight: isOverdue
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                              if (isOverdue) ...[
                                const SizedBox(width: 4),
                                const Text(
                                  'OVERDUE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                        if (task.reminderMinutesBefore != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.notifications_outlined,
                                  size: 13,
                                  color: Colors.white38,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _reminderLabel(
                                    task.reminderMinutesBefore!,
                                    context,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white38,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Complete action — vertically centered against the details.
                  InkWell(
                    onTap: onComplete,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (isRecurring
                                    ? const Color(0xFF9575CD)
                                    : const Color(0xFF6C3CE1))
                                .withAlpha(40),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isRecurring
                              ? const Color(0xFF9575CD)
                              : const Color(0xFF6C3CE1),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check,
                            size: 15,
                            color: isRecurring
                                ? const Color(0xFFCE93D8)
                                : const Color(0xFFB39DDB),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            context.tr('done'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isRecurring
                                  ? const Color(0xFFCE93D8)
                                  : const Color(0xFFB39DDB),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _reminderLabel(int minutes, BuildContext context) {
  if (minutes < 60)
    return '${context.tr('reminder')}: $minutes ${context.tr('reminderMinUnit')}';
  if (minutes < 1440)
    return '${context.tr('reminder')}: ${minutes ~/ 60}${context.tr('reminderHourUnit')}';
  return '${context.tr('reminder')}: ${minutes ~/ 1440}${context.tr('reminderDayUnit')}';
}

// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// Attacks remaining chip — shown inline in the task list header
// ─────────────────────────────────────────────────────────────────────────────

class _TasksAttacksBanner extends StatelessWidget {
  final UserModel user;
  const _TasksAttacksBanner({required this.user});

  @override
  Widget build(BuildContext context) {
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final attacks = user.lastAttackDate == todayStr ? user.todayAttacks : 0;
    final remaining = (kMaxDailyAttacks - attacks).clamp(0, kMaxDailyAttacks);
    final color = remaining > 2
        ? const Color(0xFF4CAF50)
        : remaining > 0
        ? const Color(0xFFFFC107)
        : const Color(0xFFE53935);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        children: [
          Text(
            remaining == 0 ? '🚫' : '⚔️',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              remaining == 0
                  ? context.tr('attacksExhausted')
                  : context.trArgs('attacksLeft', {'n': '$remaining'}),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
          // Dot indicators
          Row(
            children: List.generate(
              kMaxDailyAttacks,
              (i) => Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < attacks ? color : Colors.white12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String sub;
  const _EmptyState({
    required this.icon,
    required this.message,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.white24),
          const SizedBox(height: 12),
          Text(message, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
