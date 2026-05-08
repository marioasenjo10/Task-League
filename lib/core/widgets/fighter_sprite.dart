import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public widget: drop-in replacement for emoji fighter icons.
// Skins with PNG assets use Image.asset; others fall back to CustomPaint.
// ─────────────────────────────────────────────────────────────────────────────

/// Pose used to select the correct PNG for skins that have assets.
enum FighterPose { idle, attack, hit, ko }

class FighterSprite extends StatelessWidget {
  final String skin;
  final double size;
  final bool isKO;
  final FighterPose pose;

  const FighterSprite({
    super.key,
    required this.skin,
    this.size = 80,
    this.isKO = false,
    this.pose = FighterPose.idle,
  });

  /// Skins that have real PNG assets under assets/images/fighters/<skin>/
  static const Set<String> _pngSkins = {
    'boxingtiger',
    'death',
    'doctor',
    'mage',
    'masked_fighter',
    'masked_woman',
    'ninja',
    'thunderman',
    'viking',
    'warrior',
  };

  /// Fraction of [size] that is transparent *below* the character's feet
  /// in the idle PNG.  Tune each value by eye once the assets are final.
  /// 0.0 = feet are at the very bottom of the image (no padding).
  /// 0.12 = ~12 % of the image height is empty space below the feet.
  static const Map<String, double> feetPaddingFraction = {
    'warrior': 0.04,
    'mage': 0.04,
    'ninja': 0.04,
    'masked_fighter': 0.04,
    'masked_woman': 0.04,
    'viking': 0.15, // viking PNG has more transparent space below feet
    'boxingtiger': 0.04,
    'death': 0.04,
    'doctor': 0.04,
    'thunderman': 0.04,
  };

  String get _effectivePose {
    if (isKO) return 'ko';
    return pose.name;
  }

  // Path now uses a subfolder per character
  String get _assetPath =>
      'assets/images/fighters/$skin/${skin}_$_effectivePose.png';

  // ── Skin registry ──────────────────────────────────────────────────────────
  static const Map<String, FighterSkinDef> skins = {
    'warrior': FighterSkinDef(
      label: 'Warrior',
      bodyColor: Color(0xFF1565C0),
      shortsColor: Color(0xFFB71C1C),
      beltColor: Color(0xFFFFD600),
    ),
    'mage': FighterSkinDef(
      label: 'Mage',
      bodyColor: Color(0xFF6A1B9A),
      shortsColor: Color(0xFF4A148C),
      beltColor: Color(0xFF80CBC4),
    ),
    'ninja': FighterSkinDef(
      label: 'Ninja',
      bodyColor: Color(0xFF212121),
      shortsColor: Color(0xFF37474F),
      beltColor: Color(0xFFE53935),
    ),
    'masked_fighter': FighterSkinDef(
      label: 'Masked Fighter',
      bodyColor: Color(0xFF880E4F),
      shortsColor: Color(0xFF4A148C),
      beltColor: Color(0xFFFFD600),
    ),
    'masked_woman': FighterSkinDef(
      label: 'Masked Woman',
      bodyColor: Color(0xFF00695C),
      shortsColor: Color(0xFF004D40),
      beltColor: Color(0xFFFF80AB),
    ),
    'viking': FighterSkinDef(
      label: 'Viking',
      bodyColor: Color(0xFF4E342E),
      shortsColor: Color(0xFF3E2723),
      beltColor: Color(0xFFFFD600),
    ),
    'boxingtiger': FighterSkinDef(
      label: 'Boxing Tiger',
      bodyColor: Color(0xFFE65100),
      shortsColor: Color(0xFF212121),
      beltColor: Color(0xFFFFD600),
    ),
    'death': FighterSkinDef(
      label: 'Death',
      bodyColor: Color(0xFF212121),
      shortsColor: Color(0xFF1A1A1A),
      beltColor: Color(0xFF9E9E9E),
    ),
    'doctor': FighterSkinDef(
      label: 'Doctor',
      bodyColor: Color(0xFFECEFF1),
      shortsColor: Color(0xFF1565C0),
      beltColor: Color(0xFFE53935),
    ),
    'thunderman': FighterSkinDef(
      label: 'Thunderman',
      bodyColor: Color(0xFF1A237E),
      shortsColor: Color(0xFF311B92),
      beltColor: Color(0xFFFFD600),
    ),
  };

  static List<String> get skinKeys => skins.keys.toList();

  /// How many pixels of transparent space sit below this skin's feet
  /// for a sprite rendered at [size].
  double feetPaddingPixels(double size) =>
      size * (feetPaddingFraction[skin] ?? 0.04);

