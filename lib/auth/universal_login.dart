import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../app/app.dart';
import 'auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/premium_button.dart';

/// Premium Universal Login Screen
/// Stunning gradient background with floating glassmorphic card
class UniversalLoginScreen extends StatefulWidget {
  final bool isDoctor;
  const UniversalLoginScreen({super.key, required this.isDoctor});

  @override
  State<UniversalLoginScreen> createState() => _UniversalLoginScreenState();
}

class _UniversalLoginScreenState extends State<UniversalLoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkRoleAndNavigate(User user) async {
    try {
      DocumentSnapshot? doc;
      int retries = 0;
      const maxRetries = 3;
      
      while (retries < maxRetries) {
        doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get()
            .timeout(const Duration(seconds: 5));
        
        if (doc.exists) break;
        
        retries++;
        if (retries < maxRetries) {
          await Future.delayed(Duration(milliseconds: 500 * retries));
        }
      }
      
      if (doc == null || !doc.exists) {
        String role = widget.isDoctor ? 'doctor' : 'patient';
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': user.displayName ?? 'New User',
          'email': user.email,
          'role': role,
          'createdAt': FieldValue.serverTimestamp(),
          if (role == 'patient') 'profileCompleted': false,
          if (role == 'doctor') 'isVerified': false,
          if (role == 'doctor') 'verificationSubmitted': false,
        });
        
        if (mounted) {
          FocusScope.of(context).unfocus();
          if (!widget.isDoctor) {
            Navigator.pushReplacementNamed(context, '/patient_profile_setup');
          } else {
            navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (route) => false);
          }
        }
        return;
      }

      final userData = doc.data() as Map<String, dynamic>?;
      if (userData == null) {
        throw "Account data not found. Please try again.";
      }

      final role = userData['role'] as String?;

    // ✅ FIX: Sign out immediately on role mismatch to prevent session leakage
    if (widget.isDoctor && role != 'doctor') {
      await AuthService.signOut();
      throw "This account is registered as a patient. Please use patient login.";
    }
    if (!widget.isDoctor && role == 'doctor') {
      await AuthService.signOut();
      throw "This account is registered as a doctor. Please use doctor login.";
    }

      if (role == 'patient') {
        final profileCompleted = userData['profileCompleted'] as bool? ?? false;
        if (!profileCompleted && mounted) {
          FocusScope.of(context).unfocus();
          Navigator.pushReplacementNamed(context, '/patient_profile_setup');
          return;
        }
      }
      
      if (mounted) {
        FocusScope.of(context).unfocus();
        navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _handleGoogle() async {
    setState(() => _isLoading = true);
    try {
      final cred = await AuthService.signInWithGoogle();
      if (cred?.user == null) {
        setState(() => _isLoading = false);
        return;
      }
      await _checkRoleAndNavigate(cred!.user!);
    } catch (e) {
      try { await AuthService.signOut(); } catch (_) {}
      
      if(mounted) {
        _showError("Authentication failed. Please try again.");
      }
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _login() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      _showError("Please enter both email and password");
      return;
    }
    
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    
    try {
      final cred = await AuthService.signIn(
        _emailCtrl.text.trim(), 
        _passCtrl.text.trim()
      );
      
      await _checkRoleAndNavigate(cred.user!);
    } on FirebaseAuthException catch (e) {
      String message = "Invalid email or password";
      if (e.code == 'invalid-email') {
        message = "Please enter a valid email address";
      } else if (e.code == 'user-disabled') {
        message = "This account has been disabled";
      }
      _showError(message);
    } catch (e) {
    // ✅ FIX: Ensure complete sign out on any login error
    try { await AuthService.signOut(); } catch (_) {}
    _showError(e.toString().contains("account is registered") 
        ? e.toString() 
        : "Login failed. Please try again.");
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }  }
  

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.white)),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isDoctor ? "Doctor Login" : "Patient Login";

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: widget.isDoctor 
              ? AppColors.primaryGradient 
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.blue.shade400, Colors.blue.shade600],
                ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Main Content
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Medical Icon
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.isDoctor ? Icons.medical_services : Icons.person_outline,
                          size: 48,
                          color: AppColors.white,
                        ),
                      ).animate().scale(curve: Curves.elasticOut),

                      const SizedBox(height: 24),

                      // Title
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.displayMedium.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ).animate().fadeIn(delay: 100.ms),

                      const SizedBox(height: 8),

                      Text(
                        'Welcome back to ChainCare',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.white.withOpacity(0.9),
                        ),
                      ).animate().fadeIn(delay: 200.ms),

                      const SizedBox(height: 40),

                      // Floating Glass Card
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
                            // Google Sign-In
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                border: Border.all(color: AppColors.softGray),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _isLoading ? null : _handleGoogle,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: Image.network(
                                            'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png',
                                            errorBuilder: (context, error, stackTrace) => 
                                                const Icon(Icons.login, size: 24),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          "Continue with Google",
                                          style: AppTextStyles.labelLarge.copyWith(
                                            color: AppColors.deepCharcoal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Divider
                            Row(
                              children: [
                                const Expanded(child: Divider()),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    "OR",
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.mediumGray,
                                    ),
                                  ),
                                ),
                                const Expanded(child: Divider()),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // Email Field
                            TextField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              style: AppTextStyles.bodyLarge,
                              decoration: InputDecoration(
                                labelText: "Email",
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

                            const SizedBox(height: 16),

                            // Password Field
                            TextField(
                              controller: _passCtrl,
                              obscureText: true,
                              style: AppTextStyles.bodyLarge,
                              decoration: InputDecoration(
                                labelText: "Password",
                                labelStyle: AppTextStyles.bodyMedium,
                                prefixIcon: const Icon(Icons.lock_outline),
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

                            const SizedBox(height: 28),

                            // Sign In Button (blue for patient, teal for doctor)
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: widget.isDoctor 
                                      ? AppColors.primary 
                                      : Colors.blue.shade400,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 4,
                                ),
                                onPressed: _isLoading ? null : _login,
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: AppColors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : Text(
                                        "SIGN IN",
                                        style: AppTextStyles.buttonLarge.copyWith(
                                          color: AppColors.white,
                                        ),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Sign Up Link
                            Center(
                              child: TextButton(
                                onPressed: () {
                                  if (widget.isDoctor) {
                                    Navigator.pushNamed(context, '/doctor_signup');
                                  } else {
                                    Navigator.pushNamed(context, '/signup');
                                  }
                                },
                                child: RichText(
                                  text: TextSpan(
                                    text: "Don't have an account? ",
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.mediumGray,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: "Sign Up",
                                        style: AppTextStyles.labelLarge.copyWith(
                                          color: widget.isDoctor ? AppColors.primary : Colors.blue.shade600,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
                    ],
                  ),
                ),
              ),

              // Back Button (on top)
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}