import 'package:equatable/equatable.dart';
import '../../auth/models/user_model.dart' show kWeeklyMaxHp, kMonthlyMaxHp;

enum CompetitionType { weekly, monthly }

// ── Period helpers ──────────────────────────────────────────────────────────

/// Returns the max HP for this competition type.
int maxHpForType(CompetitionType type) =>
    type == CompetitionType.weekly ? kWeeklyMaxHp : kMonthlyMaxHp;

/// Returns the period key string for "now":
///   weekly  → "2026-W15"  (ISO week number)
///   monthly → "2026-04"
String currentPeriodKey(CompetitionType type) {
  final now = DateTime.now();
  if (type == CompetitionType.monthly) {
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }
  // ISO week number
  final week = _isoWeekNumber(now);
  return '${now.year}-W${week.toString().padLeft(2, '0')}';
}

int _isoWeekNumber(DateTime date) {
  final doy = date.difference(DateTime(date.year, 1, 1)).inDays + 1;
  return ((doy - date.weekday + 10) / 7).floor();
}

// Tiny helper used only here
class DateHelper {
  static int dayOfYear(DateTime date) {
    return date.difference(DateTime(date.year, 1, 1)).inDays + 1;
  }
}

// ── Model ───────────────────────────────────────────────────────────────────

class LeagueModel extends Equatable {
  final String id;
  final String name;
  final String ownerId;
  final List<String> memberIds;
  final CompetitionType competitionType;
  final DateTime createdAt;
  final String? inviteCode;

  const LeagueModel({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.memberIds,
    required this.competitionType,
    required this.createdAt,
    this.inviteCode,
  });

  factory LeagueModel.fromFirestore(Map<String, dynamic> data, String id) {
    return LeagueModel(
      id: id,
      name: data['name'] ?? '',
      ownerId: data['ownerId'] ?? '',
      memberIds: List<String>.from(data['memberIds'] ?? []),
      competitionType: data['competitionType'] == 'monthly'
          ? CompetitionType.monthly
          : CompetitionType.weekly,
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      inviteCode: data['inviteCode'],
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'ownerId': ownerId,
        'memberIds': memberIds,
        'competitionType': competitionType.name,
        'createdAt': createdAt,
        'inviteCode': inviteCode,
      };

  LeagueModel copyWith({
    String? id,
    String? name,
    String? ownerId,
    List<String>? memberIds,
    CompetitionType? competitionType,
    DateTime? createdAt,
    String? inviteCode,
  }) {
    return LeagueModel(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      memberIds: memberIds ?? this.memberIds,
      competitionType: competitionType ?? this.competitionType,
      createdAt: createdAt ?? this.createdAt,
      inviteCode: inviteCode ?? this.inviteCode,
    );
  }

  @override
  List<Object?> get props =>
      [id, name, ownerId, memberIds, competitionType, createdAt, inviteCode];
}
