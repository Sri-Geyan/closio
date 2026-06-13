import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GlassThemeExtension extends ThemeExtension<GlassThemeExtension> {
  final Color baseColor;
  final double blurSigma;
  final Color borderColor;

  const GlassThemeExtension({
    required this.baseColor,
    required this.blurSigma,
    required this.borderColor,
  });

  @override
  ThemeExtension<GlassThemeExtension> copyWith({
    Color? baseColor,
    double? blurSigma,
    Color? borderColor,
  }) {
    return GlassThemeExtension(
      baseColor: baseColor ?? this.baseColor,
      blurSigma: blurSigma ?? this.blurSigma,
      borderColor: borderColor ?? this.borderColor,
    );
  }

  @override
  ThemeExtension<GlassThemeExtension> lerp(ThemeExtension<GlassThemeExtension>? other, double t) {
    if (other is! GlassThemeExtension) {
      return this;
    }
    return GlassThemeExtension(
      baseColor: Color.lerp(baseColor, other.baseColor, t) ?? baseColor,
      blurSigma: blurSigma + (other.blurSigma - blurSigma) * t,
      borderColor: Color.lerp(borderColor, other.borderColor, t) ?? borderColor,
    );
  }
}

class ClosioTheme {
  // Base constants - Swapped to Dark Monochromatic
  static const Color primaryColor = Color(0xFFFFFFFF);
  static const Color onPrimaryColor = Color(0xFF000000);
  static const Color secondaryColor = Color(0xFFA1A1A1);
  static const Color outlineColor = Color(0xFF5E5E5E);
  static const Color errorColor = Color(0xFFCF6679);

  // Dynamic Adaptive Theme (Now Forced Dark Theme)
  static ThemeData get adaptiveTheme {
    const isNight = true; // Forced Dark Theme

    const backgroundColor = Color(0xFF000000);
    const surfaceColor = Color(0xFF121212);
    const onSurfaceColor = Color(0xFFFFFFFF);
    const surfaceContainer = Color(0xFF2C2C2C);
    const primaryDynamic = Color(0xFFFFFFFF);
    const onPrimaryDynamic = Color(0xFF000000);

    final glassBase = Colors.black.withOpacity(0.5);
    final glassBorder = Colors.white.withOpacity(0.15);

    return ThemeData(
      useMaterial3: true,
      brightness: isNight ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme(
        brightness: isNight ? Brightness.dark : Brightness.light,
        primary: primaryDynamic,
        onPrimary: onPrimaryDynamic,
        secondary: secondaryColor,
        onSecondary: Colors.white,
        error: errorColor,
        onError: Colors.white,
        background: backgroundColor,
        onBackground: onSurfaceColor,
        surface: surfaceColor,
        onSurface: onSurfaceColor,
      ),
      scaffoldBackgroundColor: backgroundColor,
      extensions: [
        GlassThemeExtension(
          baseColor: glassBase,
          blurSigma: 12.0,
          borderColor: glassBorder,
        ),
      ],
      textTheme: GoogleFonts.interTextTheme(
        ThemeData(brightness: isNight ? Brightness.dark : Brightness.light).textTheme
      ).copyWith(
        // Humanized & Imperfect Types for standout elements (e.g., greetings, special quotes)
        displayLarge: GoogleFonts.kalam(fontSize: 48, fontWeight: FontWeight.w600, height: 1.1),
        
        // Geometric Sans-Serifs (Outfit) for clean, high-legibility headings
        displayMedium: GoogleFonts.outfit(fontSize: 36, fontWeight: FontWeight.w600, letterSpacing: -0.02, height: 1.2),
        headlineLarge: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w600, letterSpacing: -0.02, height: 1.2),
        headlineMedium: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w500, letterSpacing: -0.01, height: 1.4),
        titleLarge: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.01),
        titleMedium: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
        
        // DM Sans for Bento Grid Layout titles/labels (crisp and geometric)
        titleSmall: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600),
        
        // Inter for crisp legibility and space efficiency in UI elements and chat windows
        bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, height: 1.6),
        bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, height: 1.6),
        labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        labelMedium: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.02),
        labelSmall: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.05),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryDynamic,
          foregroundColor: onPrimaryDynamic,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryDynamic,
          side: const BorderSide(color: secondaryColor, width: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: backgroundColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: outlineColor.withOpacity(0.5), width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: outlineColor.withOpacity(0.5), width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryDynamic, width: 0.5),
        ),
      ),
    );
  }

  // Static colors mapped to forced dark theme
  static const Color backgroundColor = Color(0xFF000000);
  static const Color surfaceColor = Color(0xFF121212);
  static const Color onSurfaceColor = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFF1E1E1E);
  static const Color surfaceContainer = Color(0xFF2C2C2C);

  static ThemeData get lightTheme => adaptiveTheme; // Both light and adaptive map to dark
}
