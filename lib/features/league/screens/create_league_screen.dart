import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/league_model.dart';
import '../providers/league_providers.dart';
import '../../../core/services/quota_guard.dart';

// ════════════════════════════════════════════════════════════════════════════
// Entry screen: tabbed Create / Join
// ════════════════════════════════════════════════════════════════════════════

class CreateLeagueScreen extends ConsumerStatefulWidget {
  /// When [initialTab] is 1 the screen opens directly on the "Join" tab.
  final int initialTab;
  const CreateLeagueScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<CreateLeagueScreen> createState() => _CreateLeagueScreenState();
}

class _CreateLeagueScreenState extends ConsumerState<CreateLeagueScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('League'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.add_circle_outline), text: 'Create'),
            Tab(icon: Icon(Icons.group_add), text: 'Join'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _CreateTab(),
          _JoinTab(),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// CREATE tab
// ════════════════════════════════════════════════════════════════════════════

class _CreateTab extends ConsumerStatefulWidget {
  const _CreateTab();

  @override
  ConsumerState<_CreateTab> createState() => _CreateTabState();
}

class _CreateTabState extends ConsumerState<_CreateTab> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  CompetitionType _competitionType = CompetitionType.weekly;
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null || uid.isEmpty) {
      setState(() => _errorMessage = 'Not logged in. Please sign in again.');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(leagueRepositoryProvider);
      final league = await repo.createLeague(
        name: _nameController.text.trim(),
        ownerId: uid,
        competitionType: _competitionType,
      );
      if (mounted) context.go('/league/${league.id}');
    } catch (e) {
      if (handleQuotaError(e, context: mounted ? context : null)) return;
      if (mounted) setState(() => _errorMessage = 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'League name',
                prefixIcon: Icon(Icons.shield),
                hintText: 'e.g. Thunder Squad',
              ),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
            ),
            const SizedBox(height: 24),
            Text(
              'Competition cycle',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SegmentedButton<CompetitionType>(
              segments: const [
                ButtonSegment(
                    value: CompetitionType.weekly, label: Text('Weekly')),
                ButtonSegment(
                    value: CompetitionType.monthly, label: Text('Monthly')),
              ],
              selected: {_competitionType},
              onSelectionChanged: (s) =>
                  setState(() => _competitionType = s.first),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.redAccent),
                textAlign: TextAlign.center,
              ),
            ],
            const Spacer(),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Create League'),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// JOIN tab
// ════════════════════════════════════════════════════════════════════════════

class _JoinTab extends ConsumerStatefulWidget {
  const _JoinTab();

  @override
  ConsumerState<_JoinTab> createState() => _JoinTabState();
}

class _JoinTabState extends ConsumerState<_JoinTab> {
  final _codeController = TextEditingController();
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Please enter an invite code.');
      return;
    }

    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null || uid.isEmpty) {
      setState(() => _errorMessage = 'Not logged in. Please sign in again.');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(leagueRepositoryProvider);
      final league = await repo.joinByCode(code, uid);
      if (!mounted) return;
      if (league == null) {
        setState(() => _errorMessage =
            'No league found with that code.\nCheck the code and try again.');
      } else {
        context.go('/league/${league.id}');
      }
    } catch (e) {
      if (handleQuotaError(e, context: mounted ? context : null)) return;
      if (mounted) setState(() => _errorMessage = 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          // ── Hero illustration ──────────────────────────────────────────
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF6C3CE1).withAlpha(40),
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFF6C3CE1).withAlpha(120), width: 2),
              ),
              child: const Icon(Icons.group_add,
                  size: 38, color: Color(0xFFB39DDB)),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Enter the invite code shared by your league leader:',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 24),
          // ── Code input ─────────────────────────────────────────────────
          TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            textAlign: TextAlign.center,
            maxLength: 12,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 10,
              color: Color(0xFFB39DDB),
            ),
            decoration: InputDecoration(
              hintText: 'A1B2C3',
              hintStyle: const TextStyle(
                fontSize: 28,
                letterSpacing: 10,
                color: Colors.white24,
                fontWeight: FontWeight.bold,
              ),
              counterText: '',
              errorText: _errorMessage,
              errorMaxLines: 3,
              prefixIcon: const Icon(Icons.tag),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onSubmitted: (_) => _join(),
          ),
          const SizedBox(height: 28),
          // ── Submit button ──────────────────────────────────────────────
          FilledButton.icon(
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.login),
            label: const Text('Join League'),
            onPressed: _loading ? null : _join,
          ),
          const Spacer(),
          // ── Hint ───────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.info_outline,
                  size: 14, color: Colors.white38),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Invite codes are 6 characters, e.g. "A1B2C3"',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white38),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
