import 'package:flutter/material.dart';

/// Bundled font families (declared in pubspec, loaded from fonts/*.ttf).
const String _fredoka = 'Fredoka';
const String _nunito = 'Nunito';

/// Design tokens taken directly from the redesign source (Xylophone.dc.html):
/// Fredoka for display text, Nunito for small uppercase labels, and a soft
/// peach→lilac palette.
class AppTheme {
  AppTheme._();

  // Ink & surfaces.
  static const Color ink = Color(0xFF473B5C);
  static const Color subtitle = Color(0xFF9A8DB0);
  static const Color inkSoft = subtitle; // alias used by the sheets
  static const Color card = Colors.white;
  static const Color accent = Color(0xFF8157C9); // purple accent
  static const Color pillIcon = Color(0xFF8B79B5);
  static const Color pillTint = Color(0xFFF3EDFA);
  static const Color octaveLabelTop = Color(0xFFB6A9CC);
  static const Color octaveLabel = Color(0xFF5E4F7D);

  // Slider.
  static const Color sliderTrack = Color(0xFFEADFF0);
  static const Color sliderThumbBorder = Color(0xFFB89BE8);

  // Record strip.
  static const Color recIdleBg = Color(0xFFFFE3E8);
  static const Color recActiveBg = Color(0xFFFF6B81);
  static const Color playBtnBg = Color(0xFFF3EDFA);
  static const Color playBtnFg = Color(0xFF8157C9);
  static const Color stripBg = Color(0xFFFAF6FF);
  static const Color hint = Color(0xFFB3A6C9);
  static const Color clearIcon = Color(0xFFC9BCDB);

  /// Full-screen background gradient (170deg in the source ≈ top→bottom).
  static const LinearGradient background = LinearGradient(
    begin: Alignment(-0.5, -1),
    end: Alignment(0.5, 1),
    colors: [Color(0xFFFFF7F1), Color(0xFFFBF3FA), Color(0xFFF1ECFB)],
    stops: [0.0, 0.52, 1.0],
  );

  /// The pink→purple glyph gradient (150deg).
  static const LinearGradient glyphGradient = LinearGradient(
    begin: Alignment(-0.6, -1),
    end: Alignment(0.6, 1),
    colors: [Color(0xFFFFB3C1), Color(0xFFB89BE8)],
  );

  /// Panel that holds the bars.
  static const LinearGradient panelGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.white, Color(0xFFFBF6FF)],
  );

  static const Color shadowTint = Color(0xFF785AA0); // rgba(120,90,160)

  static List<BoxShadow> glyphShadow() => [
        BoxShadow(
          color: const Color(0xFF966EC8).withValues(alpha: 0.35),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> headerBtnShadow() => [
        BoxShadow(
          color: shadowTint.withValues(alpha: 0.14),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> pillShadow() => [
        BoxShadow(
          color: shadowTint.withValues(alpha: 0.12),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> panelShadow() => [
        BoxShadow(
          color: shadowTint.withValues(alpha: 0.16),
          blurRadius: 34,
          offset: const Offset(0, 14),
        ),
      ];

  static List<BoxShadow> recordStripShadow() => [
        BoxShadow(
          color: shadowTint.withValues(alpha: 0.16),
          blurRadius: 22,
          offset: const Offset(0, 8),
        ),
      ];

  static ThemeData themeData() {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFFFBF3FA),
      colorScheme: base.colorScheme.copyWith(primary: sliderThumbBorder),
      textTheme: base.textTheme
          .apply(fontFamily: _fredoka, bodyColor: ink, displayColor: ink),
    );
  }

  static TextStyle title() => const TextStyle(
        fontFamily: _fredoka,
        fontSize: 23,
        fontWeight: FontWeight.w700,
        color: ink,
        letterSpacing: -0.3,
        height: 1.0,
      );

  /// Small uppercase section label used by the settings sheet.
  static TextStyle overline() => nunitoLabel(
        size: 10,
        weight: FontWeight.w700,
        color: octaveLabelTop,
        spacing: 1.4,
      );

  /// Nunito uppercase label (e.g. "TAP · PLAY · RECORD", "OCTAVE").
  static TextStyle nunitoLabel({
    double size = 11.5,
    FontWeight weight = FontWeight.w500,
    Color color = subtitle,
    double spacing = 1.5,
  }) =>
      TextStyle(
        fontFamily: _nunito,
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: spacing,
        height: 1.0,
      );
}
