import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../auth/providers/auth_providers.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/services/quota_guard.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isRegister = false;
  bool _loading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // If already logged in, redirect
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authStateProvider).valueOrNull;
      if (user != null && mounted) context.go('/home');
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':      return context.tr('errUserNotFound');
      case 'wrong-password':      return context.tr('errWrongPassword');
      case 'email-already-in-use':return context.tr('errEmailInUse');
      case 'weak-password':       return context.tr('errWeakPassword');
      case 'invalid-email':       return context.tr('errInvalidEmail');
      case 'too-many-requests':   return context.tr('errTooManyRequests');
      default:                    return e.message ?? context.tr('errGeneric');
    }
  }

  Future<void> _submitEmailAuth() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _errorMessage = null; });

    try {
      final service = ref.read(authServiceProvider);
      if (_isRegister) {
        await service.registerWithEmail(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        await service.signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
      if (mounted) context.go('/home');
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _errorMessage = _friendlyError(e));
    } catch (e) {
      // Free-plan quota exhausted (Firestore write on register/login) — alert.
      if (handleQuotaError(e, context: mounted ? context : null)) return;
      // Firestore write or other error — user is authenticated, still navigate
      if (mounted) context.go('/home');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitGoogle() async {
    setState(() { _loading = true; _errorMessage = null; });
    try {
      final user = await ref.read(authServiceProvider).signInWithGoogle();
      // null means the user cancelled the Google picker — do nothing
      if (user == null) return;
      if (mounted) context.go('/home');
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _errorMessage = _friendlyError(e));
    } catch (e) {
      // Free-plan quota exhausted while writing the user profile — alert.
      if (handleQuotaError(e, context: mounted ? context : null)) return;
      // Only navigate if we are actually authenticated
      final isSignedIn =
          ref.read(authStateProvider).valueOrNull != null;
      if (mounted && isSignedIn) context.go('/home');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = context.tr('enterEmailFirst'));
      return;
    }
    await ref.read(authServiceProvider).sendPasswordReset(email);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('passwordResetSent'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Language picker ──────────────────────────────────────
                  const Align(
                    alignment: Alignment.topRight,
                    child: _LanguageToggle(),
                  ),
                  const SizedBox(height: 8),

                  // ── Logo ─────────────────────────────────────────────
                  Image.asset(
                    'assets/images/Logo_white.png',
                    height: 180,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('loginTagline'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 36),

                  // ── Sign In / Register tabs ───────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _TabButton(
                          label: context.tr('signIn'),
                          selected: !_isRegister,
                          onTap: () => setState(() {
                            _isRegister = false;
                            _errorMessage = null;
                          }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _TabButton(
                          label: context.tr('register'),
                          selected: _isRegister,
                          onTap: () => setState(() {
                            _isRegister = true;
                            _errorMessage = null;
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Form ─────────────────────────────────────────────
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_isRegister) ...[
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: context.tr('fighterName'),
                              prefixIcon: const Icon(Icons.person_outline),
                            ),
                            textInputAction: TextInputAction.next,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? context.tr('enterName')
                                : null,
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: context.tr('email'),
                            prefixIcon: const Icon(Icons.email_outlined),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: (v) => (v == null || !v.contains('@'))
                              ? context.tr('enterValidEmail')
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: context.tr('password'),
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submitEmailAuth(),
                          validator: (v) => (v == null || v.length < 6)
                              ? context.tr('minChars')
                              : null,
                        ),

                        // Error message
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.withAlpha(30),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // ── Main CTA ──────────────────────────────────────
                        ElevatedButton(
                          onPressed: _loading ? null : _submitEmailAuth,
                          child: _loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(_isRegister ? context.tr('createAccount') : context.tr('signIn')),
                        ),

                        // Forgot password (sign in mode only)
                        if (!_isRegister) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _loading ? null : _forgotPassword,
                            child: Text(context.tr('forgotPassword'),
                                style: const TextStyle(color: Colors.white54)),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // ── Divider ───────────────────────────────────────────
                  const SizedBox(height: 20),
                  Row(children: [
                    const Expanded(child: Divider(color: Colors.white24)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(context.tr('orDivider'),
                          style: Theme.of(context).textTheme.labelSmall),
                    ),
                    const Expanded(child: Divider(color: Colors.white24)),
                  ]),
                  const SizedBox(height: 16),

                  // ── Google Sign-In ────────────────────────────────────
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Text('G',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                    label: Text(context.tr('continueWithGoogle'),
                        style: const TextStyle(color: Colors.white)),
                    onPressed: _loading ? null : _submitGoogle,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab button
// ─────────────────────────────────────────────────────────────────────────────

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF6C3CE1) : const Color(0xFF252540),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white54,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Language toggle
// ─────────────────────────────────────────────────────────────────────────────

class _LanguageToggle extends ConsumerWidget {
  const _LanguageToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final isEs = locale.languageCode == 'es';
    return TextButton.icon(
      icon: const Text('🌐', style: TextStyle(fontSize: 14)),
      label: Text(
        isEs ? 'ES' : 'EN',
        style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: () => ref.read(localeProvider.notifier).toggle(),
    );
  }
}
