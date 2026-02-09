import 'package:flutter/material.dart';
import 'app_colors.dart';

/// ChainCare Premium Decorations
/// Reusable BoxDecorations for consistent premium styling
class AppDecorations {
  AppDecorations._();

  // ═══════════════════════════════════════════════════════════════
  // CARD DECORATIONS
  // ═══════════════════════════════════════════════════════════════
  
  /// Premium elevated card with soft shadows
  static BoxDecoration get premiumCard => BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: AppColors.softGray,
      width: 1,
    ),
    boxShadow: [
      BoxShadow(
        color: AppColors.shadowSoft,
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
      BoxShadow(
        color: AppColors.shadowSoft.withOpacity(0.5),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );
  
  /// Card with stronger elevation for floating elements
  static BoxDecoration get elevatedCard => BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: AppColors.shadowMedium,
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: AppColors.shadowSoft,
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );
  
  /// Flat card with border only (no shadow)
  static BoxDecoration get flatCard => BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: AppColors.softGray,
      width: 1,
    ),
  );
  
  /// Subtle card for nested content
  static BoxDecoration get subtleCard => BoxDecoration(
    color: AppColors.offWhite,
    borderRadius: BorderRadius.circular(12),
  );

  // ═══════════════════════════════════════════════════════════════
  // GLASSMORPHISM EFFECTS
  // ═══════════════════════════════════════════════════════════════
  
  /// Glass card with frosted effect
  static BoxDecoration get glassCard => BoxDecoration(
    color: AppColors.glassBackground,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      color: AppColors.glassBorder,
      width: 1.5,
    ),
    boxShadow: [
      BoxShadow(
        color: AppColors.shadowSoft,
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ],
  );

  // ═══════════════════════════════════════════════════════════════
  // GRADIENT CONTAINERS
  // ═══════════════════════════════════════════════════════════════
  
  /// Primary gradient background
  static BoxDecoration get primaryGradient => BoxDecoration(
    gradient: AppColors.primaryGradient,
    borderRadius: BorderRadius.circular(12),
  );
  
  /// Success gradient background
  static BoxDecoration get successGradient => BoxDecoration(
    gradient: AppColors.successGradient,
    borderRadius: BorderRadius.circular(12),
  );
  
  /// Error gradient background
  static BoxDecoration get errorGradient => BoxDecoration(
    gradient: AppColors.errorGradient,
    borderRadius: BorderRadius.circular(12),
  );

  // ═══════════════════════════════════════════════════════════════
  // INPUT FIELD DECORATIONS
  // ═══════════════════════════════════════════════════════════════
  
  /// Input field decoration (unfocused)
  static InputDecoration inputDecoration({
    required String labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? helperText,
    String? errorText,
  }) => InputDecoration(
    labelText: labelText,
    hintText: hintText,
    helperText: helperText,
    errorText: errorText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: AppColors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: AppColors.softGray,
        width: 1.5,
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: AppColors.softGray,
        width: 1.5,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(
        color: AppColors.primary,
        width: 2,
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(
        color: AppColors.error,
        width: 1.5,
      ),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(
        color: AppColors.error,
        width: 2,
      ),
    ),
  );

  // ═══════════════════════════════════════════════════════════════
  // BUTTON DECORATIONS
  // ═══════════════════════════════════════════════════════════════
  
  /// Primary button with gradient
  static BoxDecoration get primaryButton => BoxDecoration(
    gradient: AppColors.primaryGradient,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: AppColors.primary.withOpacity(0.3),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );
  
  /// Secondary button (outlined)
  static BoxDecoration secondaryButton({bool isPressed = false}) => BoxDecoration(
    color: isPressed ? AppColors.primaryVeryLight : Colors.transparent,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: AppColors.primary,
      width: 2,
    ),
  );

  // ═══════════════════════════════════════════════════════════════
  // CHIP/TAG DECORATIONS
  // ═══════════════════════════════════════════════════════════════
  
  /// Chip/tag decoration
  static BoxDecoration chip({required Color color}) => BoxDecoration(
    color: color.withOpacity(0.15),
    borderRadius: BorderRadius.circular(16),
  );
  
  /// Status badge decoration
  static BoxDecoration statusBadge({required Color color}) => BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: color.withOpacity(0.3),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );

  // ═══════════════════════════════════════════════════════════════
  // DIVIDER DECORATIONS
  // ═══════════════════════════════════════════════════════════════
  
  /// Solid divider
  static BoxDecoration get divider => BoxDecoration(
    color: AppColors.softGray,
  );
  
  /// Dashed divider
  static BoxDecoration get dashedDivider => BoxDecoration(
    border: Border(
      bottom: BorderSide(
        color: AppColors.softGray,
        width: 1,
        style: BorderStyle.solid,
      ),
    ),
  );

  // ═══════════════════════════════════════════════════════════════
  // SPECIAL DECORATIONS
  // ═══════════════════════════════════════════════════════════════
  
  /// Shimmer loading overlay
  static BoxDecoration get shimmerOverlay => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        AppColors.lightGray.withOpacity(0),
        AppColors.lightGray.withOpacity(0.5),
        AppColors.lightGray.withOpacity(0),
      ],
      stops: const [0.0, 0.5, 1.0],
    ),
  );
  
  /// Avatar decoration
  static BoxDecoration get avatar => BoxDecoration(
    shape: BoxShape.circle,
    border: Border.all(
      color: AppColors.softGray,
      width: 2,
    ),
    boxShadow: [
      BoxShadow(
        color: AppColors.shadowSoft,
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );
  
  /// QR code container
  static BoxDecoration get qrCodeContainer => BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      color: AppColors.softGray,
      width: 1,
    ),
    boxShadow: [
      BoxShadow(
        color: AppColors.shadowMedium,
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
    ],
  );
}
