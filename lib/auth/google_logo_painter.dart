import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app/app.dart';
import 'auth_service.dart';

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
      // Wait for Firestore to be ready with retry logic
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
        // Auto-signup logic for new users
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
        
        // For new users, navigate appropriately
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

      // Existing user - strict role check
      final userData = doc.data() as Map<String, dynamic>?;
      if (userData == null) {
        throw "Account data not found. Please try again.";
      }

      final role = userData['role'] as String?;

      if (widget.isDoctor && role != 'doctor') {
        throw "This account is registered as a patient. Please use patient login.";
      }
      if (!widget.isDoctor && role == 'doctor') {
        throw "This account is registered as a doctor. Please use doctor login.";
      }

      // Check profile completion for existing patients
      if (role == 'patient') {
        final profileCompleted = userData['profileCompleted'] as bool? ?? false;
        if (!profileCompleted && mounted) {
          FocusScope.of(context).unfocus();
          Navigator.pushReplacementNamed(context, '/patient_profile_setup');
          return;
        }
      }
      
      // Success - navigate to home
      if (mounted) {
        FocusScope.of(context).unfocus();
        navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      rethrow; // Let the caller handle the error
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
        // SECURITY: Use generic error message - don't leak internal errors
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
      // SECURITY: Use generic messages for auth failures to prevent enumeration attacks
      String message = "Invalid email or password";
      if (e.code == 'invalid-email') {
        message = "Please enter a valid email address";
      } else if (e.code == 'user-disabled') {
        message = "This account has been disabled. Contact support.";
      }
      // Note: 'user-not-found', 'wrong-password', 'invalid-credential' all get generic message
      
      try { await AuthService.signOut(); } catch (_) {}
      if(mounted) _showError(message);
    } catch (e) {
      // SECURITY: Generic error for role mismatch and other errors
      try { await AuthService.signOut(); } catch (_) {}
      if(mounted) _showError("Authentication failed. Please check your credentials.");
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isDoctor ? "Doctor Login" : "Patient Login";
    final color = widget.isDoctor ? Colors.teal : Colors.blue;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(title), 
        backgroundColor: color, 
        foregroundColor: Colors.white
      ),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Modern Google Sign-In Button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isLoading ? null : _handleGoogle,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Google "G" Logo
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: CustomPaint(
                                painter: GoogleLogoPainter(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              "Sign in with Google",
                              style: TextStyle(
                                color: Color(0xFF3C4043),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text("OR")
                    ),
                    Expanded(child: Divider())
                  ]
                ),
                const SizedBox(height: 24),

                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    border: OutlineInputBorder()
                  )
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Password",
                    border: OutlineInputBorder()
                  )
                ),
                const SizedBox(height: 24),
                
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color, 
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16)
                  ),
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("SIGN IN"),
                ),

                const SizedBox(height: 16),
                TextButton(
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
                      style: const TextStyle(color: Colors.grey),
                      children: [
                        TextSpan(
                          text: "Sign Up",
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold
                          )
                        ),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Custom painter for Google "G" logo
class GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    
    // Blue section
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height),
      -0.5236, // -30 degrees in radians
      2.0944, // 120 degrees
      true,
      paint,
    );
    
    // Red section
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height),
      1.5708, // 90 degrees
      1.5708, // 90 degrees
      true,
      paint,
    );
    
    // Yellow section
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height),
      3.1416, // 180 degrees
      1.0472, // 60 degrees
      true,
      paint,
    );
    
    // Green section
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height),
      4.1888, // 240 degrees
      1.0472, // 60 degrees
      true,
      paint,
    );
    
    // White center circle
    paint.color = Colors.white;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width * 0.35,
      paint,
    );
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}