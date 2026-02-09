import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/doctor_dashboard.dart';
import '../patient/patient_dashboard.dart';
import '../patient/patient_profile_screen.dart';
import '../screens/admin_dashboard.dart';
import '../screens/doctor_verification_screen.dart';
import '../screens/doctor_pending_screen.dart';
import '../screens/doctor_rejected_screen.dart';
import 'universal_login.dart';
import 'email_verification_screen.dart';

class AuthGate extends StatelessWidget {
  final bool isDoctor;
  const AuthGate({super.key, this.isDoctor = false});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return UniversalLoginScreen(isDoctor: isDoctor);
    }

    // Check email verification FIRST (but skip Google sign-in users)
    if (!user.emailVerified && !user.providerData.any((info) => info.providerId == 'google.com')) {
      return const EmailVerificationScreen();
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, profileSnap) {
        // Handle connection states
        if (profileSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // Handle errors with retry option
        if (profileSnap.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Connection Error',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Unable to load your profile',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Force rebuild by navigating to same route
                      Navigator.pushReplacementNamed(context, '/');
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        if (!profileSnap.hasData || !profileSnap.data!.exists) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Setting up account...',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        }

        final data = profileSnap.data!.data() as Map<String, dynamic>;
        final role = data['role'];

        if (role == 'admin') return const AdminDashboard();

        if (role == 'doctor') {
          bool isVerified = data['isVerified'] ?? false;
          bool isRejected = data['isRejected'] ?? false; // ✅ Check rejection status
          bool submitted = data['verificationSubmitted'] ?? false;
          
          // Check if doctorProfile exists to determine if submission is complete
          bool hasProfile = data.containsKey('doctorProfile') && data['doctorProfile'] != null;

          if (isVerified) return const DoctorDashboard();
          if (isRejected) return const DoctorRejectedScreen(); // ✅ Show rejection screen
          if (submitted && hasProfile) return const DoctorPendingScreen();
          return const DoctorVerificationScreen();
        }

        // Patient role - check profile completion
        if (role == 'patient') {
          bool profileCompleted = data['profileCompleted'] ?? false;
          if (!profileCompleted) {
            return const PatientProfileScreen(isSetup: true);
          }
        }

        // Default to Patient Dashboard
        return const PatientDashboard();
      },
    );
  }
}