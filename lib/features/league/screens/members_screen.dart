import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/league_providers.dart';
import '../models/league_model.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/repositories/user_repository.dart';
import '../../auth/models/user_model.dart';
import '../../../core/widgets/fighter_sprite.dart';

// ---------------------------------------------------------------------------
// Provider: fetch all member UserModels for a given leagueId
// ---------------------------------------------------------------------------

final leagueMembersProvider = StreamProvider.family<List<UserModel>, String>(
  (ref, leagueId) async* {
    // Depend on auth state — when the user signs out/in this provider restarts
    final currentUid = ref.watch(authStateProvider).valueOrNull?.uid;
    if (currentUid == null) {
      yield [];
      return;
    }

    final league = await ref.watch(leagueProvider(leagueId).future);
    if (league == null) {
      yield [];
      return;
    }
    final repo = UserRepository();
    // Combine streams of all members into one list stream
    final streams = league.memberIds.map((uid) => repo.watchUser(uid)).toList();
    yield* _mergeUserStreams(streams);
  },
);

/// Merges multiple user streams into a single list stream.
Stream<List<UserModel>> _mergeUserStreams(
    List<Stream<UserModel?>> streams) async* {
  if (streams.isEmpty) {
    yield [];
    return;
  }
  final latest = List<UserModel?>.filled(streams.length, null);
  // Use a broadcast approach: re-emit on any change
  final controller =
      StreamController<List<UserModel>>.broadcast();

  for (int i = 0; i < streams.length; i++) {
    final idx = i;
    streams[idx].listen((user) {
      latest[idx] = user;
      if (!controller.isClosed) {
        controller.add(latest.whereType<UserModel>().toList());
      }
    });
  }

  yield* controller.stream;
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class MembersScreen extends ConsumerWidget {
  final String leagueId;
  const MembersScreen({super.key, required this.leagueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leagueAsync = ref.watch(leagueProvider(leagueId));
    final membersAsync = ref.watch(leagueMembersProvider(leagueId));
    final currentUid = ref.watch(authStateProvider).valueOrNull?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Members')),
      body: leagueAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorBody(message: e.toString()),
        data: (league) {
          if (league == null) {
            return const _ErrorBody(message: 'League not found.');
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── League info card ─────────────────────────────────────────
              _LeagueInfoCard(
                name: league.name,
                competitionType: league.competitionType.name,
                memberCount: league.memberIds.length,
                inviteCode: league.inviteCode,
              ),
              const SizedBox(height: 24),
              // ── Section header ───────────────────────────────────────────
              Text(
                'Fighters (${league.memberIds.length})',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 10),
              // ── Member list ──────────────────────────────────────────────
              membersAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, _) => _ErrorBody(message: e.toString()),
                data: (members) {
                  if (members.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'No members found.',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                    );
                  }
                  // Sort: owner first, then by level desc
                  final sorted = [...members]..sort((a, b) {
                      final aIsOwner = a.id == league.ownerId ? 0 : 1;
                      final bIsOwner = b.id == league.ownerId ? 0 : 1;
                      if (aIsOwner != bIsOwner) return aIsOwner - bIsOwner;
                      return b.coins.compareTo(a.coins);
                    });
                  return Column(
                    children: sorted
                        .map((u) => _MemberTile(
                              user: u,
                              isOwner: u.id == league.ownerId,
                              isCurrentUser: u.id == currentUid,
                              leagueId: league.id,
                              maxHp: maxHpForType(league.competitionType),
                            ))
                        .toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// League info card with invite code
// ---------------------------------------------------------------------------

class _LeagueInfoCard extends StatelessWidget {
  final String name;
  final String competitionType;
  final int memberCount;
  final String? inviteCode;

  const _LeagueInfoCard({
    required this.name,
    required this.competitionType,
    required this.memberCount,
    this.inviteCode,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 24,
                  backgroundColor: Color(0xFF6C3CE1),
                  child: Icon(Icons.shield, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${competitionType[0].toUpperCase()}${competitionType.substring(1)} · $memberCount fighter${memberCount == 1 ? '' : 's'}',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (inviteCode != null) ...[
              const SizedBox(height: 20),
              const Divider(color: Colors.white12),
              const SizedBox(height: 14),
              Text(
                'Invite Code',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: Colors.white54, letterSpacing: 1),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C3CE1).withAlpha(40),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFF6C3CE1).withAlpha(120)),
                    ),
                    child: Text(
                      inviteCode!,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 8,
                        color: Color(0xFFB39DDB),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.copy),
                    tooltip: 'Copy invite code',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: inviteCode!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Invite code copied!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.share),
                    tooltip: 'Share invite code',
                    onPressed: () => _shareCode(context, inviteCode!),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Share this code with friends to invite them to your league.',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _shareCode(BuildContext context, String code) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Share Invite Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Share this code with your friends so they can join your league:'),
            const SizedBox(height: 16),
            SelectableText(
              code,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 10,
                color: Color(0xFFB39DDB),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invite code copied!')),
              );
            },
            child: const Text('Copy & Close'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Member tile
// ---------------------------------------------------------------------------

class _MemberTile extends StatelessWidget {
  final UserModel user;
  final bool isOwner;
  final bool isCurrentUser;
  final String leagueId;
  final int maxHp;

  const _MemberTile({
    required this.user,
    required this.isOwner,
    required this.isCurrentUser,
    required this.leagueId,
    required this.maxHp,
  });

  @override
  Widget build(BuildContext context) {
    final hp = user.currentHp(leagueId, maxHp: maxHp);
    final hpPercent = maxHp > 0 ? (hp / maxHp).clamp(0.0, 1.0) : 0.0;
    final hpColor = hpPercent > 0.5
        ? const Color(0xFF66BB6A)
        : hpPercent > 0.25
            ? const Color(0xFFFFCA28)
            : const Color(0xFFEF5350);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar — fighter sprite instead of initials
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF6C3CE1).withAlpha(40),
                    border: Border.all(
                      color: isCurrentUser
                          ? const Color(0xFF6C3CE1)
                          : Colors.white12,
                      width: 2,
                    ),
                  ),
                  // Always show the fighter sprite — more fitting for this
                  // app and avoids flaky network image loads (429s, etc.)
                  child: ClipOval(
                    child: FighterSprite(
                      skin: user.characterSkin,
                      size: 56,
                    ),
                  ),
                ),
                if (isOwner)
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF57C00),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.star,
                          size: 11, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.name.isNotEmpty ? user.name : user.email,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C3CE1).withAlpha(80),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'You',
                            style: TextStyle(
                                color: Color(0xFFB39DDB),
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                      if (isOwner) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF57C00).withAlpha(60),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Leader',
                            style: TextStyle(
                                color: Color(0xFFFFB74D),
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  // HP bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: hpPercent,
                      minHeight: 6,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(hpColor),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'HP $hp/$maxHp',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Coins badge
            Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF57C00).withAlpha(40),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: const Color(0xFFF57C00).withAlpha(160),
                        width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      '${user.coins}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFFFFB74D)),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                const Text('🪙',
                    style: TextStyle(fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error body helper
// ---------------------------------------------------------------------------

class _ErrorBody extends StatelessWidget {
  final String message;
  const _ErrorBody({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
