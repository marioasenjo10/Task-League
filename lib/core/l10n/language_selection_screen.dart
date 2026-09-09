import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'locale_provider.dart';

/// Full-screen language picker shown on the very first launch (before login),
/// when no language has been chosen yet. Uses large flag buttons instead of a
/// small EN/ES toggle so it is obvious — especially for older users. Once a
/// language is selected the whole app (login included) renders in it.
class LanguageSelectionScreen extends ConsumerWidget {
  const LanguageSelectionScreen({super.key});

  void _choose(WidgetRef ref, Locale locale) {
    ref.read(localeProvider.notifier).setLocale(locale);
    ref.read(languageChosenProvider.notifier).state = true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF6C3CE1).withAlpha(35),
                    ),
                    child: const Icon(Icons.translate_rounded,
                        color: Color(0xFFB39DDB), size: 44),
                  ),
                  const SizedBox(height: 28),
                  // Bilingual heading — the user hasn't chosen a language yet.
                  const Text(
                    'Select your language',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Selecciona tu idioma',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 36),
                  _LanguageOption(
                    flag: const _UkFlag(),
                    label: 'English',
                    onTap: () => _choose(ref, const Locale('en')),
                  ),
                  const SizedBox(height: 16),
                  _LanguageOption(
                    flag: const _SpainFlag(),
                    label: 'Español',
                    onTap: () => _choose(ref, const Locale('es')),
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

class _LanguageOption extends StatelessWidget {
  final Widget flag;
  final String label;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.flag,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withAlpha(25)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  width: 42,
                  height: 28,
                  child: flag,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: Colors.white38, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Flags drawn with CustomPainter — emoji flags don't render on web/Windows,
// so we paint them to guarantee they show everywhere.
// ─────────────────────────────────────────────────────────────────────────────

class _SpainFlag extends StatelessWidget {
  const _SpainFlag();

  @override
  Widget build(BuildContext context) {
    // Simplified Spanish flag: red / yellow (double height) / red bands.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: const [
        Expanded(flex: 1, child: ColoredBox(color: Color(0xFFAA151B))),
        Expanded(flex: 2, child: ColoredBox(color: Color(0xFFF1BF00))),
        Expanded(flex: 1, child: ColoredBox(color: Color(0xFFAA151B))),
      ],
    );
  }
}

class _UkFlag extends StatelessWidget {
  const _UkFlag();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _UnionJackPainter());
  }
}

class _UnionJackPainter extends CustomPainter {
  static const _blue = Color(0xFF012169);
  static const _red = Color(0xFFC8102E);
  static const _white = Color(0xFFFFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Rect.fromLTWH(0, 0, w, h);

    // Blue background
    canvas.drawRect(rect, Paint()..color = _blue);

    canvas.save();
    canvas.clipRect(rect);

    // Diagonals — white (thick) then red (thin) approximating the saltires.
    final whiteDiag = Paint()
      ..color = _white
      ..strokeWidth = h * 0.30
      ..style = PaintingStyle.stroke;
    final redDiag = Paint()
      ..color = _red
      ..strokeWidth = h * 0.12
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(0, 0), Offset(w, h), whiteDiag);
    canvas.drawLine(Offset(w, 0), Offset(0, h), whiteDiag);
    canvas.drawLine(Offset(0, 0), Offset(w, h), redDiag);
    canvas.drawLine(Offset(w, 0), Offset(0, h), redDiag);

    // Central cross — white border then red on top.
    final whiteCrossV = Rect.fromLTWH(w / 2 - h * 0.19, 0, h * 0.38, h);
    final whiteCrossH = Rect.fromLTWH(0, h / 2 - h * 0.19, w, h * 0.38);
    canvas.drawRect(whiteCrossV, Paint()..color = _white);
    canvas.drawRect(whiteCrossH, Paint()..color = _white);

    final redCrossV = Rect.fromLTWH(w / 2 - h * 0.11, 0, h * 0.22, h);
    final redCrossH = Rect.fromLTWH(0, h / 2 - h * 0.11, w, h * 0.22);
    canvas.drawRect(redCrossV, Paint()..color = _red);
    canvas.drawRect(redCrossH, Paint()..color = _red);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
