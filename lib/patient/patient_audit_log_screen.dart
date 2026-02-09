import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class PatientAuditLogScreen extends StatelessWidget {
  const PatientAuditLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text("Please log in")));

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: Text('Access Transparency Log', style: AppTextStyles.titleMedium.copyWith(color: AppColors.white)),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.primaryGradient,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('audit_chain')
            .where('patientId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Unable to load logs.\n${snapshot.error}"));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          final docs = snapshot.data?.docs ?? [];
          
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppColors.primaryVeryLight,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.shield_outlined,
                      size: 80,
                      color: AppColors.primary.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "No Access Logs Found",
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.mediumGray,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Your data has not been accessed yet",
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.mediumGray.withOpacity(0.7),
                    ),
                  ),
                ],
              ).animate().fadeIn().scale(),
            );
          }

          // Sort manually (Newest First)
          docs.sort((a, b) {
            final tA = (a.data() as Map)['timestamp'] as Timestamp?;
            final tB = (b.data() as Map)['timestamp'] as Timestamp?;
            if (tA == null) return 1;
            if (tB == null) return -1;
            return tB.compareTo(tA);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return _LogCardWrapper(data: data);
            },
          );
        },
      ),
    );
  }
}

class _LogCardWrapper extends StatelessWidget {
  final Map<String, dynamic> data;
  const _LogCardWrapper({required this.data});

  @override
  Widget build(BuildContext context) {
    final action = data['action'] ?? 'UNKNOWN';
    final doctorId = data['doctorId'];
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
    final timeStr = timestamp != null ? DateFormat('MMM dd, hh:mm a').format(timestamp) : 'Unknown Time';
    final reason = data['reason'];

    // Determine Base Style
    IconData icon;
    Color color;
    String title;
    String baseSubtitle;
    String viewerLabel = "Doctor ID"; // Default label

    if (action == 'EMERGENCY_VIEW') {
      icon = Icons.warning_amber_rounded;
      color = AppColors.error;
      title = "Emergency Override Access";
      baseSubtitle = "Reason: ${reason ?? 'Not Specified'}";
      viewerLabel = "Viewer / Responder";
    } else if (action == 'ADD_MEDICAL_RECORD') {
      icon = Icons.post_add;
      color = AppColors.primary;
      title = "New Medical Record Added";
      baseSubtitle = "Doctor ID: ...${doctorId != null && doctorId.length > 5 ? doctorId.substring(doctorId.length - 5) : doctorId}";
    } else if (action == 'DOCTOR_VIEW_HISTORY') {
      icon = Icons.visibility;
      color = AppColors.info;
      title = "Medical History Viewed";
      baseSubtitle = "Doctor ID: ...${doctorId != null && doctorId.length > 5 ? doctorId.substring(doctorId.length - 5) : doctorId}";
    } else {
      icon = Icons.info;
      color = AppColors.mediumGray;
      title = action;
      baseSubtitle = "System Action";
    }

    // Only fetch details if it's a known doctor ID
    if (doctorId != null && doctorId != 'System' && doctorId != 'ANONYMOUS_RESPONDER') {
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(doctorId).get(),
        builder: (context, snapshot) {
          String doctorInfo = baseSubtitle;
          
          if (snapshot.hasData && snapshot.data!.exists) {
            final docData = snapshot.data!.data() as Map<String, dynamic>?;
            final profile = docData?['doctorProfile'] as Map<String, dynamic>?;
            
            String rawName = profile?['fullName'] ?? docData?['name'] ?? 'Unknown';
            final hospital = profile?['hospitalName'] ?? docData?['hospitalName'] ?? 'Unknown Clinic';
            
            if (!rawName.startsWith('Dr.') && !rawName.startsWith('Doctor')) {
              rawName = 'Dr. $rawName';
            }
            
            doctorInfo = "By: $rawName\nFacility: $hospital";
          }

          return _buildCard(icon, color, title, timeStr, doctorInfo, viewerLabel, doctorId);
        },
      );
    } else {
      return _buildCard(icon, color, title, timeStr, baseSubtitle, viewerLabel, doctorId);
    }
  }

  Widget _buildCard(IconData icon, Color color, String title, String timeStr, String subtitle, String viewerLabel, String? idValue) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowSoft,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: AppColors.shadowMedium,
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          title,
          style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            "$timeStr\n$subtitle",
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.mediumGray),
          ),
        ),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Divider(color: AppColors.softGray),
                _detailRow(viewerLabel, idValue),
                const SizedBox(height: 8),
                Text(
                  "BLOCKCHAIN VERIFICATION",
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.mediumGray,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Block Hash: ${data['hash'] ?? 'Pending...'}",
                  style: AppTextStyles.caption.copyWith(
                    fontFamily: 'monospace',
                    color: AppColors.mediumGray,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _detailRow(String label, dynamic value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.mediumGray,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value?.toString() ?? 'N/A',
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}