  @override
  Widget build(BuildContext context) {
    if (_pngSkins.contains(skin)) {
      return SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          _assetPath,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stack) {
            debugPrint('FighterSprite: failed [$_assetPath]');
            return Image.asset(
              'assets/images/fighters/$skin/${skin}_idle.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error2, stack2) {
                debugPrint('FighterSprite: idle fallback failed for skin=$skin');
                return _buildPainted();
              },
            );
          },
        ),
      );
    }
    return _buildPainted();
  }

  Widget _buildPainted() => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: FighterPainter(
            def: skins[skin] ?? skins['warrior']!,
            isKO: isKO,
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Skin definition
// ─────────────────────────────────────────────────────────────────────────────

class FighterSkinDef {
  final String label;
  final Color bodyColor;
  final Color shortsColor;
  final Color beltColor;

  const FighterSkinDef({
    required this.label,
    required this.bodyColor,
    required this.shortsColor,
    required this.beltColor,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Painter — draws a cartoon fighter character
// ─────────────────────────────────────────────────────────────────────────────

class FighterPainter extends CustomPainter {
  final FighterSkinDef def;
  final bool isKO;
  const FighterPainter({required this.def, required this.isKO});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..style = PaintingStyle.fill;

    // ── Legs ─────────────────────────────────────────────────────────────────
    paint.color = def.shortsColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.28, h * 0.62, w * 0.17, h * 0.32),
          const Radius.circular(6)),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.55, h * 0.62, w * 0.17, h * 0.32),
          const Radius.circular(6)),
      paint,
    );
    // Boots
    paint.color = const Color(0xFF212121);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.26, h * 0.87, w * 0.21, h * 0.10),
          const Radius.circular(4)),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.53, h * 0.87, w * 0.21, h * 0.10),
          const Radius.circular(4)),
      paint,
    );

    // ── Shorts ───────────────────────────────────────────────────────────────
    paint.color = def.shortsColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.24, h * 0.52, w * 0.52, h * 0.18),
          const Radius.circular(4)),
      paint,
    );

    // ── Belt ─────────────────────────────────────────────────────────────────
    paint.color = def.beltColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.24, h * 0.52, w * 0.52, h * 0.07),
          const Radius.circular(3)),
      paint,
    );
    paint.color = Colors.white.withAlpha(200);
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(w * 0.50, h * 0.555),
          width: w * 0.10,
          height: h * 0.06),
      paint,
    );

    // ── Torso ────────────────────────────────────────────────────────────────
    paint.color = def.bodyColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.22, h * 0.28, w * 0.56, h * 0.26),
          const Radius.circular(8)),
      paint,
    );
    // Chest emblem
    paint.color = Colors.white.withAlpha(55);
    canvas.drawCircle(Offset(w * 0.50, h * 0.38), w * 0.08, paint);
    paint.color = def.beltColor.withAlpha(200);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.5;
    canvas.drawCircle(Offset(w * 0.50, h * 0.38), w * 0.06, paint);
    paint.style = PaintingStyle.fill;

    // ── Arms ─────────────────────────────────────────────────────────────────
    paint.color = def.bodyColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.06, isKO ? h * 0.30 : h * 0.28, w * 0.16,
              h * 0.24),
          const Radius.circular(6)),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.78, isKO ? h * 0.30 : h * 0.24, w * 0.16,
              h * 0.24),
          const Radius.circular(6)),
      paint,
    );
    // Gloves
    paint.color = const Color(0xFFB71C1C);
    canvas.drawCircle(
        Offset(w * 0.14, isKO ? h * 0.58 : h * 0.52), w * 0.09, paint);
    canvas.drawCircle(
        Offset(w * 0.86, isKO ? h * 0.52 : h * 0.46), w * 0.09, paint);

    // ── Head ─────────────────────────────────────────────────────────────────
    // Neck
    paint.color = const Color(0xFFFFCC80);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.43, h * 0.18, w * 0.14, h * 0.12),
          const Radius.circular(4)),
      paint,
    );
    // Head oval
    canvas.drawOval(Rect.fromLTWH(w * 0.30, h * 0.02, w * 0.40, h * 0.20),
        paint);
    // Hair
    paint.color = def.bodyColor.withAlpha(200);
    canvas.drawOval(
        Rect.fromLTWH(w * 0.30, h * 0.02, w * 0.40, h * 0.09), paint);
    // Eyes whites
    paint.color = Colors.white;
    canvas.drawCircle(Offset(w * 0.42, h * 0.10), w * 0.045, paint);
    canvas.drawCircle(Offset(w * 0.58, h * 0.10), w * 0.045, paint);
    paint.color = Colors.black87;
    canvas.drawCircle(Offset(w * 0.43, h * 0.10), w * 0.025, paint);
    canvas.drawCircle(Offset(w * 0.59, h * 0.10), w * 0.025, paint);

    if (isKO) {
      // × eyes
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 1.5;
      canvas.drawLine(Offset(w * 0.395, h * 0.085),
          Offset(w * 0.445, h * 0.115), paint);
      canvas.drawLine(Offset(w * 0.445, h * 0.085),
          Offset(w * 0.395, h * 0.115), paint);
      canvas.drawLine(Offset(w * 0.565, h * 0.085),
          Offset(w * 0.615, h * 0.115), paint);
      canvas.drawLine(Offset(w * 0.615, h * 0.085),
          Offset(w * 0.565, h * 0.115), paint);
      paint.style = PaintingStyle.fill;
    }

    // Mouth
    paint.color = Colors.brown.shade700;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.5;
    if (isKO) {
      final path = Path()
        ..moveTo(w * 0.42, h * 0.155)
        ..quadraticBezierTo(w * 0.50, h * 0.14, w * 0.58, h * 0.155);
      canvas.drawPath(path, paint);
    } else {
      canvas.drawLine(
          Offset(w * 0.43, h * 0.145), Offset(w * 0.57, h * 0.145), paint);
    }
    paint.style = PaintingStyle.fill;
  }

  @override
  bool shouldRepaint(FighterPainter old) =>
      old.def != def || old.isKO != isKO;
}
