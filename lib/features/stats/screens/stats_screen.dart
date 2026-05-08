import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/stats_providers.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../auth/providers/auth_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Custom date-range picker helper
// Returns null if cancelled, otherwise a [StatsDateRange].
// ─────────────────────────────────────────────────────────────────────────────

Future<StatsDateRange?> _pickDateRange(
    BuildContext context, StatsDateRange? initial) async {
  final now = DateTime.now();
  final initialRange = initial != null
      ? DateTimeRange(start: initial.start, end: initial.end)
      : null;

  final picked = await showDateRangePicker(
    context: context,
    firstDate: DateTime(2020),
    lastDate: now,
    initialDateRange: initialRange,
    builder: (context, child) => Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF8E24AA),
          onPrimary: Colors.white,
          surface: Color(0xFF1E1E2E),
          onSurface: Colors.white,
        ),
      ),
      child: child!,
    ),
  );
  if (picked == null) return null;
  return StatsDateRange(start: picked.start, end: picked.end);
}

// ─────────────────────────────────────────────────────────────────────────────
// Palette
// ─────────────────────────────────────────────────────────────────────────────
const _palette = [
  Color(0xFF6C3CE1), Color(0xFFE53935), Color(0xFF00897B), Color(0xFFF57C00),
  Color(0xFF8E24AA), Color(0xFF039BE5), Color(0xFFFFB300), Color(0xFF43A047),
];
Color _colorFor(int i) => _palette[i % _palette.length];

// ─────────────────────────────────────────────────────────────────────────────
// Main screen
// ─────────────────────────────────────────────────────────────────────────────

