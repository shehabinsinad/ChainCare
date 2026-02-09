import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'auth_service.dart';
import '../screens/check_status_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/premium_button.dart';

/// Premium Doctor Signup Screen  
/// Stunning gradient background with floating glassmorphic card
class DoctorSignupScreen extends StatefulWidget {
  const DoctorSignupScreen({super.key});

  @override
  State<DoctorSignupScreen> createState() => _DoctorSignupScreenState();
}

class _DoctorSignupScreenState extends State<DoctorSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleGoogleSignup() async {
    setState(() => _isLoading = true);
    try {
      final cred = await AuthService.signInWithGoogle();
      if (cred?.user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final doc = await FirebaseFirestore.instance.collection('users').doc(cred!.user!.uid).get();
    
    // ✅ FIX: Validate role before allowing signup
    if (doc.exists) {
      final existingRole = (doc.data() as Map<String, dynamic>?)?['role'] as String?;
      
      if (existingRole != null && existingRole != 'doctor') {
        // User already exists as patient or admin - reject signup
        await AuthService.signOut();
        throw Exception('This email is already registered as a ${existingRole}. Please sign in to the ${existingRole} portal instead.');
      }
      
      // If role is already 'doctor', just proceed to navigation
    } else {
      // Create new doctor account only if user doesn't exist
      await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
        'name': cred.user!.displayName ?? 'New Doctor',
        'email': cred.user!.email,
        'role': 'doctor',
        'isVerified': false,
        'verificationSubmitted': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
    } catch (e) {
      try { await AuthService.signOut(); } catch (_) {}
      if (mounted) {
        _showError("Signup failed. Please try again.");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailCtrl.text.trim(),
        password: passCtrl.text.trim(),
      );
      
      await cred.user!.updateDisplayName(nameCtrl.text.trim());
      await cred.user!.sendEmailVerification();

      await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
        'name': nameCtrl.text.trim(),
        'email': emailCtrl.text.trim(),
        'role': 'doctor',
        'isVerified': false,
        'verificationSubmitted': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      String message = "Registration failed";
      if (e.code == 'email-already-in-use') {
        message = "Email already registered. Try logging in.";
      } else if (e.code == 'weak-password') {
        message = "Password too weak. Use at least 6 characters.";
      } else if (e.code == 'invalid-email') {
        message = "Invalid email format.";
      }
      
      if (mounted) _showError(message);
    } catch (e) {
      if (mounted) _showError("Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.white)),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
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
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.medical_services,
                          size: 48,
                          color: AppColors.white,
                        ),
                      ).animate().scale(curve: Curves.elasticOut),

                      const SizedBox(height: 24),

                      Text(
                        "Apply for Doctor Access",
                        textAlign: TextAlign.center,
                        style: AppTextStyles.displayMedium.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ).animate().fadeIn(delay: 100.ms),

                      const SizedBox(height: 8),

                      Text(
                        'Join ChainCare medical network',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.white.withOpacity(0.9),
                        ),
                      ).animate().fadeIn(delay: 200.ms),

                      const SizedBox(height: 40),

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
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  side: BorderSide(color: AppColors.softGray),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Image.network(
                                    'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png',
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Icon(Icons.login, size: 24),
                                  ),
                                ),
                                label: Text(
                                  "Sign up with Google",
                                  style: AppTextStyles.labelLarge.copyWith(
                                    color: AppColors.deepCharcoal,
                                  ),
                                ),
                                onPressed: _isLoading ? null : _handleGoogleSignup,
                              ),

                              const SizedBox(height: 24),

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

                              TextFormField(
                                controller: nameCtrl,
                                textCapitalization: TextCapitalization.words,
                                decoration: InputDecoration(
                                  labelText: "Full Name",
                                  prefixIcon: const Icon(Icons.person_outline),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                validator: (v) => v!.isEmpty ? "Required" : null,
                              ),

                              const SizedBox(height: 16),

                              TextFormField(
                                controller: emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText: "Professional Email",
                                  prefixIcon: const Icon(Icons.alternate_email),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                validator: (v) => !v!.contains('@') ? "Invalid Email" : null,
                              ),

                              const SizedBox(height: 16),

                              TextFormField(
                                controller: passCtrl,
                                obscureText: true,
                                decoration: InputDecoration(
                                  labelText: "Password",
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                validator: (v) => v!.length < 6 ? "Min 6 chars" : null,
                              ),

                              const SizedBox(height: 28),

                              PremiumButton(
                                text: "SUBMIT APPLICATION",
                                onPressed: _isLoading ? null : _register,
                                isLoading: _isLoading,
                                isFullWidth: true,
                              ),

                              const SizedBox(height: 16),

                              Center(
                                child: TextButton(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const CheckStatusScreen()),
                                  ),
                                  child: Text(
                                    "Already applied? Check Status",
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.mediumGray,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
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