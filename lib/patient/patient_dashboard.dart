import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../auth/auth_service.dart';
import '../app/app.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/premium_card.dart';
import '../screens/qr_display_screen.dart';
import '../screens/patient_records_screen.dart';
import '../screens/patient_ai_chat_screen.dart';
import 'patient_profile_screen.dart';
import 'patient_audit_log_screen.dart';

/// Premium Patient Dashboard
/// Modern, card-based layout with stats and quick actions
class PatientDashboard extends StatelessWidget {
  const PatientDashboard({super.key});

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
          // Premium AppBar
          _buildPremiumAppBar(context, user),
          
          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats Cards
                  _buildStatsSection(user),
                  
                  const SizedBox(height: 32),
                  
                  // Quick Actions Header
                  Text(
                    'Quick Actions',
                    style: AppTextStyles.titleLarge,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Quick Actions Grid
                  _buildQuickActions(context, user),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Premium AppBar with gradient
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
                  String name = "Patient";
                  String? picUrl;
                  
                  if (snapshot.hasData && snapshot.data!.exists) {
                    final data = snapshot.data!.data() as Map<String, dynamic>;
                    name = data['name'] ?? 'Patient';
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
                                  name.isNotEmpty ? name[0].toUpperCase() : 'P',
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
                              name,
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
        // App Lock Icon
        IconButton(
          icon: const Icon(Icons.lock_outline, color: AppColors.white),
          tooltip: 'App Lock',
          onPressed: () => _showAppLockDialog(context),
        ),
        
       // Sign Out Icon
        IconButton(
          icon: const Icon(Icons.logout, color: AppColors.white),
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

  /// Get time-based greeting
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  /// Stats Section with cards
  Widget _buildStatsSection(User user) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('records')
          .snapshots(),
      builder: (context, snapshot) {
        final recordCount = snapshot.data?.docs.length ?? 0;
        
        return Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.folder_outlined,
                value: recordCount.toString(),
                label: 'Docs',
                color: AppColors.info,
              ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2, end: 0),
            ),
            
            const SizedBox(width: 16),
            
            Expanded(
              child: _StatCard(
                icon: Icons.psychology,
                value: 'AI',
                label: 'Assistant',
                color: AppColors.primary,
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
            ),
            
            const SizedBox(width: 16),
            
            Expanded(
              child: _StatCard(
                icon: Icons.verified_user,
                value: '100%',
                label: 'Secure',
                color: AppColors.success,
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
            ),
          ],
        );
      },
    );
  }

  /// Quick Actions Grid
  Widget _buildQuickActions(BuildContext context, User user) {
    return Column(
      children: [
        _QuickActionCard(
          title: 'My Medical ID',
          subtitle: 'Show QR to Doctor',
          icon: Icons.qr_code_2,
          gradient: LinearGradient(
            colors: [Colors.blue.shade400, Colors.blue.shade600],
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const QrDisplayScreen()),
          ),
        ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.2, end: 0),
        
        const SizedBox(height: 12),
        
        _QuickActionCard(
          title: 'Medical Records',
          subtitle: 'View History & Reports',
          icon: Icons.folder_special,
          gradient: AppColors.primaryGradient,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PatientRecordsScreen()),
          ),
        ).animate().fadeIn(delay: 150.ms).slideX(begin: -0.2, end: 0),
        
        const SizedBox(height: 12),
        
        _QuickActionCard(
          title: 'Medical Assistant',
          subtitle: 'AI-Powered Health Insights',
          icon: Icons.psychology,
          gradient: LinearGradient(
            colors: [AppColors.info, Colors.indigo.shade700],
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PatientAIChatScreen()),
          ),
        ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.2, end: 0),
        
        const SizedBox(height: 12),
        
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                title: 'Access Logs',
                subtitle: 'See who viewed',
                icon: Icons.shield_outlined,
                gradient: LinearGradient(
                  colors: [Colors.orange.shade400, Colors.orange.shade600],
                ),
                isCompact: true,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PatientAuditLogScreen(),
                  ),
                ),
              ).animate().fadeIn(delay: 250.ms).scale(),
            ),
            
            const SizedBox(width: 12),
            
            Expanded(
              child: _QuickActionCard(
                title: 'Edit Profile',
                subtitle: 'Update details',
                icon: Icons.person_outline,
                gradient: LinearGradient(
                  colors: [Colors.purple.shade400, Colors.purple.shade600],
                ),
                isCompact: true,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PatientProfileScreen(isSetup: false),
                  ),
                ),
              ).animate().fadeIn(delay: 300.ms).scale(),
            ),
          ],
        ),
      ],
    );
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
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          
          const SizedBox(height: 12),
          
          Text(
            value,
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          
          const SizedBox(height: 4),
          
          Text(
            label,
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Quick Action Card
class _QuickActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;
  final bool isCompact;

  const _QuickActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return GradientCard(
        onTap: onTap,
        gradient: gradient,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 32, color: AppColors.white),
            const SizedBox(height: 12),
            Text(
              title,
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.white.withOpacity(0.9),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    return GradientCard(
      onTap: onTap,
      gradient: gradient,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.white.withOpacity(0.25),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28, color: AppColors.white),
          ),
          
          const SizedBox(width: 16),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.titleSmall.copyWith(
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
          
          Icon(
            Icons.arrow_forward_ios,
            size: 18,
            color: AppColors.white.withOpacity(0.8),
          ),
        ],
      ),
    );
  }
}