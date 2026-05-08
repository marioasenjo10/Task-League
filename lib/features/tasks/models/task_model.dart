import 'package:equatable/equatable.dart';

enum TaskRepeat { none, daily, weekly, monthly }

class TaskModel extends Equatable {
  final String id;
  final String leagueId;
  final String creatorId;
  final String? assigneeId;          // null = unassigned (league task)
  final String title;
  final String description;
  final int effort;
  final TaskRepeat repeat;
  final DateTime? scheduledAt;       // scheduled date/time (recurring or one-time)
  final DateTime? dueDate;           // due date/time (recurring or one-time; mutually exclusive with scheduledAt)
  final int? reminderMinutesBefore;  // null = no reminder; default 30
  final bool addToCalendar;
  final String? googleEventId;
  final String? parentTaskId;        // set on subtasks spawned from a recurring template

  const TaskModel({
    required this.id,
    required this.leagueId,
    required this.creatorId,
    this.assigneeId,
    required this.title,
    this.description = '',
    required this.effort,
    this.repeat = TaskRepeat.none,
    this.scheduledAt,
    this.dueDate,
    this.reminderMinutesBefore,
    this.addToCalendar = false,
    this.googleEventId,
    this.parentTaskId,
  });

  factory TaskModel.fromFirestore(Map<String, dynamic> data, String id) {
    return TaskModel(
      id: id,
      leagueId: data['leagueId'] ?? '',
      creatorId: data['creatorId'] ?? '',
      assigneeId: data['assigneeId'] as String?,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      effort: data['effort'] ?? 1,
      repeat: TaskRepeat.values.firstWhere(
        (e) => e.name == data['repeat'],
        orElse: () => TaskRepeat.none,
      ),
      scheduledAt: (data['scheduledAt'] as dynamic)?.toDate(),
      dueDate: (data['dueDate'] as dynamic)?.toDate(),
      reminderMinutesBefore: data['reminderMinutesBefore'] as int?,
      addToCalendar: data['addToCalendar'] ?? false,
      googleEventId: data['googleEventId'],
      parentTaskId: data['parentTaskId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'leagueId': leagueId,
        'creatorId': creatorId,
        'assigneeId': assigneeId,
        'title': title,
        'description': description,
        'effort': effort,
        'repeat': repeat.name,
        'scheduledAt': scheduledAt,
        'dueDate': dueDate,
        'reminderMinutesBefore': reminderMinutesBefore,
        'addToCalendar': addToCalendar,
        'googleEventId': googleEventId,
        'parentTaskId': parentTaskId,
      };

  TaskModel copyWith({
    String? id,
    String? leagueId,
    String? creatorId,
    Object? assigneeId = _sentinel,
    String? title,
    String? description,
    int? effort,
    TaskRepeat? repeat,
    Object? scheduledAt = _sentinel,
    Object? dueDate = _sentinel,
    Object? reminderMinutesBefore = _sentinel,
    bool? addToCalendar,
    Object? googleEventId = _sentinel,
    Object? parentTaskId = _sentinel,
  }) {
    return TaskModel(
      id: id ?? this.id,
      leagueId: leagueId ?? this.leagueId,
      creatorId: creatorId ?? this.creatorId,
      assigneeId: assigneeId == _sentinel ? this.assigneeId : assigneeId as String?,
      title: title ?? this.title,
      description: description ?? this.description,
      effort: effort ?? this.effort,
      repeat: repeat ?? this.repeat,
      scheduledAt: scheduledAt == _sentinel ? this.scheduledAt : scheduledAt as DateTime?,
      dueDate: dueDate == _sentinel ? this.dueDate : dueDate as DateTime?,
      reminderMinutesBefore: reminderMinutesBefore == _sentinel
          ? this.reminderMinutesBefore
          : reminderMinutesBefore as int?,
      addToCalendar: addToCalendar ?? this.addToCalendar,
      googleEventId: googleEventId == _sentinel ? this.googleEventId : googleEventId as String?,
      parentTaskId: parentTaskId == _sentinel ? this.parentTaskId : parentTaskId as String?,
    );
  }

  @override
  List<Object?> get props => [
        id, leagueId, creatorId, assigneeId, title, description,
        effort, repeat, scheduledAt, dueDate, reminderMinutesBefore,
        addToCalendar, googleEventId, parentTaskId,
      ];
}

const _sentinel = Object();
