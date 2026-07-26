import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand & Stitch Color Tokens
  static const Color primary = Color(0xFF2563EB); // Primary Blue (#2563EB / #004AC6)
  static const Color primaryVariant = Color(0xFF004AC6);
  static const Color primaryContainer = Color(0xFF2563EB);
  static const Color onPrimaryContainer = Color(0xFFEEEFFF);
  
  static const Color secondaryAccent = Color(0xFFFF6B5B); // Coral / Warm Accent
  static const Color secondaryContainer = Color(0xFFDEE0E2);
  static const Color tertiary = Color(0xFF943700);
  static const Color tertiaryContainer = Color(0xFFBC4800);
  
  static const Color background = Color(0xFFFAF8FF); // Soft canvas background (#FAF8FF / #FFFFFF)
  static const Color surface = Color(0xFFFFFFFF); // Pure White Surface
  static const Color surfaceContainerLow = Color(0xFFF3F3FE);
  static const Color surfaceContainer = Color(0xFFEDEDF9);
  static const Color surfaceContainerHigh = Color(0xFFE7E7F3);
  static const Color surfaceContainerHighest = Color(0xFFE1E2ED);
  
  // Text & Ink Colors
  static const Color textPrimary = Color(0xFF191B23); // High-contrast ink
  static const Color textSecondary = Color(0xFF434655); // Secondary metadata ink
  static const Color textVariant = Color(0xFF737686);
  
  // Outlines & Dividers
  static const Color hairline = Color(0xFFC3C6D7); // 1px border stroke
  static const Color outline = Color(0xFF737686);
  static const Color outlineVariant = Color(0xFFC3C6D7);
  
  // Functional Colors
  static const Color chipBackground = Color(0xFFF3F3FE);
  static const Color userBubbleBackground = Color(0x1A2563EB);
  static const Color systemBubbleBackground = Color(0x1A434655);
  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);

  // Spacing & Grid System
  static const double containerPadding = 20.0;
  static const double sectionGap = 32.0;
  static const double elementGap = 16.0;
  static const double stackSm = 8.0;
  static const double stackMd = 16.0;
  static const double stackLg = 32.0;
  static const double stackXl = 64.0;
  static const double hairlineWeight = 1.0;

  // Stitch Shape Radii
  static const double radiusSm = 12.0; // Chips & Badges
  static const double radiusMd = 18.0; // Buttons & Text Fields (Squircle)
  static const double radiusLg = 24.0; // Primary Cards & Containers
  static const double radiusFull = 9999.0;

  // Plus Jakarta Sans Font Family
  static const String fontFamily = 'Plus Jakarta Sans';

  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: secondaryAccent,
        surface: surface,
        error: error,
        onPrimary: Colors.white,
        onSurface: textPrimary,
      ),
      fontFamily: fontFamily,
      fontFamilyFallback: const ['Inter', 'Roboto', 'sans-serif'],
      textTheme: GoogleFonts.plusJakartaSansTextTheme(),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: hairline,
        thickness: hairlineWeight,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: hairline, width: hairlineWeight),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: textPrimary,
          elevation: 0,
          minimumSize: const Size(double.infinity, 56),
          side: const BorderSide(color: hairline, width: hairlineWeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
    );
  }
}
