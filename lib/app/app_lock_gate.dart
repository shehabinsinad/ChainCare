import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/auth_service.dart';
import '../auth/auth_gate.dart';
import '../screens/landing_page.dart';

/// Banking-app style App Lock implementation.
/// 
/// Triggers ONLY on:
/// 1. Cold Start - When app is first launched (once per app session)
/// 2. Resume from Background - When app was minimized and reopened
/// 
/// Does NOT trigger during:
/// - Internal navigation (login/logout, role switching, etc.)
/// - Widget rebuilds
/// - Auth state changes
class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key});

  // ✅ STATIC STATE - Persists across widget rebuilds
  static bool _isSessionUnlocked = false;
  static bool _hasPerformedInitialCheck = false;
  static DateTime? _pausedAt;

  /// Call this to reset lock state (e.g., when explicitly locking)
  static void lock() {
    _isSessionUnlocked = false;
  }

  /// Reset everything on app termination (optional)
  static void resetSession() {
    _isSessionUnlocked = false;
    _hasPerformedInitialCheck = false;
    _pausedAt = null;
  }

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  bool _isAuthenticating = false;
  bool _showLockScreen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Only run initial check ONCE per app session
    if (!AppLockGate._hasPerformedInitialCheck) {
      debugPrint('🔐 [COLD START] First initialization');
      _performInitialLockCheck();
    } else {
      debugPrint('🔐 [REBUILD] Already checked, session unlocked: ${AppLockGate._isSessionUnlocked}');
      // Sync local state with static state
      _showLockScreen = !AppLockGate._isSessionUnlocked;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Only called ONCE on true cold start
  Future<void> _performInitialLockCheck() async {
    AppLockGate._hasPerformedInitialCheck = true;
    
    final lockEnabled = await AuthService.isAppLockEnabled();
    
    if (!lockEnabled) {
      debugPrint('🔐 [COLD START] Lock disabled - granting access');
      AppLockGate._isSessionUnlocked = true;
      if (mounted) setState(() => _showLockScreen = false);
      return;
    }

    debugPrint('🔐 [COLD START] Lock enabled - requesting auth');
    if (mounted) {
      setState(() => _showLockScreen = true);
      await _authenticate();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('🔐 Lifecycle: $state');

    switch (state) {
      case AppLifecycleState.paused:
        AppLockGate._pausedAt = DateTime.now();
        debugPrint('🔐 App paused at ${AppLockGate._pausedAt}');
        break;
        
      case AppLifecycleState.resumed:
        _handleResume();
        break;
        
      default:
        break;
    }
  }

  Future<void> _handleResume() async {
    // Skip if already locked or showing lock screen
    if (_showLockScreen || _isAuthenticating) {
      debugPrint('🔐 [RESUME] Already showing lock screen, skipping');
      return;
    }

    // Skip if session was never unlocked
    if (!AppLockGate._isSessionUnlocked) {
      debugPrint('🔐 [RESUME] Session never unlocked, skipping');
      return;
    }

    final lockEnabled = await AuthService.isAppLockEnabled();
    if (!lockEnabled) {
      debugPrint('🔐 [RESUME] Lock disabled, staying unlocked');
      return;
    }

    // Check if we were actually in background
    if (AppLockGate._pausedAt != null) {
      final secondsInBackground = DateTime.now().difference(AppLockGate._pausedAt!).inSeconds;
      debugPrint('🔐 [RESUME] Was in background for $secondsInBackground seconds');
      
      // ✅ Only lock if minimized for more than 60 seconds (1 minute cooldown)
      if (secondsInBackground > 60) {
        debugPrint('🔐 [RESUME] Exceeded 1-minute threshold - locking app');
        AppLockGate._isSessionUnlocked = false;
        if (mounted) {
          setState(() => _showLockScreen = true);
          await _authenticate();
        }
      } else {
        debugPrint('🔐 [RESUME] Within 1-minute cooldown - staying unlocked');
      }
    }
    
    AppLockGate._pausedAt = null;
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;

    setState(() => _isAuthenticating = true);

    try {
      await Future.delayed(const Duration(milliseconds: 100));
      
      final authenticated = await AuthService.authenticate(reason: 'Unlock ChainCare');

      if (mounted) {
        if (authenticated) {
          AppLockGate._isSessionUnlocked = true;
          setState(() {
            _showLockScreen = false;
            _isAuthenticating = false;
          });
        } else {
          setState(() => _isAuthenticating = false);
          _showRetryDialog();
        }
      }
    } catch (e) {
      debugPrint('🔐 Auth error: $e');
      if (mounted) {
        setState(() => _isAuthenticating = false);
        _showRetryDialog(errorMessage: 'Authentication failed. Please try again.');
      }
    }
  }

  void _showRetryDialog({String? errorMessage}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Authentication Required'),
        content: Text(errorMessage ?? 'You must authenticate to access the app.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _authenticate();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show lock screen only when needed
    if (_showLockScreen) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 80, color: Colors.grey),
              const SizedBox(height: 24),
              const Text(
                'App Locked',
                style: TextStyle(fontSize: 24, color: Colors.grey, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: _isAuthenticating ? null : _authenticate,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  backgroundColor: const Color(0xFF009688),
                ),
                child: _isAuthenticating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Unlock', style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    // ✅ UNLOCKED - Show app content
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasData && snapshot.data != null) {
          return const AuthGate();
        }

        return const LandingPage();
      },
    );
  }
}