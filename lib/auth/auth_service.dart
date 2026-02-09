import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _googleSignIn = GoogleSignIn();
  static final _localAuth = LocalAuthentication();

  // --- Global App Lock (One Lock For The Entire App) ---
  
  static Future<bool> authenticate({String reason = 'Unlock ChainCare'}) async {
    try {
      final bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
    
      debugPrint('🔐 Can check biometrics: $canCheckBiometrics');
      debugPrint('🔐 Device supported: $isDeviceSupported');

      if (!canCheckBiometrics || !isDeviceSupported) {
        debugPrint('🔐 Biometrics not available, allowing access');
        return true;
      }

      final List<BiometricType> availableBiometrics = 
          await _localAuth.getAvailableBiometrics();
    
      debugPrint('🔐 Available biometrics: $availableBiometrics');

      if (availableBiometrics.isEmpty) {
        debugPrint('🔐 No biometrics enrolled, allowing access');
        return true;
      }

      await Future.delayed(const Duration(milliseconds: 100));

      debugPrint('🔐 Attempting authentication...');
    
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
          sensitiveTransaction: false,
        ),
      );

      debugPrint('🔐 Authentication result: $didAuthenticate');
      return didAuthenticate;
    
    } catch (e) {
      debugPrint('🔐 Authentication error: $e');
      // SECURITY: On error, deny access - never grant access on failure
      return false;
    }
  }

  // --- ONE Global Lock Setting ---
  static Future<bool> isAppLockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('app_lock_enabled') ?? false;
  }

  static Future<void> setAppLockEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_lock_enabled', enabled);
  }

  // --- Auth Methods ---
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      // ✅ Sign out first to force account selection dialog
      await _googleSignIn.signOut();
      
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      return null;
    }
  }

  static Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  static Future<UserCredential> signUp(String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    try { await cred.user?.sendEmailVerification(); } catch (_) {}
    return cred;
  }

  static Future<void> signOut() async {
    try { await _googleSignIn.signOut(); } catch (_) {}
    await _auth.signOut();
  }
}