class StatsScreen extends ConsumerWidget {
  final String leagueId;
  const StatsScreen({super.key, required this.leagueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(leagueStatsProvider(leagueId));
    final currentUid = ref.watch(authStateProvider).valueOrNull?.uid;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('statistics'))),
      body: Column(
        children: [
          // ── Filter bar (always visible) ──────────────────────────────────
          _FilterBar(leagueId: leagueId),
          const Divider(height: 1, color: Colors.white12),

          // ── Content ──────────────────────────────────────────────────────
          Expanded(
            child: statsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                  child: Text('$e', style: const TextStyle(color: Colors.white54))),
              data: (stats) => stats.totalEvents == 0
                  ? _EmptyStats(leagueId: leagueId)
                  : _StatsBody(stats: stats, currentUid: currentUid),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter bar — quick chips + month navigator
// ─────────────────────────────────────────────────────────────────────────────

class _FilterBar extends ConsumerWidget {
  final String leagueId;
  const _FilterBar({required this.leagueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter   = ref.watch(statsFilterProvider(leagueId));
    final notifier = ref.read(statsFilterProvider(leagueId).notifier);
    final now      = DateTime.now();

    // Determine which quick-chip is active
    final isThisMonth  = !filter.isAllTime && filter is! ThreeMonthFilter &&
        filter is! CustomRangeFilter &&
        filter.year == now.year && filter.month == now.month;
    final isLastMonth = () {
      final lm = now.month == 1 ? 12 : now.month - 1;
      final ly = now.month == 1 ? now.year - 1 : now.year;
      return !filter.isAllTime && filter is! ThreeMonthFilter &&
          filter is! CustomRangeFilter &&
          filter.year == ly && filter.month == lm;
    }();
    final is3Months    = filter is ThreeMonthFilter;
    final isAllTime    = filter.isAllTime;
    final isCustom     = filter is CustomRangeFilter;

    // Label for custom chip
    String customLabel;
    if (filter is CustomRangeFilter) {
      final fmt = DateFormat('d MMM', context.l10n.locale.languageCode);
      customLabel = '${fmt.format(filter.rangeStart)} – ${fmt.format(filter.rangeEnd)}';
    } else {
      customLabel = context.tr('statsCustomRange');
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Quick chips ─────────────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _QuickChip(
                  label: context.tr('statsThisMonth'),
                  active: isThisMonth,
                  onTap: notifier.setThisMonth,
                ),
                const SizedBox(width: 8),
                _QuickChip(
                  label: context.tr('statsLastMonth'),
                  active: isLastMonth,
                  onTap: notifier.setLastMonth,
                ),
                const SizedBox(width: 8),
                _QuickChip(
                  label: context.tr('statsLast3Months'),
                  active: is3Months,
                  onTap: notifier.setLast3Months,
                ),
                const SizedBox(width: 8),
                _QuickChip(
                  label: context.tr('statsAllTime'),
                  active: isAllTime,
                  onTap: notifier.setAllTime,
                ),
                const SizedBox(width: 8),
                // ── Custom range chip ──────────────────────────────────────
                _CustomRangeChip(
                  label: customLabel,
                  active: isCustom,
                  onTap: () async {
                    StatsDateRange? current;
                    if (filter is CustomRangeFilter) {
                      current = StatsDateRange(
                          start: filter.rangeStart, end: filter.rangeEnd);
                    }
                    final picked =
                        await _pickDateRange(context, current);
                    if (picked != null) {
                      notifier.setCustomRange(
                          picked.start, picked.end);
                    }
                  },
                  onClear: isCustom ? notifier.setThisMonth : null,
                ),
              ],
            ),
          ),

          // ── Month navigator (hidden when allTime or custom) ──────────────
          if (!filter.isAllTime && filter is! CustomRangeFilter) ...[
            const SizedBox(height: 8),
            _MonthNavigator(leagueId: leagueId, filter: filter, notifier: notifier),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick chip
// ─────────────────────────────────────────────────────────────────────────────

class _QuickChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _QuickChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF8E24AA);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? accent : Colors.white.withAlpha(15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? accent : Colors.white.withAlpha(30),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            color: active ? Colors.white : Colors.white54,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom range chip — calendar icon + label + optional ✕ clear button
// ─────────────────────────────────────────────────────────────────────────────

class _CustomRangeChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  const _CustomRangeChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF8E24AA);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.only(
            left: 10, right: active ? 4 : 10, top: 6, bottom: 6),
        decoration: BoxDecoration(
          color: active ? accent : Colors.white.withAlpha(15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? accent : Colors.white.withAlpha(30),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.date_range,
                size: 13,
                color: active ? Colors.white : Colors.white54),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                color: active ? Colors.white : Colors.white54,
              ),
            ),
            if (active && onClear != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close,
                    size: 14, color: Colors.white70),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Month navigator — ← Abril 2025 →
// ─────────────────────────────────────────────────────────────────────────────

class _MonthNavigator extends StatelessWidget {
  final String leagueId;
  final StatsFilter filter;
  final StatsFilterNotifier notifier;
  const _MonthNavigator({
    required this.leagueId,
    required this.filter,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.l10n.locale.languageCode;
    final canNext = notifier.canGoNext;

    // Build label
    String label;
    if (filter is ThreeMonthFilter) {
      final s = filter as ThreeMonthFilter;
      final startFmt = DateFormat('MMM yyyy', lang)
          .format(DateTime(s.startYear, s.startMonth));
      var em = s.startMonth + 2;
      var ey = s.startYear;
      if (em > 12) { em -= 12; ey += 1; }
      final endFmt = DateFormat('MMM yyyy', lang).format(DateTime(ey, em));
      label = '$startFmt – $endFmt';
    } else {
      label = DateFormat('MMMM yyyy', lang)
          .format(DateTime(filter.year!, filter.month!));
      // Capitalise first letter
      label = label[0].toUpperCase() + label.substring(1);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white70),
          onPressed: notifier.previousMonth,
          splashRadius: 18,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        IconButton(
          icon: Icon(Icons.chevron_right,
              color: canNext ? Colors.white70 : Colors.white24),
          onPressed: canNext ? notifier.nextMonth : null,
          splashRadius: 18,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Body
// ─────────────────────────────────────────────────────────────────────────────

class _StatsBody extends StatelessWidget {
  final LeagueStats stats;
  final String? currentUid;
  const _StatsBody({required this.stats, this.currentUid});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _SummaryRow(stats: stats),
        const SizedBox(height: 20),
        _SectionHeader(context.tr('statsByMember')),
        const SizedBox(height: 12),
        _PieSection(stats: stats),
        const SizedBox(height: 24),
        _SectionHeader(context.tr('statsTopTasks')),
        const SizedBox(height: 12),
        _TopTasksBar(stats: stats),
        const SizedBox(height: 24),
        _SectionHeader(context.tr('statsMemberBreakdown')),
        const SizedBox(height: 8),
        ...stats.memberStats.asMap().entries.map((entry) => _MemberCard(
              memberStats: entry.value,
              color: _colorFor(entry.key),
              isCurrentUser: entry.value.member.id == currentUid,
            )),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary chips
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final LeagueStats stats;
  const _SummaryRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    final totalDmg   = stats.memberStats.fold(0, (s, m) => s + m.totalDamage);
    final totalCoins = stats.memberStats.fold(0, (s, m) => s + m.totalCoins);
    return Row(children: [
      _StatChip(icon: Icons.task_alt,  label: context.tr('statsTotalTasks'),
          value: '${stats.totalEvents}', color: const Color(0xFF6C3CE1)),
      const SizedBox(width: 8),
      _StatChip(icon: Icons.whatshot,  label: context.tr('statsTotalDamage'),
          value: '$totalDmg', color: const Color(0xFFE53935)),
      const SizedBox(width: 8),
      _StatChip(icon: Icons.toll,      label: context.tr('statsTotalCoins'),
          value: '$totalCoins', color: const Color(0xFFF57C00)),
    ]);
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon; final String label, value; final Color color;
  const _StatChip({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(30),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pie chart
// ─────────────────────────────────────────────────────────────────────────────

class _PieSection extends StatefulWidget {
  final LeagueStats stats;
  const _PieSection({required this.stats});
  @override
  State<_PieSection> createState() => _PieSectionState();
}

class _PieSectionState extends State<_PieSection> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final ms = widget.stats.memberStats.where((m) => m.totalTasks > 0).toList();
    if (ms.isEmpty) return const SizedBox.shrink();
    final sections = ms.asMap().entries.map((entry) {
      final i = entry.key; final m = entry.value;
      final isTouched = i == _touched;
      final pct = (m.totalTasks / widget.stats.totalEvents * 100).toStringAsFixed(1);
      return PieChartSectionData(
        value: m.totalTasks.toDouble(), color: _colorFor(i),
        radius: isTouched ? 70 : 58,
        title: isTouched ? '$pct%' : '',
        titleStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();

    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      SizedBox(
        height: 180, width: 180,
        child: PieChart(PieChartData(
          sections: sections, centerSpaceRadius: 36, sectionsSpace: 2,
          pieTouchData: PieTouchData(touchCallback: (event, response) {
            setState(() {
              _touched = (!event.isInterestedForInteractions ||
                  response?.touchedSection == null)
                  ? -1
                  : response!.touchedSection!.touchedSectionIndex;
            });
          }),
        )),
      ),
      const SizedBox(width: 20),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: ms.asMap().entries.map((entry) {
            final i = entry.key; final m = entry.value;
            final color = _colorFor(i);
            final name = m.member.name.isNotEmpty ? m.member.name : m.member.email;
            final isTouched = i == _touched;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: isTouched ? 14 : 10, height: isTouched ? 14 : 10,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(name,
                    style: TextStyle(fontSize: 12,
                        color: isTouched ? Colors.white : Colors.white70,
                        fontWeight: isTouched ? FontWeight.bold : FontWeight.normal,
                        overflow: TextOverflow.ellipsis),
                    maxLines: 1)),
                Text('${m.totalTasks}',
                    style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
              ]),
            );
          }).toList(),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top tasks bar
// ─────────────────────────────────────────────────────────────────────────────

class _TopTasksBar extends StatelessWidget {
  final LeagueStats stats;
  const _TopTasksBar({required this.stats});

  @override
  Widget build(BuildContext context) {
    final sorted = stats.topTasks.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(6).toList();
    if (top.isEmpty) return const SizedBox.shrink();
    final maxVal = top.first.value.toDouble();

    return Column(children: top.asMap().entries.map((entry) {
      final i = entry.key; final e = entry.value;
      final ratio = maxVal > 0 ? e.value / maxVal : 0.0;
      final color = _colorFor(i);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(width: 110, child: Text(e.key,
              style: const TextStyle(fontSize: 11, color: Colors.white70),
              maxLines: 2, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Expanded(child: Stack(children: [
            Container(height: 20,
                decoration: BoxDecoration(color: Colors.white10,
                    borderRadius: BorderRadius.circular(4))),
            FractionallySizedBox(
              widthFactor: ratio.clamp(0.0, 1.0),
              child: Container(height: 20,
                  decoration: BoxDecoration(color: color.withAlpha(180),
                      borderRadius: BorderRadius.circular(4))),
            ),
          ])),
          const SizedBox(width: 8),
          SizedBox(width: 24, child: Text('${e.value}',
              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold),
              textAlign: TextAlign.right)),
        ]),
      );
    }).toList());
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-member expandable card
// ─────────────────────────────────────────────────────────────────────────────

class _MemberCard extends StatefulWidget {
  final MemberStats memberStats;
  final Color color;
  final bool isCurrentUser;
  const _MemberCard({required this.memberStats, required this.color, required this.isCurrentUser});
  @override
  State<_MemberCard> createState() => _MemberCardState();
}

class _MemberCardState extends State<_MemberCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final m    = widget.memberStats;
    final name = m.member.name.isNotEmpty ? m.member.name : m.member.email;
    final sorted = m.taskFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxFreq = sorted.isEmpty ? 1 : sorted.first.value;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: widget.isCurrentUser
              ? widget.color.withAlpha(150)
              : Colors.white.withAlpha(15)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(radius: 18,
                  backgroundColor: widget.color.withAlpha(40),
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(color: widget.color, fontWeight: FontWeight.bold))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  if (widget.isCurrentUser) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                          color: widget.color.withAlpha(80),
                          borderRadius: BorderRadius.circular(4)),
                      child: const Text('YOU', style: TextStyle(
                          fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ]),                  Text(
                  '${m.totalTasks} ${context.tr('statsTasks')}  ·  '
                  '${m.totalDamage} ${context.tr('statsDmg')}  ·  '
                  '${m.totalCoins} ${context.tr('statsCoins')}',
                  style: const TextStyle(fontSize: 11, color: Colors.white54)),
              ])),
              Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: Colors.white38),
            ]),

            if (_expanded && sorted.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, color: Colors.white12),
              const SizedBox(height: 10),
              Text(context.tr('statsTaskBreakdown'),
                  style: const TextStyle(fontSize: 11, color: Colors.white38, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              ...sorted.take(8).map((entry) {
                final ratio = entry.value / maxFreq;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Expanded(child: Text(entry.key,
                          style: const TextStyle(fontSize: 11, color: Colors.white70),
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Text('×${entry.value}',
                          style: TextStyle(fontSize: 11, color: widget.color, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 3),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: ratio, minHeight: 5,
                        backgroundColor: Colors.white10,
                        valueColor: AlwaysStoppedAnimation(widget.color.withAlpha(180)),
                      ),
                    ),
                  ]),
                );
              }),
            ],
            if (_expanded && sorted.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(context.tr('statsNoData'),
                    style: const TextStyle(fontSize: 12, color: Colors.white38)),
              ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.white38, letterSpacing: 1.4));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyStats extends ConsumerWidget {
  final String leagueId;
  const _EmptyStats({required this.leagueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.bar_chart, size: 64, color: Colors.white24),
        const SizedBox(height: 16),
        Text(context.tr('statsNoDataPeriod'),
            style: const TextStyle(color: Colors.white54)),
        const SizedBox(height: 6),
        Text(context.tr('statsNoDataSub'),
            style: const TextStyle(color: Colors.white38, fontSize: 12)),
      ]),
    );
  }
}
