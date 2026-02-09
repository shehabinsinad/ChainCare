import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// ChainCare Premium Typography System
/// Inter font family with clear hierarchy for medical readability
class AppTextStyles {
  AppTextStyles._();

  // ═══════════════════════════════════════════════════════════════
  // DISPLAY STYLES (Large headers, dashboard titles)
  // ═══════════════════════════════════════════════════════════════
  
  /// Display Large - 32px, weight 700, for main dashboard headers
  static TextStyle get displayLarge => GoogleFonts.inter(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: AppColors.deepCharcoal,
    height: 1.2,
  );
  
  /// Display Medium - 28px, weight 700
  static TextStyle get displayMedium => GoogleFonts.inter(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.25,
    color: AppColors.deepCharcoal,
    height: 1.2,
  );

  // ═══════════════════════════════════════════════════════════════
  // TITLE STYLES (Section headings, card titles)
  // ═══════════════════════════════════════════════════════════════
  
  /// Title Large - 24px, weight 600, for section titles
  static TextStyle get titleLarge => GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.25,
    color: AppColors.deepCharcoal,
    height: 1.3,
  );
  
  /// Title Medium - 20px, weight 600, for card headers
  static TextStyle get titleMedium => GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.deepCharcoal,
    height: 1.4,
  );
  
  /// Title Small - 18px, weight 600
  static TextStyle get titleSmall => GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.deepCharcoal,
    height: 1.4,
  );

  // ═══════════════════════════════════════════════════════════════
  // BODY STYLES (Main content, descriptions)
  // ═══════════════════════════════════════════════════════════════
  
  /// Body Large - 16px, weight 400, for main content
  static TextStyle get bodyLarge => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.deepCharcoal,
    height: 1.6,
  );
  
  /// Body Medium - 14px, weight 400, for secondary content
  static TextStyle get bodyMedium => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.mediumGray,
    height: 1.5,
  );
  
  /// Body Small - 13px, weight 400
  static TextStyle get bodySmall => GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.mediumGray,
    height: 1.5,
  );

  // ═══════════════════════════════════════════════════════════════
  // LABEL STYLES (Tags, categories, buttons)
  // ═══════════════════════════════════════════════════════════════
  
  /// Label Large - 14px, weight 500, for prominent labels
  static TextStyle get labelLarge => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.deepCharcoal,
    letterSpacing: 0.1,
  );
  
  /// Label Medium - 12px, weight 500, uppercase for tags
  static TextStyle get labelMedium => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.mediumGray,
    letterSpacing: 0.5,
  );
  
  /// Label Small - 11px, weight 500
  static TextStyle get labelSmall => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.mediumGray,
    letterSpacing: 0.5,
  );

  // ═══════════════════════════════════════════════════════════════
  // CAPTION STYLES (Timestamps, metadata, helper text)
  // ═══════════════════════════════════════════════════════════════
  
  /// Caption - 11px, weight 400, for timestamps and metadata
  static TextStyle get caption => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppColors.mediumGray,
    height: 1.3,
  );

  // ═══════════════════════════════════════════════════════════════
  // BUTTON STYLES
  // ═══════════════════════════════════════════════════════════════
  
  /// Button Large - 16px, weight 600, for primary buttons
  static TextStyle get buttonLarge => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );
  
  /// Button Medium - 14px, weight 600
  static TextStyle get buttonMedium => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );
  
  /// Button Small - 13px, weight 600
  static TextStyle get buttonSmall => GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  // ═══════════════════════════════════════════════════════════════
  // MONOSPACE STYLES (Medical codes, IDs, technical data)
  // ═══════════════════════════════════════════════════════════════
  
  /// Monospace Medium - for medical codes and IDs
  static TextStyle get monospaceMedium => GoogleFonts.jetBrainsMono(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.deepCharcoal,
    letterSpacing: 0,
  );
  
  /// Monospace Small - for smaller technical data
  static TextStyle get monospaceSmall => GoogleFonts.jetBrainsMono(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.mediumGray,
    letterSpacing: 0,
  );

  // ═══════════════════════════════════════════════════════════════
  // SPECIALIZED STYLES
  // ═══════════════════════════════════════════════════════════════
  
  /// Error text style
  static TextStyle get error => bodyMedium.copyWith(
    color: AppColors.error,
  );
  
  /// Success text style
  static TextStyle get success => bodyMedium.copyWith(
    color: AppColors.success,
  );
  
  /// Link style
  static TextStyle get link => bodyMedium.copyWith(
    color: AppColors.info,
    decoration: TextDecoration.underline,
  );
  
  /// Disabled text style
  static TextStyle get disabled => bodyMedium.copyWith(
    color: AppColors.mediumGray.withOpacity(0.5),
  );
}
