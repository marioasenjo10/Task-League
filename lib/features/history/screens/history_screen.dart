import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/history_providers.dart';
import '../models/task_event_model.dart';
import '../../league/screens/members_screen.dart' show leagueMembersProvider;

class HistoryScreen extends ConsumerStatefulWidget {
  final String leagueId;
  const HistoryScreen({super.key, required this.leagueId});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(historyFilterProvider(widget.leagueId));
    final historyAsync = ref.watch(filteredHistoryProvider(widget.leagueId));
    final notifier = ref.read(historyFilterProvider(widget.leagueId).notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task History'),
        actions: [
          if (filter.isActive)
            TextButton.icon(
              icon: const Icon(Icons.clear_all, color: Colors.redAccent, size: 18),
              label: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
              onPressed: () {
                notifier.reset();
                _searchController.clear();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter panel — always visible ─────────────────────────────────
          _FilterPanel(
            leagueId: widget.leagueId,
            filter: filter,
            notifier: notifier,
            searchController: _searchController,
          ),

          // ── Results count + limit note ────────────────────────────────────
          historyAsync.whenData((events) => events).valueOrNull != null
              ? _ResultsBar(
                  leagueId: widget.leagueId,
                  shownCount: historyAsync.valueOrNull?.length ?? 0,
                )
              : const SizedBox.shrink(),

          // ── List ──────────────────────────────────────────────────────────
          Expanded(
            child: historyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (events) => events.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.history_toggle_off,
                              size: 56, color: Colors.white24),
                          const SizedBox(height: 12),
                          Text(
                            filter.isActive
                                ? 'No results for these filters.'
                                : 'No activity yet.',
                            style: const TextStyle(color: Colors.white54),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: events.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) => _EventTile(event: events[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Results bar
// ─────────────────────────────────────────────────────────────────────────────

class _ResultsBar extends ConsumerWidget {
  final String leagueId;
  final int shownCount;
  const _ResultsBar({required this.leagueId, required this.shownCount});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(historyFilterProvider(leagueId));
    final notifier = ref.read(historyFilterProvider(leagueId).notifier);

    return Container(
      color: const Color(0xFF12122A),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Text(
            'Showing $shownCount task${shownCount == 1 ? '' : 's'}',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const Spacer(),
          const Text('Max: ', style: TextStyle(color: Colors.white38, fontSize: 12)),
          DropdownButton<int?>(
            value: filter.limit,
            isDense: true,
            underline: const SizedBox.shrink(),
            dropdownColor: const Color(0xFF1A1A2E),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            items: kHistoryLimitOptions.map((v) => DropdownMenuItem<int?>(
              value: v,
              child: Text(
                v == null ? 'All' : v.toString(),
                style: TextStyle(
                  color: filter.limit == v
                      ? const Color(0xFFB39DDB)
                      : Colors.white70,
                  fontWeight: filter.limit == v
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            )).toList(),
            onChanged: notifier.setLimit,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter panel
// ─────────────────────────────────────────────────────────────────────────────

class _FilterPanel extends ConsumerWidget {
  final String leagueId;
  final HistoryFilter filter;
  final HistoryFilterNotifier notifier;
  final TextEditingController searchController;

  const _FilterPanel({
    required this.leagueId,
    required this.filter,
    required this.notifier,
    required this.searchController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(leagueMembersProvider(leagueId));

    return Container(
      color: const Color(0xFF1A1A2E),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search by task name
          TextField(
            controller: searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, color: Colors.white38),
              hintText: 'Search task name…',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withAlpha(12),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, color: Colors.white38),
                      onPressed: () {
                        searchController.clear();
                        notifier.setSearch('');
                      },
                    )
                  : null,
            ),
            onChanged: notifier.setSearch,
          ),
          const SizedBox(height: 12),

          // Fighter selector
          membersAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (members) {
              if (members.isEmpty) return const SizedBox.shrink();
              return DropdownButtonFormField<String?>(
                value: filter.memberUid,
                dropdownColor: const Color(0xFF1A1A2E),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  prefixIcon:
                      const Icon(Icons.person_search, color: Colors.white38),
                  hintText: 'All fighters',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withAlpha(12),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All fighters',
                        style: TextStyle(color: Colors.white54)),
                  ),
                  ...members.map((m) => DropdownMenuItem<String?>(
                        value: m.id,
                        child: Text(m.name,
                            style: const TextStyle(color: Colors.white)),
                      )),
                ],
                onChanged: notifier.setMember,
              );
            },
          ),
          const SizedBox(height: 12),

          // Date range picker
          Row(
            children: [
              Expanded(
                child: _DatePickerField(
                  label: 'From',
                  date: filter.dateFrom,
                  lastDate: filter.dateTo ?? DateTime.now(),
                  onPicked: (d) => notifier.setDateRange(d, filter.dateTo),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DatePickerField(
                  label: 'To',
                  date: filter.dateTo,
                  firstDate: filter.dateFrom,
                  lastDate: DateTime.now(),
                  onPicked: (d) => notifier.setDateRange(filter.dateFrom, d),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Date picker field
// ─────────────────────────────────────────────────────────────────────────────

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final ValueChanged<DateTime?> onPicked;

  const _DatePickerField({
    required this.label,
    required this.date,
    required this.onPicked,
    this.firstDate,
    this.lastDate,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy');
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: firstDate ?? DateTime(2020),
          lastDate: lastDate ?? DateTime.now(),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.dark(
                primary: Color(0xFF6C3CE1),
                onPrimary: Colors.white,
                surface: Color(0xFF1A1A2E),
                onSurface: Colors.white,
              ),
            ),
            child: child!,
          ),
        );
        onPicked(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: date != null
                ? const Color(0xFF6C3CE1)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              size: 16,
              color: date != null ? const Color(0xFF6C3CE1) : Colors.white38,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                date != null ? fmt.format(date!) : label,
                style: TextStyle(
                  color: date != null ? Colors.white : Colors.white38,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (date != null)
              GestureDetector(
                onTap: () => onPicked(null),
                child:
                    const Icon(Icons.close, size: 14, color: Colors.white38),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Event tile
// ─────────────────────────────────────────────────────────────────────────────

class _EventTile extends ConsumerWidget {
  final TaskEventModel event;
  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doerName = ref.watch(userDisplayNameProvider(event.doerId));
    final targetName = event.targetId != null
        ? ref.watch(userDisplayNameProvider(event.targetId!))
        : null;

    final doer = doerName.valueOrNull ?? event.doerId;
    final target = targetName?.valueOrNull ?? event.targetId;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF6C3CE1).withAlpha(50),
        child: const Icon(Icons.bolt, color: Color(0xFFB39DDB)),
      ),
      title: Text(
        '$doer completed "${event.taskTitle}"',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _Tag(
              icon: Icons.local_fire_department,
              label: '-${event.damageDealt} HP'
                  '${target != null ? ' to $target' : ''}',
              color: Colors.redAccent,
            ),
            if (event.coinsEarned > 0)
              _Tag(
                icon: Icons.toll,
                label: '+${event.coinsEarned} 🪙',
                color: const Color(0xFFFFB74D),
              ),
            _Tag(
              icon: Icons.access_time,
              label: DateFormat('dd MMM · HH:mm').format(event.completedAt),
              color: Colors.white38,
            ),
          ],
        ),
      ),
      isThreeLine: true,
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Tag({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }
}
