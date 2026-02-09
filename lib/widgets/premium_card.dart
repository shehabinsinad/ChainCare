import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';

/// Premium Card Widget with elevation and shadows
/// Provides consistent card styling across the app
class PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? color;
  final double? borderRadius;
  final bool elevated;
  final bool flat;
  final Border? border;
  
  const PremiumCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.color,
    this.borderRadius,
    this.elevated = false,
    this.flat = false,
    this.border,
  });
  
  @override
  Widget build(BuildContext context) {
    // Choose decoration based on elevation level
    BoxDecoration decoration = flat
        ? AppDecorations.flatCard
        : (elevated ? AppDecorations.elevatedCard : AppDecorations.premiumCard);
    
    // Override color if provided
    if (color != null) {
      decoration = decoration.copyWith(color: color);
    }
    
    // Override border radius if provided
    if (borderRadius != null) {
      decoration = decoration.copyWith(
        borderRadius: BorderRadius.circular(borderRadius!),
      );
    }
    
    // Override border if provided
    if (border != null) {
      decoration = decoration.copyWith(border: border);
    }
    
    Widget card = Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: decoration,
      child: child,
    );
    
    // Wrap with InkWell if tappable
    if (onTap != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius ?? 16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(borderRadius ?? 16),
            child: card,
          ),
        ),
      );
    }
    
    return card;
  }
}

/// Glass Card with frosted glass effect
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final double? borderRadius;
  
  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.borderRadius,
  });
  
  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: AppDecorations.glassCard.copyWith(
        borderRadius: BorderRadius.circular(borderRadius ?? 20),
      ),
      child: child,
    );
    
    if (onTap != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius ?? 20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(borderRadius ?? 20),
            child: card,
          ),
        ),
      );
    }
    
    return card;
  }
}

/// Gradient Card with premium gradient background
class GradientCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final double? borderRadius;
  
  const GradientCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.gradient,
    this.borderRadius,
  });
  
  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient ?? AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(borderRadius ?? 16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
    
    if (onTap != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius ?? 16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(borderRadius ?? 16),
            child: card,
          ),
        ),
      );
    }
    
    return card;
  }
}
