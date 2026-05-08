import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/task_model.dart';

class TaskRepository {
  final FirebaseFirestore _db;
  final _uuid = const Uuid();

  TaskRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _tasks(String leagueId) =>
      _db.collection('leagues').doc(leagueId).collection('tasks');

  Future<TaskModel> createTask(TaskModel task) async {
    final id = _uuid.v4();
    final withId = task.copyWith(id: id);
    await _tasks(task.leagueId).doc(id).set(withId.toFirestore());
    return withId;
  }

  Stream<List<TaskModel>> watchTasks(String leagueId) {
    return _tasks(leagueId).snapshots().map((snap) => snap.docs
        .map((d) => TaskModel.fromFirestore(d.data(), d.id))
        .toList());
  }

  Future<void> deleteTask(String leagueId, String taskId) async {
    await _tasks(leagueId).doc(taskId).delete();
  }

  Future<void> updateTask(TaskModel task) async {
    await _tasks(task.leagueId)
        .doc(task.id)
        .update(task.toFirestore());
  }

  /// Returns all tasks in a league assigned to [userId] (no googleEventId yet).
  Future<List<TaskModel>> getTasksForUser({
    required String leagueId,
    required String userId,
  }) async {
    final snap = await _tasks(leagueId)
        .where('assigneeId', isEqualTo: userId)
        .get();
    return snap.docs
        .map((d) => TaskModel.fromFirestore(d.data(), d.id))
        .toList();
  }
}
