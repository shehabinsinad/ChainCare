import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../auth/auth_service.dart';
import '../app/app.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/premium_card.dart';
import '../screens/doctor_patient_action_screen.dart';
import 'doctor_verification_screen.dart';
import 'my_records_screen.dart';
import 'my_patients_screen.dart';

/// Premium Doctor Dashboard
/// Professional workspace with stats and QR scanner
class DoctorDashboard extends StatelessWidget {
  const DoctorDashboard({super.key});

  void _scanQR(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: AppColors.deepCharcoal,
          appBar: AppBar(
            title: const Text('Scan Patient QR'),
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
          ),
          body: MobileScanner(
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DoctorPatientActionScreen(
                        patientUid: barcode.rawValue!,
                      ),
                    ),
                  );
                  break;
                }
              }
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Error: No user logged in")),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: CustomScrollView(
        slivers: [
          // Premium AppBar with Gradient
          _buildPremiumAppBar(context, user),
          
          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats Cards (Centered)
                  _buildStatsSection(user),
                  
                  const SizedBox(height: 32),
                  
                  // QR Scanner Card
                  _buildQRScannerSection(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Premium AppBar with gradient and profile
  Widget _buildPremiumAppBar(BuildContext context, User user) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: AppColors.primary,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.primaryGradient,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  String name = "Doctor";
                  String? picUrl;
                  
                  if (snapshot.hasData && snapshot.data!.exists) {
                    final data = snapshot.data!.data() as Map<String, dynamic>;
                    name = data['name'] ?? 'Doctor';
                    picUrl = data['profilePicUrl'];
                  }
                  
                  return Row(
                    children: [
                      // Avatar
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.white.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 28,
                          backgroundColor: AppColors.white.withOpacity(0.2),
                          backgroundImage:
                              picUrl != null ? NetworkImage(picUrl) : null,
                          child: picUrl == null
                              ? Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'D',
                                  style: AppTextStyles.titleLarge.copyWith(
                                    color: AppColors.white,
                                  ),
                                )
                              : null,
                        ),
                      ).animate().scale(delay: 100.ms),
                      
                      const SizedBox(width: 16),
                      
                      // Greeting
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _getGreeting(),
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.white.withOpacity(0.9),
                              ),
                            ),
                            Text(
                              'Doctor. $name',
                              style: AppTextStyles.titleMedium.copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.2, end: 0),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.person_outline),
          tooltip: 'Update Profile',
          onPressed: () async {
            final user = FirebaseAuth.instance.currentUser;
            if (user == null) return;

            try {
              final doc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get();

              if (!doc.exists) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile not found')),
                );
                return;
              }

              final data = doc.data()!;
              final doctorProfile =
                  data['doctorProfile'] as Map<String, dynamic>?;

              final existingProfile = doctorProfile != null
                  ? Map<String, dynamic>.from(doctorProfile)
                  : <String, dynamic>{};

              if (!context.mounted) return;

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DoctorVerificationScreen(
                    existingProfile: existingProfile,
                  ),
                ),
              );
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error loading profile: $e')),
              );
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.lock_outline),
          tooltip: 'App Lock',
          onPressed: () => _showAppLockDialog(context),
        ),
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Sign Out',
          onPressed: () async {
            await AuthService.signOut();
            navigatorKey.currentState?.pushNamedAndRemoveUntil(
              '/landing',
              (r) => false,
            );
          },
        ),
      ],
    );
  }

  /// Stats Cards Section - Centered
  Widget _buildStatsSection(User user) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collectionGroup('records')
          .where('doctorId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final recordCount = snapshot.data?.docs.length ?? 0;
        final uniquePatients = snapshot.data?.docs
                .map((d) => d['patientId'])
                .toSet()
                .length ??
            0;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _StatCard(
              label: 'Patients',
              count: '$uniquePatients',
              icon: Icons.people_outline,
              color: AppColors.info,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MyPatientsScreen(),
                ),
              ),
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),

            const SizedBox(width: 16),

            _StatCard(
              label: 'Records',
              count: '$recordCount',
              icon: Icons.folder_outlined,
              color: AppColors.warning,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MyRecordsScreen(),
                ),
              ),
            ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
          ],
        );
      },
    );
  }

  /// QR Scanner Section
  Widget _buildQRScannerSection(BuildContext context) {
    return GestureDetector(
      onTap: () => _scanQR(context),
      child: Container(
        height: 320,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.qr_code_scanner,
                size: 80,
                color: AppColors.white,
              ),
            ).animate(onPlay: (controller) => controller.repeat())
              .shimmer(duration: 2000.ms, color: AppColors.white.withOpacity(0.3)),

            const SizedBox(height: 24),

            Text(
              'SCAN PATIENT QR',
              style: AppTextStyles.titleLarge.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Access Records & Write Prescriptions',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.white.withOpacity(0.9),
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
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
                  const Icon(
                    Icons.touch_app,
                    color: AppColors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Tap to Open Scanner',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 400.ms).scale(curve: Curves.elasticOut);
  }

  /// Get time-based greeting
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  /// Show App Lock Dialog
  void _showAppLockDialog(BuildContext context) async {
    bool isEnabled = await AuthService.isAppLockEnabled();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          title: Row(
            children: [
              const Icon(Icons.lock, color: AppColors.primary),
              const SizedBox(width: 12),
              Text('App Lock', style: AppTextStyles.titleMedium),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Require biometric authentication when opening the app for security.',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Enable App Lock',
                  style: AppTextStyles.labelLarge,
                ),
                value: isEnabled,
                activeColor: AppColors.primary,
                onChanged: (val) async {
                  setState(() => isEnabled = val);
                  await AuthService.setAppLockEnabled(val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stat Card Widget
class _StatCard extends StatelessWidget {
  final String label;
  final String count;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _StatCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: PremiumCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: color),
              ),

              const SizedBox(height: 16),

              Text(
                count,
                style: AppTextStyles.displayLarge.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 32,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.mediumGray,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}