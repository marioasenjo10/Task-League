import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/league_model.dart';

class LeagueRepository {
  final FirebaseFirestore _db;
  final _uuid = const Uuid();

  LeagueRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _leagues =>
      _db.collection('leagues');

  Future<LeagueModel> createLeague({
    required String name,
    required String ownerId,
    required CompetitionType competitionType,
  }) async {
    final id = _uuid.v4();
    final inviteCode = id.substring(0, 6).toUpperCase();
    final league = LeagueModel(
      id: id,
      name: name,
      ownerId: ownerId,
      memberIds: [ownerId],
      competitionType: competitionType,
      createdAt: DateTime.now(),
      inviteCode: inviteCode,
    );
    await _leagues.doc(id).set(league.toFirestore());
    return league;
  }

  Future<LeagueModel?> getLeague(String id) async {
    final doc = await _leagues.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return LeagueModel.fromFirestore(doc.data()!, doc.id);
  }

  Stream<LeagueModel?> watchLeague(String id) {
    return _leagues.doc(id).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return LeagueModel.fromFirestore(doc.data()!, doc.id);
    });
  }

  /// All leagues where the user is a member.
  Stream<List<LeagueModel>> watchUserLeagues(String uid) {
    return _leagues
        .where('memberIds', arrayContains: uid)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => LeagueModel.fromFirestore(d.data(), d.id))
            .toList());
  }

  /// Leave a league (removes uid from memberIds).
  /// Returns false if the user is the owner (owners cannot leave).
  Future<bool> leaveLeague(String leagueId, String uid) async {
    final doc = await _leagues.doc(leagueId).get();
    if (!doc.exists || doc.data() == null) return false;
    final league = LeagueModel.fromFirestore(doc.data()!, doc.id);
    if (league.ownerId == uid) return false; // owners cannot leave
    await _leagues.doc(leagueId).update({
      'memberIds': FieldValue.arrayRemove([uid]),
    });
    return true;
  }

  /// Join a league by invite code.
  Future<LeagueModel?> joinByCode(String code, String uid) async {
    final snap = await _leagues
        .where('inviteCode', isEqualTo: code.toUpperCase())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    await doc.reference.update({
      'memberIds': FieldValue.arrayUnion([uid]),
    });
    return LeagueModel.fromFirestore(doc.data(), doc.id);
  }
}
