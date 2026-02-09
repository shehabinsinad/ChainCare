import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'doctor_verification_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/premium_button.dart';

/// Premium Check Application Status Screen
/// Gradient background with floating glassmorphic card
class CheckStatusScreen extends StatefulWidget {
  const CheckStatusScreen({super.key});

  @override
  State<CheckStatusScreen> createState() => _CheckStatusScreenState();
}

class _CheckStatusScreenState extends State<CheckStatusScreen> {
  final emailCtrl = TextEditingController();
  bool _isLoading = false;
  String? _statusMessage;
  Color _statusColor = AppColors.deepCharcoal;
  IconData _statusIcon = Icons.info_outline;
  bool _showRetryButton = false;

  Future<void> _check() async {
    if (emailCtrl.text.isEmpty) return;
    
    FocusScope.of(context).unfocus();
    
    setState(() { 
      _isLoading = true; 
      _statusMessage = null; 
    });

    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: emailCtrl.text.trim())
          .where('role', isEqualTo: 'doctor')
          .get();

      if (query.docs.isEmpty) {
        setState(() { 
          _statusMessage = "Account not found with this email."; 
          _statusColor = AppColors.error;
          _statusIcon = Icons.error_outline;
          _showRetryButton = false;
        });
        return;
      }

      final data = query.docs.first.data();
      final isRejected = data['isRejected'] ?? false;
      final rejectionReason = data['rejectionReason'] ?? '';
      
      if (isRejected) {
        setState(() { 
          _statusMessage = rejectionReason.isNotEmpty 
              ? rejectionReason 
              : 'Your verification was not approved. Please review your documents and try again.';
          _statusColor = AppColors.error;
          _statusIcon = Icons.cancel;
          _showRetryButton = true;
        });
      } else if (data['isVerified'] == true) {
        setState(() { 
          _statusMessage = "Congratulations! Your application has been approved. You can now login."; 
          _statusColor = AppColors.success;
          _statusIcon = Icons.check_circle;
          _showRetryButton = false; 
        });
      } else if (data['verificationSubmitted'] == true) {
        setState(() { 
          _statusMessage = "Your application is under review. Check back in 24-48 hours."; 
          _statusColor = AppColors.warning;
          _statusIcon = Icons.schedule;
          _showRetryButton = false; 
        });
      } else {
        setState(() { 
          _statusMessage = "Application not submitted yet."; 
          _statusColor = AppColors.info;
          _statusIcon = Icons.info_outline;
          _showRetryButton = false; 
        });
      }
    } catch (e) {
      setState(() { 
        _statusMessage = "Error checking status. Please try again."; 
        _statusColor = AppColors.error;
        _statusIcon = Icons.error_outline;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Back Button
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.white),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ).animate().fadeIn().slideX(begin: -0.3, end: 0),
              ),

              // Main Content
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icon
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings,
                          size: 48,
                          color: AppColors.white,
                        ),
                      ).animate().scale(curve: Curves.elasticOut),

                      const SizedBox(height: 24),

                      // Title
                      Text(
                        "Check Application Status",
                        textAlign: TextAlign.center,
                        style: AppTextStyles.displayMedium.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ).animate().fadeIn(delay: 100.ms),

                      const SizedBox(height: 8),

                      Text(
                        'Enter your registered email',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.white.withOpacity(0.9),
                        ),
                      ).animate().fadeIn(delay: 200.ms),

                      const SizedBox(height: 40),

                      // Floating Card
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppColors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Email Field
                            TextField(
                              controller: emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              style: AppTextStyles.bodyLarge,
                              decoration: InputDecoration(
                                labelText: "Enter Doctor Email",
                                labelStyle: AppTextStyles.bodyMedium,
                                prefixIcon: const Icon(Icons.email_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppColors.softGray),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.primary,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Check Button
                            PremiumButton(
                              text: "CHECK STATUS",
                              onPressed: _isLoading ? null : _check,
                              isLoading: _isLoading,
                              isFullWidth: true,
                            ),

                            // Status Display
                            if (_statusMessage != null) ...[
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: _statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _statusColor.withOpacity(0.3),
                                    width: 2,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      _statusIcon,
                                      size: 48,
                                      color: _statusColor,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _statusMessage!,
                                      textAlign: TextAlign.center,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        color: _statusColor,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ).animate().fadeIn().scale(),
                            ],

                            // Try Again Button
                            if (_showRetryButton) ...[
                              const SizedBox(height: 16),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  side: BorderSide(color: AppColors.primary),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const DoctorVerificationScreen(),
                                    ),
                                  );
                                },
                                child: Text(
                                  "TRY AGAIN",
                                  style: AppTextStyles.labelLarge.copyWith(
                                    color: AppColors.primary,
                                  ),
                                ),
                              ).animate().fadeIn().slideY(begin: 0.2, end: 0),
                            ],
                          ],
                        ),
                      ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}