import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../league/providers/league_providers.dart';
import '../../league/models/league_model.dart';
import '../../auth/providers/auth_providers.dart';
import '../../profile/providers/calendar_sync_provider.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/widgets/coins_chip.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaguesAsync = ref.watch(userLeaguesProvider);
    final locale = ref.watch(localeProvider);
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    // Watch calendarSyncProvider here so its build() runs immediately on login,
    // triggering the background Google session restore + bulk sync.
    ref.watch(calendarSyncProvider);
    final calendarInitializing = ref.watch(calendarSyncInitializingProvider);

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Image.asset('assets/images/Logo_white_withoutText.png', height: 48),
            centerTitle: false,
            actions: [
              if (currentUser != null)
                CoinsChip(coins: currentUser.coins),
              _LanguageButton(currentLocale: locale),
              IconButton(
                icon: const Icon(Icons.person),
                onPressed: () => context.push('/profile'),
              ),
            ],
          ),
          body: leaguesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    color: Colors.redAccent, size: 48),
                const SizedBox(height: 12),
                Text(context.tr('error'),
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(e.toString(),
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        ),
        data: (leagues) => leagues.isEmpty
            ? _EmptyLeagues(
                onCreateTap: () => context.push('/league/create'),
                onJoinTap: () => context.push('/league/create?tab=1'),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: leagues.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) =>
                    _LeagueCard(league: leagues[index]),
              ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'join',
            icon: const Icon(Icons.group_add),
            label: Text(context.tr('joinLeagueBtn')),
            backgroundColor: const Color(0xFF37474F),
            onPressed: () => context.push('/league/create?tab=1'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'create',
            icon: const Icon(Icons.add),
            label: Text(context.tr('newLeague')),
            onPressed: () => context.push('/league/create'),
          ),
        ],
      ),
        ),

        // ── Calendar sync overlay ──────────────────────────────────────────
        if (calendarInitializing)
          Container(
            color: Colors.black54,
            child: Center(
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 20),
                      Text(
                        context.tr('syncingCalendar'),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.tr('syncingCalendarSub'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Language toggle button
// ---------------------------------------------------------------------------

class _LanguageButton extends ConsumerWidget {
  final Locale currentLocale;
  const _LanguageButton({required this.currentLocale});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(localeProvider.notifier);
    final isEn = currentLocale.languageCode == 'en';

    return TextButton(
      onPressed: () => notifier.toggle(),
      style: TextButton.styleFrom(
        foregroundColor: Colors.white70,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.language, size: 16),
          const SizedBox(width: 4),
          Text(
            isEn ? 'EN' : 'ES',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// League card
// ---------------------------------------------------------------------------

class _LeagueCard extends StatelessWidget {
  final LeagueModel league;
  const _LeagueCard({required this.league});

  @override
  Widget build(BuildContext context) {
    final count = league.memberIds.length;
    final typeLabel = league.competitionType == CompetitionType.weekly
        ? context.tr('weeklyCompetition')
        : context.tr('monthlyCompetition');
    final memberLabel = count == 1
        ? context.tr('fighter')
        : context.tr('fighters');

    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFF6C3CE1),
          child: Icon(Icons.shield, color: Colors.white),
        ),
        title: Text(league.name),
        subtitle: Text(
          '$count $memberLabel · $typeLabel',
          style: Theme.of(context).textTheme.labelSmall,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/league/${league.id}'),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyLeagues extends StatelessWidget {
  final VoidCallback onCreateTap;
  final VoidCallback onJoinTap;
  const _EmptyLeagues(
      {required this.onCreateTap, required this.onJoinTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events_outlined,
              size: 72, color: Colors.white30),
          const SizedBox(height: 16),
          Text(context.tr('noLeaguesYet'),
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(context.tr('noLeaguesSubtitle'),
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: Text(context.tr('createLeague')),
                onPressed: onCreateTap,
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.group_add),
                label: Text(context.tr('joinLeague')),
                onPressed: onJoinTap,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
