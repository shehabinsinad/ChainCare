import 'package:flutter/material.dart';

/// ChainCare Premium Color Palette
/// Medical-grade colors with sophisticated teal accent
class AppColors {
  AppColors._();

  // ═══════════════════════════════════════════════════════════════
  // PRIMARY COLORS (Medical Teal Theme)
  // ═══════════════════════════════════════════════════════════════
  
  /// Primary brand color - Medical Teal
  static const Color primary = Color(0xFF009688);
  
  /// Darker variant for depth and emphasis
  static const Color primaryDark = Color(0xFF00796B);
  
  /// Lighter variant for backgrounds and hover states
  static const Color primaryLight = Color(0xFF4DB6AC);
  
  /// Very light teal for subtle backgrounds
  static const Color primaryVeryLight = Color(0xFFE0F2F1);

  // ═══════════════════════════════════════════════════════════════
  // NEUTRAL PALETTE
  // ═══════════════════════════════════════════════════════════════
  
  /// Pure white - Main background
  static const Color white = Color(0xFFFFFFFF);
  
  /// Off-white - Secondary background
  static const Color offWhite = Color(0xFFF8F9FA);
  
  /// Soft gray - Borders, dividers
  static const Color softGray = Color(0xFFE8EAED);
  
  /// Medium gray - Secondary text
  static const Color mediumGray = Color(0xFF5F6368);
  
  /// Deep charcoal - Primary text
  static const Color deepCharcoal = Color(0xFF202124);
  
  /// Light gray - Disabled states
  static const Color lightGray = Color(0xFFF1F3F4);

  // ═══════════════════════════════════════════════════════════════
  // ACCENT COLORS (Semantic)
  // ═══════════════════════════════════════════════════════════════
  
  /// Success green - Verified status, positive indicators
  static const Color success = Color(0xFF34A853);
  static const Color successLight = Color(0xFFE6F4EA);
  
  /// Warning amber - Pending actions, caution
  static const Color warning = Color(0xFFFBBC04);
  static const Color warningLight = Color(0xFFFEF7E0);
  
  /// Error red - Critical alerts, errors
  static const Color error = Color(0xFFEA4335);
  static const Color errorLight = Color(0xFFFCE8E6);
  
  /// Info blue - Information, links
  static const Color info = Color(0xFF4285F4);
  static const Color infoLight = Color(0xFFE8F0FE);

  // ═══════════════════════════════════════════════════════════════
  // GRADIENT DEFINITIONS
  // ═══════════════════════════════════════════════════════════════
  
  /// Primary gradient for buttons and important CTAs
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );
  
  /// Subtle background gradient
  static const LinearGradient subtleBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [white, offWhite],
  );
  
  /// Card shimmer effect for premium feel
  static LinearGradient get cardShimmer => LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      primary.withOpacity(0.1),
      primary.withOpacity(0.05),
      primary.withOpacity(0.1),
    ],
  );
  
  /// Success gradient
  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF34A853), Color(0xFF2D8E47)],
  );
  
  /// Error gradient
  static const LinearGradient errorGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEA4335), Color(0xFFD93025)],
  );

  // ═══════════════════════════════════════════════════════════════
  // SHADOW COLORS
  // ═══════════════════════════════════════════════════════════════
  
  /// Soft shadow for cards
  static Color get shadowSoft => Colors.black.withOpacity(0.04);
  
  /// Medium shadow for elevated elements
  static Color get shadowMedium => Colors.black.withOpacity(0.08);
  
  /// Strong shadow for floating elements
  static Color get shadowStrong => Colors.black.withOpacity(0.12);

  // ═══════════════════════════════════════════════════════════════
  // GLASSMORPHISM EFFECTS
  // ═══════════════════════════════════════════════════════════════
  
  /// Glass background with transparency
  static Color get glassBackground => white.withOpacity(0.7);
  
  /// Glass border
  static Color get glassBorder => white.withOpacity(0.2);
}
