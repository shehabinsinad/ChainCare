import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/blockchain_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'doctor_patient_view.dart';
import 'add_record_screen.dart';

/// Premium Clinical Gateway Screen
/// Hero patient section + action cards
class DoctorPatientActionScreen extends StatefulWidget {
  final String patientUid;
  const DoctorPatientActionScreen({super.key, required this.patientUid});

  @override
  State<DoctorPatientActionScreen> createState() => _DoctorPatientActionScreenState();
}

class _DoctorPatientActionScreenState extends State<DoctorPatientActionScreen> {
  bool _isLoading = true;
  String _name = "Unknown Patient";
  String? _profilePicUrl;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.patientUid).get();
      if (doc.exists) {
        final data = doc.data()!;
        final profile = data['profile'] as Map<String, dynamic>?;
        setState(() {
          _name = profile?['name'] ?? data['name'] ?? "Unknown Patient";
          _profilePicUrl = data['profilePicUrl'];
        });
      }
    } catch (_) {} finally {
      setState(() => _isLoading = false);
    }
  }

  void _nav(bool readOnly) async {
    if (readOnly) {
      // Log View
      await BlockchainService.logTransaction(
        action: "DOCTOR_VIEW_HISTORY",
        patientId: widget.patientUid,
        doctorId: FirebaseAuth.instance.currentUser?.uid ?? 'System',
        details: "Viewed Medical History",
      );
      if(!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => DoctorPatientView(patientUid: widget.patientUid, isReadOnly: true)));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => AddRecordScreen(patientUid: widget.patientUid)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : CustomScrollView(
            slivers: [
              // Premium Gradient AppBar
              SliverAppBar(
                expandedHeight: 120,
                pinned: true,
                backgroundColor: AppColors.primary,
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: true,
                  title: Text(
                    "Clinical Gateway",
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                    ),
                  ),
                ),
              ),
              
              // Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Hero Patient Section
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                          BoxShadow(
                            color: AppColors.deepCharcoal.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                        ),
                        child: Column(
                          children: [
                            // Avatar with glow
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.deepCharcoal.withOpacity(0.15),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                              ),
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: AppColors.primary.withOpacity(0.1),
                                backgroundImage: _profilePicUrl != null
                                    ? NetworkImage(_profilePicUrl!)
                                    : null,
                                child: _profilePicUrl == null
                                    ? Text(
                                        _name[0].toUpperCase(),
                                        style: AppTextStyles.displayLarge.copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      )
                                    : null,
                              ),
                            ).animate().scale(delay: 100.ms, curve: Curves.elasticOut),
                            
                            const SizedBox(height: 16),
                            
                            Text(
                              _name,
                              style: AppTextStyles.titleLarge.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ).animate().fadeIn(delay: 200.ms),
                            
                            const SizedBox(height: 8),
                            
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primary.withOpacity(0.1),
                                    AppColors.primary.withOpacity(0.05),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.badge,
                                    size: 16,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "ID: ...${widget.patientUid.substring(widget.patientUid.length - 6)}",
                                    style: AppTextStyles.labelMedium.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ).animate().fadeIn(delay: 300.ms),
                          ],
                        ),
                      ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2, end: 0),
                      
                      const SizedBox(height: 32),
                      
                      // Action Cards
                      _buildActionCard(
                        title: "View Medical History",
                        subtitle: "Read-only access",
                        icon: Icons.history_edu,
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF4A90E2), // Vibrant blue
                            Color(0xFF357ABD), // Deeper blue
                          ],
                        ),
                        onTap: () => _nav(true),
                        delay: 400,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      _buildActionCard(
                        title: "Add New Record",
                        subtitle: "Write diagnosis & notes",
                        icon: Icons.post_add,
                        gradient: AppColors.primaryGradient,
                        onTap: () => _nav(false),
                        delay: 500,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Gradient gradient,
    required VoidCallback onTap,
    required int delay,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: AppColors.white,
                size: 32,
              ),
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
              color: AppColors.white,
              size: 16,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: delay.ms).slideX(begin: 0.2, end: 0);
  }
}