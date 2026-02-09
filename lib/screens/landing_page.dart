import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/premium_card.dart';
import '../widgets/premium_button.dart';

/// Premium Landing Page - Marketing-quality experience
/// Showcases ChainCare as a premium medical platform
class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.subtleBackground,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Hero Section
                _buildHeroSection(context),
                
                const SizedBox(height: 60),
                
                // Role Selection Cards
                _buildRoleSelection(context),
                
                const SizedBox(height: 60),
                
                // Features Section
                _buildFeaturesSection(context),
                
                const SizedBox(height: 60),
                
                // Bottom Actions
                _buildBottomActions(context),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Hero Section with gradient and bold headline
  Widget _buildHeroSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 60),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      child: Column(
        children: [
          // App Icon with glow
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.white.withOpacity(0.3),
                  blurRadius: 24,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: const Icon(
              Icons.health_and_safety,
              size: 64,
              color: AppColors.white,
            ),
          ).animate()
            .scale(duration: 600.ms, curve: Curves.elasticOut)
            .fade(),
          
          const SizedBox(height: 24),
          
          // Main Headline
          Text(
            'ChainCare',
            style: AppTextStyles.displayLarge.copyWith(
              color: AppColors.white,
              fontSize: 42,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ).animate()
            .fadeIn(delay: 200.ms)
            .slideY(begin: 0.3, end: 0),
          
          const SizedBox(height: 12),
          
          // Subheadline
          Text(
            'Your Medical Records,\nSecured by Blockchain',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.white.withOpacity(0.95),
              fontWeight: FontWeight.w400,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ).animate()
            .fadeIn(delay: 400.ms)
            .slideY(begin: 0.3, end: 0),
          
          const SizedBox(height: 32),
          
          // Feature Pills
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _buildFeaturePill('Blockchain Secured', Icons.lock),
              _buildFeaturePill('AI Powered', Icons.psychology),
              _buildFeaturePill('Always Accessible', Icons.access_time),
            ],
          ).animate()
            .fadeIn(delay: 600.ms)
            .slideY(begin: 0.3, end: 0),
        ],
      ),
    );
  }

  /// Feature pill for hero section
  Widget _buildFeaturePill(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Role Selection Cards
  Widget _buildRoleSelection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Text(
            'Choose Your Portal',
            style: AppTextStyles.titleLarge,
          ),
          
          const SizedBox(height: 8),
          
          Text(
            'Select your role to access your dashboard',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 32),
          
          // Patient Portal Card
          _RoleCard(
            title: 'Patient Portal',
            subtitle: 'Access and manage your health records',
            icon: Icons.person_outline,
            gradient: LinearGradient(
              colors: [Colors.blue.shade400, Colors.blue.shade600],
            ),
            onTap: () => Navigator.pushNamed(context, '/patient_entry'),
          ).animate()
            .fadeIn(delay: 100.ms)
            .slideX(begin: -0.2, end: 0),
          
          const SizedBox(height: 16),
          
          // Doctor Portal Card
          _RoleCard(
            title: 'Doctor Workspace',
            subtitle: 'Verify identity & manage patient care',
            icon: Icons.medical_services_outlined,
            gradient: AppColors.primaryGradient,
            onTap: () async {
              // ✅ FIX: Validate role before allowing portal access
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                try {
                  final doc = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .get();
                  
                  if (doc.exists) {
                    final role = (doc.data() as Map<String, dynamic>?)?['role'];
                    if (role != 'doctor') {
                      // Wrong role - sign out and navigate to login
                      await FirebaseAuth.instance.signOut();
                      if (context.mounted) {
                        Navigator.pushNamed(context, '/doctor_entry');
                      }
                      return;
                    }
                  }
                } catch (e) {
                  // On error, sign out and go to login
                  await FirebaseAuth.instance.signOut();
                }
              }
              // Proceed to login/portal
              if (context.mounted) {
                Navigator.pushNamed(context, '/doctor_entry');
              }
            },
          ).animate()
            .fadeIn(delay: 200.ms)
            .slideX(begin: -0.2, end: 0),
          
          const SizedBox(height: 16),
          
          // Emergency Access Card
          _RoleCard(
            title: 'Emergency Access',
            subtitle: 'Break-glass protocol for critical situations',
            icon: Icons.emergency,
            gradient: AppColors.errorGradient,
            onTap: () => Navigator.pushNamed(context, '/emergency'),
          ).animate()
            .fadeIn(delay: 300.ms)
            .slideX(begin: -0.2, end: 0),
        ],
      ),
    );
  }

  /// Features Section
  Widget _buildFeaturesSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Text(
            'Why ChainCare?',
            style: AppTextStyles.titleLarge,
          ),
          
          const SizedBox(height: 32),
          
          // Features Grid
          Row(
            children: [
              Expanded(
                child: _FeatureCard(
                  icon: Icons.security,
                  title: 'Blockchain\nSecurity',
                  description: 'Immutable audit trail',
                ).animate()
                  .fadeIn(delay: 100.ms)
                  .scale(),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _FeatureCard(
                  icon: Icons.psychology,
                  title: 'AI Medical\nAssistant',
                  description: 'Instant insights',
                ).animate()
                  .fadeIn(delay: 200.ms)
                  .scale(),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _FeatureCard(
                  icon: Icons.qr_code_scanner,
                  title: 'QR Code\nAccess',
                  description: 'Instant sharing',
                ).animate()
                  .fadeIn(delay: 300.ms)
                  .scale(),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _FeatureCard(
                  icon: Icons.fingerprint,
                  title: 'Biometric\nLock',
                  description: 'Extra protection',
                ).animate()
                  .fadeIn(delay: 400.ms)
                  .scale(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Bottom Actions
  Widget _buildBottomActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Blockchain Audit Button
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/audit'),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.offWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.softGray,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.policy,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'View Blockchain Audit Ledger',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ).animate()
            .fadeIn(delay: 500.ms)
            .slideY(begin: 0.2, end: 0),
        ],
      ),
    );
  }
}

/// Premium Role Card with gradient background
class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GradientCard(
      onTap: onTap,
      gradient: gradient,
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          // Icon Container
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.white.withOpacity(0.25),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 32,
              color: AppColors.white,
            ),
          ),
          
          const SizedBox(width: 20),
          
          // Text Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          
          // Arrow
          Icon(
            Icons.arrow_forward_ios,
            size: 20,
            color: AppColors.white.withOpacity(0.8),
          ),
        ],
      ),
    );
  }
}

/// Feature Card for features section
class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 32,
              color: AppColors.white,
            ),
          ),
          
          const SizedBox(height: 16),
          
          Text(
            title,
            style: AppTextStyles.labelLarge.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          Text(
            description,
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}