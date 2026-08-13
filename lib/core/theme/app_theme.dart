import 'package:flutter/material.dart';

/// Detective Byte palette — dark charcoal UI + warm fox character.
abstract final class AppTheme {
  // Desktop / page backgrounds
  static const Color desktopSky = Color(0xFFD8E2EC);
  static const Color desktopDesk = Color(0xFFC4B8A8);
  static const Color parchment = Color(0xFFF3EEE6);
  static const Color parchmentDark = Color(0xFFE4D9C8);

  // Dark floating widgets (exact mockup style)
  static const Color panel = Color(0xFF1E1E1E);
  static const Color panelElevated = Color(0xFF2A2A2A);
  static const Color panelBorder = Color(0xFF3A3A3A);
  static const Color panelText = Color(0xFFF2F2F2);
  static const Color panelMuted = Color(0xFF9A9A9A);

  // Accents
  static const Color accentGreen = Color(0xFF3DDC84);
  static const Color accentGreenDim = Color(0xFF2A9F5F);
  static const Color amber = Color(0xFFE8A85C);
  static const Color foxOrange = Color(0xFFF08A3C);
  static const Color foxCream = Color(0xFFFFF1DF);
  static const Color coatBrown = Color(0xFF6B4A32);
  static const Color coatDark = Color(0xFF3E2A1C);
  static const Color ink = Color(0xFF2B2118);
  static const Color inkSoft = Color(0xFF6B5344);
  static const Color shadow = Color(0x66000000);

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: parchment,
      colorScheme: ColorScheme.fromSeed(
        seedColor: coatBrown,
        brightness: Brightness.light,
        surface: parchment,
        onSurface: ink,
        primary: accentGreen,
      ),
      fontFamily: 'Segoe UI',
      textTheme: const TextTheme(
        bodyMedium: TextStyle(
          color: ink,
          fontSize: 15,
          height: 1.4,
          fontWeight: FontWeight.w400,
        ),
        titleMedium: TextStyle(
          color: ink,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        titleSmall: TextStyle(
          color: panelText,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        labelLarge: TextStyle(
          color: inkSoft,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        labelMedium: TextStyle(
          color: panelMuted,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return const Color(0xFFBDBDBD);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accentGreen;
          return const Color(0xFF555555);
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accentGreen,
        inactiveTrackColor: const Color(0xFF555555),
        thumbColor: Colors.white,
        overlayColor: accentGreen.withValues(alpha: 0.2),
        trackHeight: 4,
      ),
    );
  }

  static BoxDecoration get desktopBackground => const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFE8F0F6),
            desktopSky,
            Color(0xFFCDD8E4),
            desktopDesk,
          ],
          stops: [0.0, 0.35, 0.72, 1.0],
        ),
      );

  static BoxDecoration get darkPanel => BoxDecoration(
        color: panel.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: panelBorder.withValues(alpha: 0.8)),
        boxShadow: const [
          BoxShadow(
            color: shadow,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      );

  static BoxShadow get softShadow => const BoxShadow(
        color: shadow,
        blurRadius: 16,
        offset: Offset(0, 6),
      );
}
