import '../../auth/repositories/user_repository.dart';
import '../../auth/models/user_model.dart' show kDamagePerAttack;
import '../../tasks/models/task_model.dart';
import '../../tasks/repositories/task_repository.dart';
import '../../history/models/task_event_model.dart';
import '../../history/repositories/task_event_repository.dart';
import '../../league/models/league_model.dart';
import '../services/google_calendar_service.dart';

class TaskService {
  final UserRepository _userRepo;
  final TaskRepository _taskRepo;
  final TaskEventRepository _eventRepo;
  final GoogleCalendarService _calendarService;

  TaskService({
    UserRepository? userRepo,
    TaskRepository? taskRepo,
    TaskEventRepository? eventRepo,
    GoogleCalendarService? calendarService,
  })  : _userRepo = userRepo ?? UserRepository(),
        _taskRepo = taskRepo ?? TaskRepository(),
        _eventRepo = eventRepo ?? TaskEventRepository(),
        _calendarService = calendarService ?? GoogleCalendarService();

  /// Complete a task → coins + damage + history.
  /// - One-time tasks: deleted after completion.
  /// - Recurring tasks: scheduledAt/dueDate advanced to the next occurrence.
  ///
  /// **KO rule (Option B — Soft KO):**
  /// If the doer is currently KO'd (0 HP) in the league, they can still complete
  /// tasks for productivity tracking, but they earn 0 coins and deal 0 damage.
  Future<TaskEventModel> completeTask({
    required TaskModel task,
    required String doerId,
    String? targetId,
    CompetitionType leagueType = CompetitionType.weekly,
  }) async {
    // Check if doer is KO'd in this league
    final doer = await _userRepo.getUser(doerId);
    final maxHp = maxHpForType(leagueType);
    final isKO = doer != null && doer.currentHp(task.leagueId, maxHp: maxHp) <= 0;

    // 1. Award 1 coin to doer — skipped if KO'd
    final coinsEarned = isKO ? 0 : await _userRepo.addCoins(doerId);

    // 2. Damage to target — skipped if KO'd
    int damageDealt = 0;
    if (!isKO && targetId != null) {
      final applied = await _userRepo.applyDamage(
        attackerUid: doerId,
        targetUid: targetId,
        leagueId: task.leagueId,
        leagueType: leagueType,
      );
      if (applied) damageDealt = kDamagePerAttack;
    }

    // 3. Record history event
    final event = await _eventRepo.recordEvent(TaskEventModel(
      id: '',
      leagueId: task.leagueId,
      taskId: task.id,
      taskTitle: task.title,
      doerId: doerId,
      targetId: targetId,
      damageDealt: damageDealt,
      coinsEarned: coinsEarned,
      completedAt: DateTime.now(),
    ));

    // 4. Delete if one-time; advance date if recurring
    if (task.repeat == TaskRepeat.none) {
      await deleteTask(task);
    } else {
      final next = _nextOccurrenceDate(task);
      // Preserve whichever date field was set on the original task
      final advanced = task.scheduledAt != null
          ? task.copyWith(scheduledAt: next)
          : task.copyWith(dueDate: next);
      await _taskRepo.updateTask(advanced);
    }

    return event;
  }

  /// Advances a date by one repeat interval.
  static DateTime _advanceDate(DateTime d, TaskRepeat repeat) {
    switch (repeat) {
      case TaskRepeat.daily:
        return d.add(const Duration(days: 1));
      case TaskRepeat.weekly:
        return d.add(const Duration(days: 7));
      case TaskRepeat.monthly:
        return DateTime(d.year, d.month + 1, d.day, d.hour, d.minute);
      case TaskRepeat.none:
        return d;
    }
  }

  /// Returns the next occurrence datetime for a recurring task.
  static DateTime _nextOccurrenceDate(TaskModel task) {
    final base = task.scheduledAt ?? task.dueDate ?? DateTime.now();
    return _advanceDate(base, task.repeat);
  }

  /// Delete a task and remove its Google Calendar event if present.
  Future<void> deleteTask(TaskModel task) async {
    // Remove from Google Calendar if linked
    if (task.googleEventId != null) {
      _calendarService.deleteEvent(task.googleEventId!).catchError((_) {});
    }
    await _taskRepo.deleteTask(task.leagueId, task.id);
  }

  /// Update an existing task (title, effort, due date, reminder, etc.).
  Future<void> updateTask(TaskModel task) async {
    await _taskRepo.updateTask(task);
  }

  /// Create task and sync to Calendar only for the assignee (if set),
  /// or for the creator if they are also the assignee.
  /// The reminder is included in the Calendar event.
  Future<TaskModel> createTaskWithCalendarSync({
    required TaskModel task,
    required String creatorId,
  }) async {
    // First create the task to get its ID
    final created = await _taskRepo.createTask(task);

    // Determine who should receive the Calendar event:
    // - If there is an assignee, only that person gets it.
    // - If no assignee, only the creator (if they have calendarSync).
    final calendarUserId = task.assigneeId ?? creatorId;
    final effectiveDate = task.dueDate ?? task.scheduledAt;

    if (effectiveDate != null) {
      try {
        final user = await _userRepo.getUser(calendarUserId);
        if (user != null && user.calendarSync) {
          final eventId = await _calendarService.createEvent(
            title: task.title,
            description: task.description,
            startTime: effectiveDate,
            endTime: effectiveDate.add(const Duration(hours: 1)),
            reminderMinutesBefore: task.reminderMinutesBefore ?? 30,
          );
          if (eventId != null) {
            // Save the googleEventId back to the task
            final withEventId = created.copyWith(googleEventId: eventId);
            await _taskRepo.updateTask(withEventId);
            return withEventId;
          }
        }
      } catch (_) {}
    }

    return created;
  }

