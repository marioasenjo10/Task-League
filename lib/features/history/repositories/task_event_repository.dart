import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/task_event_model.dart';

class TaskEventRepository {
  final FirebaseFirestore _db;
  final _uuid = const Uuid();

  TaskEventRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _events(String leagueId) =>
      _db.collection('leagues').doc(leagueId).collection('events');

  Future<TaskEventModel> recordEvent(TaskEventModel event) async {
    final id = _uuid.v4();
    final withId = TaskEventModel(
      id: id,
      leagueId: event.leagueId,
      taskId: event.taskId,
      taskTitle: event.taskTitle,
      doerId: event.doerId,
      targetId: event.targetId,
      damageDealt: event.damageDealt,
      coinsEarned: event.coinsEarned,
      completedAt: event.completedAt,
    );
    await _events(event.leagueId).doc(id).set(withId.toFirestore());
    return withId;
  }

  /// Stream events for a league, ordered by most recent.
  ///
  /// All parameters are optional and applied **server-side** to keep Firestore
  /// read costs low:
  ///  - [start] / [end]  → only events whose `completedAt` falls in the range.
  ///  - [limit]          → cap the number of documents returned.
  ///
  /// Passing no arguments streams the **entire** history (used only by the
  /// Statistics screen when "All time" is selected).
  Stream<List<TaskEventModel>> watchEvents(
    String leagueId, {
    DateTime? start,
    DateTime? end,
    int? limit,
  }) {
    Query<Map<String, dynamic>> q =
        _events(leagueId).orderBy('completedAt', descending: true);
    if (start != null) {
      q = q.where('completedAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(start));
    }
    if (end != null) {
      q = q.where('completedAt', isLessThanOrEqualTo: Timestamp.fromDate(end));
    }
    if (limit != null) {
      q = q.limit(limit);
    }
    return q.snapshots().map((snap) => snap.docs
        .map((d) => TaskEventModel.fromFirestore(d.data(), d.id))
        .toList());
  }

  /// Events for a specific user within a league.
  Stream<List<TaskEventModel>> watchUserEvents(
      String leagueId, String uid) {
    return _events(leagueId)
        .where('doerId', isEqualTo: uid)
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => TaskEventModel.fromFirestore(d.data(), d.id))
            .toList());
  }
}
