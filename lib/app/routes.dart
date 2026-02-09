import 'package:flutter/material.dart';

// Screens
import '../screens/landing_page.dart';
import '../screens/qr_display_screen.dart';
import '../screens/audit_log_screen.dart';
import '../screens/qr_scan_screen.dart';

// Auth
import '../auth/auth_gate.dart';
import '../auth/universal_login.dart';
import '../auth/patient_signup.dart';
import '../auth/doctor_signup.dart';
import '../auth/email_verification_screen.dart';
import '../emergency/emergency_gate.dart';

// Workflows
import '../patient/patient_dashboard.dart';
import '../patient/patient_profile_screen.dart';
import '../screens/doctor_dashboard.dart';
import '../screens/doctor_verification_screen.dart';
import '../screens/check_status_screen.dart';
import '../screens/doctor_pending_screen.dart';
import '../screens/patient_records_screen.dart';
import '../screens/admin_dashboard.dart';

final Map<String, WidgetBuilder> appRoutes = {
  // Named route for manual navigation back to landing
  '/landing': (_) => const LandingPage(),

  // Auth Gates (Direct Access)
  '/patient_entry': (_) => const AuthGate(isDoctor: false),
  '/doctor_entry': (_) => const AuthGate(isDoctor: true),

  // Login & Signup
  '/login': (_) => const UniversalLoginScreen(isDoctor: false),
  '/doctor_login': (_) => const UniversalLoginScreen(isDoctor: true),
  '/signup': (_) => const PatientSignupScreen(),
  '/doctor_signup': (_) => const DoctorSignupScreen(),

  // Email Verification
  '/email_verification': (_) => const EmailVerificationScreen(),

  // Doctor Flow
  '/doctor_dashboard': (_) => const DoctorDashboard(),
  '/doctor_verification': (_) => const DoctorVerificationScreen(),
  '/doctor_pending': (_) => const DoctorPendingScreen(),
  '/check_status': (_) => const CheckStatusScreen(),

  // Patient Flow
  '/dashboard': (_) => const PatientDashboard(),
  '/profile': (_) => const PatientProfileScreen(),
  '/patient_profile_setup': (_) => const PatientProfileScreen(isSetup: true),
  '/my_qr': (_) => const QrDisplayScreen(),
  '/my_records': (_) => const PatientRecordsScreen(),

  // Admin
  '/admin_dashboard': (_) => const AdminDashboard(),

  // System
  '/emergency': (_) => const EmergencyGate(),
  '/audit': (_) => const AuditLogScreen(),
  '/qr_scanner': (_) => const QrScanScreen(),
};