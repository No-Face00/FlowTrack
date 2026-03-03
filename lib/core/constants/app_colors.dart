import 'package:flutter/material.dart';

class AppColors {

  // ── Primary Gradient ──────────────────────

  static const Color midnight   = Color(0xFF00033D);

  static const Color deepBlue   = Color(0xFF0600AB);

  static const Color royalBlue  = Color(0xFF0033FF);

  static const Color violet     = Color(0xFF977DFF);

  static const Color softPink   = Color(0xFFFFCCF2);

  // ── Backgrounds ────────────────────────────

  static const Color bgLavender = Color(0xFFF0EEF8);

  static const Color white      = Color(0xFFFFFFFF);

  static const Color iconTile   = Color(0xFFEEF0FF);

  // ── Semantic ────────────────────────────────

  static const Color income     = Color(0xFF00C48C);

  static const Color expense    = Color(0xFFFF647C);

  // ── Text ────────────────────────────────────

  static const Color textDark   = Color(0xFF0A0A2E);

  static const Color textMid    = Color(0xFF3D3B6E);

  static const Color textMuted  = Color(0xFF7B78A8);

  // ── Gradients ───────────────────────────────

  static const LinearGradient heroGradient = LinearGradient(

    begin: Alignment.topLeft,

    end: Alignment.bottomRight,

    colors: [midnight, deepBlue, royalBlue, violet],

    stops: [0.0, 0.4, 0.72, 1.0],

  );

  static const LinearGradient buttonGradient = LinearGradient(

    begin: Alignment.topLeft,

    end: Alignment.bottomRight,

    colors: [royalBlue, violet],

  );

  static const LinearGradient aiCardGradient = LinearGradient(

    begin: Alignment.topLeft,

    end: Alignment.bottomRight,

    colors: [midnight, deepBlue],

  );

}