import 'package:equatable/equatable.dart';

/// Represents a completed task event — used for history and HP damage.
class TaskEventModel extends Equatable {
  final String id;
  final String leagueId;
  final String taskId;
  final String taskTitle;
  final String doerId;       // who completed the task
  final String? targetId;    // who received the damage (optional)
  final int damageDealt;
  final int coinsEarned;     // coins awarded for this event (0 if daily cap reached)
  final DateTime completedAt;

  const TaskEventModel({
    required this.id,
    required this.leagueId,
    required this.taskId,
    required this.taskTitle,
    required this.doerId,
    this.targetId,
    required this.damageDealt,
    required this.coinsEarned,
    required this.completedAt,
  });

  factory TaskEventModel.fromFirestore(Map<String, dynamic> data, String id) {
    return TaskEventModel(
      id: id,
      leagueId: data['leagueId'] ?? '',
      taskId: data['taskId'] ?? '',
      taskTitle: data['taskTitle'] ?? '',
      doerId: data['doerId'] ?? '',
      targetId: data['targetId'],
      damageDealt: data['damageDealt'] ?? 0,
      // Support old documents that still have xpEarned
      coinsEarned: data['coinsEarned'] ?? (data['xpEarned'] != null ? 1 : 0),
      completedAt: (data['completedAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'leagueId': leagueId,
        'taskId': taskId,
        'taskTitle': taskTitle,
        'doerId': doerId,
        'targetId': targetId,
        'damageDealt': damageDealt,
        'coinsEarned': coinsEarned,
        'completedAt': completedAt,
      };

  @override
  List<Object?> get props => [
        id, leagueId, taskId, taskTitle, doerId,
        targetId, damageDealt, coinsEarned, completedAt,
      ];
}