  /// Assign a specific occurrence of a recurring task to a user.
  /// Creates a one-time subtask with the given [occurrenceDate] and leaves
  /// the original recurring template untouched in League Tasks.
  /// [isDue] mirrors the date mode of the template: true → dueDate, false → scheduledAt.
  Future<TaskModel> assignOccurrence({
    required TaskModel recurringTask,
    required String assigneeId,
    required DateTime occurrenceDate,
    bool isDue = false,
  }) async {
    // Build a one-time subtask from the recurring template
    final subtask = TaskModel(
      id: '',
      leagueId: recurringTask.leagueId,
      creatorId: recurringTask.creatorId,
      assigneeId: assigneeId,
      title: recurringTask.title,
      description: recurringTask.description,
      effort: recurringTask.effort,
      repeat: TaskRepeat.none,         // fixed, one-time
      scheduledAt: isDue ? null : occurrenceDate,
      dueDate: isDue ? occurrenceDate : null,
      reminderMinutesBefore: recurringTask.reminderMinutesBefore,
      addToCalendar: recurringTask.addToCalendar,
      parentTaskId: recurringTask.id,  // link back to template
    );

    final created = await _taskRepo.createTask(subtask);

    // Try to add to assignee's calendar
    try {
      final user = await _userRepo.getUser(assigneeId);
      if (user != null && user.calendarSync) {
        final eventId = await _calendarService.createEvent(
          title: created.title,
          description: created.description,
          startTime: occurrenceDate,
          endTime: occurrenceDate.add(const Duration(hours: 1)),
          reminderMinutesBefore: created.reminderMinutesBefore ?? 30,
        );
        if (eventId != null) {
          final withEvent = created.copyWith(googleEventId: eventId);
          await _taskRepo.updateTask(withEvent);
          return withEvent;
        }
      }
    } catch (_) {}

    return created;
  }

  /// Assign a task to a user. If that user has calendarSync, creates a
  /// Calendar event for them (and removes any previous one).
  Future<TaskModel> assignTask({
    required TaskModel task,
    required String assigneeId,
  }) async {
    // Remove old calendar event if any
    if (task.googleEventId != null) {
      _calendarService.deleteEvent(task.googleEventId!).catchError((_) {});
    }

    final updated = task.copyWith(assigneeId: assigneeId, googleEventId: null);
    await _taskRepo.updateTask(updated);

    // Try to add to assignee's calendar
    final effectiveDate = updated.dueDate ?? updated.scheduledAt;
    if (effectiveDate != null) {
      try {
        final user = await _userRepo.getUser(assigneeId);
        if (user != null && user.calendarSync) {
          final eventId = await _calendarService.createEvent(
            title: updated.title,
            description: updated.description,
            startTime: effectiveDate,
            endTime: effectiveDate.add(const Duration(hours: 1)),
            reminderMinutesBefore: updated.reminderMinutesBefore ?? 30,
          );
          if (eventId != null) {
            final withEvent = updated.copyWith(googleEventId: eventId);
            await _taskRepo.updateTask(withEvent);
            return withEvent;
          }
        }
      } catch (_) {}
    }

    return updated;
  }

  /// Syncs ALL existing tasks assigned to [userId] to Google Calendar.
  /// Called when the user enables calendar sync for the first time,
  /// or when they re-enable it after a session loss.
  Future<int> syncExistingTasksToCalendar({
    required String userId,
    required List<String> leagueIds,
  }) async {
    int synced = 0;
    for (final leagueId in leagueIds) {
      try {
        final tasks = await _taskRepo.getTasksForUser(
          leagueId: leagueId,
          userId: userId,
        );
        for (final task in tasks) {
          // Skip if already linked or has no date
          if (task.googleEventId != null) continue;
          final effectiveDate = task.dueDate ?? task.scheduledAt;
          if (effectiveDate == null) continue;
          // Skip tasks from previous days (tasks due today are still valid)
          final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
          if (effectiveDate.isBefore(today)) continue;

          try {
            final eventId = await _calendarService.createEvent(
              title: task.title,
              description: task.description,
              startTime: effectiveDate,
              endTime: effectiveDate.add(const Duration(hours: 1)),
              reminderMinutesBefore: task.reminderMinutesBefore ?? 30,
            );
            if (eventId != null) {
              await _taskRepo.updateTask(
                task.copyWith(googleEventId: eventId),
              );
              synced++;
            }
          } catch (_) {}
        }
      } catch (_) {}
    }
    return synced;
  }
}
