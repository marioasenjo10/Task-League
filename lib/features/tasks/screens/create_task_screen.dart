import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/services/quota_guard.dart';
import '../providers/task_service_provider.dart';
import '../models/task_model.dart';
import '../../auth/providers/auth_providers.dart';
import '../../league/screens/members_screen.dart' show leagueMembersProvider;

// Reminder options: translation key → minutes before
const _reminderOptions = <String, int?>{
  'reminderNone': null,
  'reminder15': 15,
  'reminder30': 30,
  'reminder60': 60,
  'reminder120': 120,
  'reminder1440': 1440,
  'reminder2880': 2880,
};

enum _DateMode { scheduled, due }

class CreateTaskScreen extends ConsumerStatefulWidget {
  final String leagueId;
  const CreateTaskScreen({super.key, required this.leagueId});

  @override
  ConsumerState<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends ConsumerState<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  int _effort = 1;
  TaskRepeat _repeat = TaskRepeat.none;
  _DateMode _dateMode = _DateMode.scheduled;
  DateTime? _pickedDate; // shared for both modes
  int? _reminderMinutes = 30;
  String? _assigneeId; // set to currentUid once members load
  bool _assigneeInitialised = false;
  bool _loading = false;
  bool _submitted = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final initialDate = _pickedDate ??
        (_dateMode == _DateMode.scheduled
            ? now
            : now.add(const Duration(days: 1)));

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: _dateMode == _DateMode.scheduled
          ? now.subtract(const Duration(days: 365))
          : now,
      lastDate: now.add(const Duration(days: 365 * 2)),
      builder: _darkCalendarTheme,
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_pickedDate ?? now),
      builder: _darkCalendarTheme,
    );
    if (time == null || !mounted) return;

    setState(() {
      _pickedDate =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Widget Function(BuildContext, Widget?) get _darkCalendarTheme =>
      (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.dark(
                primary: Color(0xFF6C3CE1),
                onPrimary: Colors.white,
                surface: Color(0xFF1A1A2E),
                onSurface: Colors.white,
              ),
            ),
            child: child!,
          );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pickedDate == null) {
      setState(() => _submitted = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_dateMode == _DateMode.scheduled
              ? context.tr('pleaseSetScheduled')
              : context.tr('pleaseSetDue')),
        ),
      );
      return;
    }
    setState(() => _loading = true);

    try {
      final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
      final task = TaskModel(
        id: '',
        leagueId: widget.leagueId,
        creatorId: uid,
        assigneeId: _assigneeId,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        effort: _effort,
        repeat: _repeat,
        scheduledAt: _dateMode == _DateMode.scheduled ? _pickedDate : null,
        dueDate: _dateMode == _DateMode.due ? _pickedDate : null,
        reminderMinutesBefore: _reminderMinutes,
        addToCalendar: false,
      );

      await ref.read(taskServiceProvider).createTaskWithCalendarSync(
            task: task,
            creatorId: uid,
          );

      if (mounted) context.pop();
    } catch (e) {
      if (handleQuotaError(e, context: mounted ? context : null)) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.tr('error')}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy – HH:mm');
    final membersAsync = ref.watch(leagueMembersProvider(widget.leagueId));
    final currentUid = ref.watch(authStateProvider).valueOrNull?.uid;

    // Default assignee = me, once members are available
    membersAsync.whenData((members) {
      if (!_assigneeInitialised && currentUid != null) {
        final isMember = members.any((m) => m.id == currentUid);
        if (isMember) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _assigneeId = currentUid;
                _assigneeInitialised = true;
              });
            }
          });
        }
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('createTask'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Title ──────────────────────────────────────────────────
              TextFormField(
                controller: _titleController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: context.tr('taskTitle'),
                  prefixIcon: const Icon(Icons.task_alt),
                ),
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.isEmpty) ? context.tr('enterTitle') : null,
              ),
              const SizedBox(height: 16),

              // ── Description ───────────────────────────────────────────
              TextFormField(
                controller: _descController,
                decoration: InputDecoration(
                  labelText: context.tr('description'),
                  prefixIcon: const Icon(Icons.notes),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              // ── Effort ────────────────────────────────────────────────
              Text('⚔️ ${context.tr('effortDamage')}: $_effort',
                  style: Theme.of(context).textTheme.titleMedium),
              Slider(
                value: _effort.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                label: '$_effort',
                onChanged: (v) => setState(() => _effort = v.round()),
              ),
              const SizedBox(height: 8),

              // ── Repeat ────────────────────────────────────────────────
              DropdownButtonFormField<TaskRepeat>(
                initialValue: _repeat,
                decoration: InputDecoration(labelText: context.tr('repeat')),
                items: TaskRepeat.values
                    .map((r) => DropdownMenuItem(
                        value: r,
                        child: Text(r.name[0].toUpperCase() +
                            r.name.substring(1))))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _repeat = v;
                    // No longer force-switch date mode when repeat changes.
                    // Both scheduled and due date are valid for recurring tasks.
                  });
                },
              ),
              const SizedBox(height: 16),

              // ── Assignee ──────────────────────────────────────────────
              membersAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (members) => DropdownButtonFormField<String?>(
                  initialValue: _assigneeId,
                  decoration: InputDecoration(
                    labelText: context.tr('assignedToLabel'),
                    prefixIcon: const Icon(Icons.person_pin),
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(context.tr('noAssignee')),
                    ),
                    ...members.map((m) => DropdownMenuItem<String?>(
                          value: m.id,
                          child: Text(m.id == currentUid
                              ? '${m.name} (me)'
                              : m.name),
                        )),
                  ],
                  onChanged: (v) => setState(() => _assigneeId = v),
                ),
              ),
              const SizedBox(height: 20),

              // ── Date mode toggle ──────────────────────────────────────
              SegmentedButton<_DateMode>(
                segments: [
                  ButtonSegment(
                    value: _DateMode.scheduled,
                    label: Text(context.tr('scheduled')),
                    icon: const Icon(Icons.schedule, size: 16),
                  ),
                  ButtonSegment(
                    value: _DateMode.due,
                    label: Text(context.tr('dueDate')),
                    icon: const Icon(Icons.event, size: 16),
                  ),
                ],
                selected: {_dateMode},
                onSelectionChanged: (s) => setState(() {
                  _dateMode = s.first;
                  // Keep the picked date — user just changed the label,
                  // no need to force them to re-enter the same datetime.
                }),
                style: ButtonStyle(
                  iconSize: WidgetStateProperty.all(14),
                ),
              ),
              const SizedBox(height: 12),

              // ── Date picker ───────────────────────────────────────────
              InkWell(
                onTap: _pickDateTime,
                borderRadius: BorderRadius.circular(10),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: _dateMode == _DateMode.scheduled
                        ? '${context.tr('scheduledDateTime')} *'
                        : '${context.tr('dueDateDateTime')} *',
                    prefixIcon: Icon(_dateMode == _DateMode.scheduled
                        ? Icons.schedule
                        : Icons.event),
                    suffixIcon: _pickedDate != null
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () =>
                                setState(() => _pickedDate = null),
                          )
                        : const Icon(Icons.chevron_right),
                    border: const OutlineInputBorder(),
                    errorText:
                        _submitted && _pickedDate == null ? context.tr('required') : null,
                  ),
                  child: Text(
                    _pickedDate != null
                        ? fmt.format(_pickedDate!)
                        : context.tr('tapToSelect'),
                    style: TextStyle(
                      color: _pickedDate != null
                          ? Colors.white
                          : Colors.white38,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Reminder ──────────────────────────────────────────────
              DropdownButtonFormField<int?>(
                initialValue: _reminderMinutes,
                decoration: InputDecoration(
                  labelText: context.tr('reminder'),
                  prefixIcon: const Icon(Icons.notifications_outlined),
                ),
                items: _reminderOptions.entries
                    .map((e) => DropdownMenuItem<int?>(
                          value: e.value,
                          child: Text(context.tr(e.key)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _reminderMinutes = v),
              ),

              const SizedBox(height: 32),

              // ── Submit ────────────────────────────────────────────────
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(context.tr('createTaskBtn')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
