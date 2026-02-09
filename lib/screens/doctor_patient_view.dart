import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'add_record_screen.dart';
import 'doctor_clinical_assistant_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart'; 

class DoctorPatientView extends StatefulWidget {
  final String patientUid;
  final bool showOnlyMyRecords; 
  final bool isReadOnly; 

  const DoctorPatientView({
    super.key, 
    required this.patientUid,
    this.showOnlyMyRecords = false, 
    this.isReadOnly = false, 
  });

  @override
  State<DoctorPatientView> createState() => _DoctorPatientViewState();
}

class _DoctorPatientViewState extends State<DoctorPatientView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _patientProfile;
  String? _patientName; 
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchPatientDetails();
  }

  Future<void> _fetchPatientDetails() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.patientUid).get();
      if (doc.exists) {
        final data = doc.data()!;
        var profile = data['profile'] as Map<String, dynamic>?;
        
        // Robust fallback for name
        final name = profile?['name'] ?? data['name'] ?? 'Unknown Patient';
        
        setState(() {
          _patientProfile = profile ?? {}; // Ensure it's not null to avoid crashes later
          _patientName = name;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: Text('Patient Medical File', style: AppTextStyles.titleMedium.copyWith(color: AppColors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.primaryGradient,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontSize: 14),
          labelColor: AppColors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.person_outline), text: 'Profile & Vitals'),
            Tab(icon: Icon(Icons.history_edu), text: 'Clinical History'),
          ],
        ),
      ),
      body: _loading 
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _patientProfile == null 
              ? const Center(child: Text("Patient Profile Not Found"))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildProfileTab(),
                    _buildHistoryTab(), 
                  ],
                ),
      floatingActionButton: widget.isReadOnly 
          ? null 
          : FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.edit_note, color: AppColors.white),
              label: Text('Add Clinical Note', style: AppTextStyles.labelLarge.copyWith(color: AppColors.white)),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => AddRecordScreen(patientUid: widget.patientUid)));
              },
              elevation: 4,
            ).animate().fadeIn(delay: 200.ms).scale(delay: 200.ms),
    );
  }

  Widget _buildProfileTab() {
    final p = _patientProfile!;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // 1. IDENTITY HEADER - Premium Card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepCharcoal.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar with gradient ring
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(3),
                child: CircleAvatar(
                  radius: 35,
                  backgroundColor: AppColors.white,
                  child: CircleAvatar(
                    radius: 33,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: Text(
                      (_patientName ?? "?")[0].toUpperCase(),
                      style: TextStyle(fontSize: 30, color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _patientName ?? "Unknown", 
                      style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold, fontSize: 19),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "ID: ...${widget.patientUid.length > 6 ? widget.patientUid.substring(widget.patientUid.length - 6) : widget.patientUid}", 
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.mediumGray),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _tag(p['gender'] ?? 'N/A', AppColors.info),
                        _tag(p['bloodGroup'] ?? 'N/A', AppColors.error),
                      ],
                    )
                  ],
                ),
              )
            ],
          ),
        ).animate().fadeIn(delay: 50.ms).slideY(begin: -0.1, end: 0),
        
        const SizedBox(height: 24),
        Text(
          "VITALS & CONTACT", 
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.mediumGray, 
            fontWeight: FontWeight.bold, 
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),

        // 2. DETAILED INFO GRID - Premium Card
        _sectionContainer([
          _detailRow(Icons.height, "Height", "${p['height'] ?? '--'} cm"),
          const Divider(height: 24, color: AppColors.softGray),
          _detailRow(Icons.monitor_weight, "Weight", "${p['weight'] ?? '--'} kg"),
          const Divider(height: 24, color: AppColors.softGray),
          _detailRow(Icons.phone, "Phone", p['phone'] ?? 'N/A'),
          const Divider(height: 24, color: AppColors.softGray),
          Row(
            children: [
              Icon(Icons.home, size: 20, color: AppColors.mediumGray),
              const SizedBox(width: 16),
              Text("Address", style: AppTextStyles.bodyMedium.copyWith(color: AppColors.mediumGray)),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  p['address'] ?? 'N/A',
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ],
          ),
        ]).animate().fadeIn(delay: 100.ms).slideY(begin: -0.1, end: 0),

        const SizedBox(height: 24),
        Text(
          "MEDICAL ALERTS", 
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.mediumGray, 
            fontWeight: FontWeight.bold, 
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),

        // 3. ALERTS SECTION - Premium Card
        _sectionContainer([
          _alertRow("Chronic Conditions", p['conditions'] ?? 'None', Icons.favorite),
          const Divider(height: 24, color: AppColors.softGray),
          _alertRow("Allergies", p['allergies'] ?? 'None', Icons.warning_amber),
        ]).animate().fadeIn(delay: 150.ms).slideY(begin: -0.1, end: 0),
      ],
    );
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1), 
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text, 
        style: AppTextStyles.labelSmall.copyWith(
          color: color, 
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _sectionContainer(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepCharcoal.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.mediumGray),
        const SizedBox(width: 16),
        Text(label, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.mediumGray)),
        const Spacer(),
        Text(value, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _alertRow(String label, String value, IconData icon) {
    bool hasIssue = value.toLowerCase() != 'none' && value.isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon, 
          size: 20, 
          color: hasIssue ? AppColors.error : AppColors.mediumGray,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label, 
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.mediumGray),
              ),
              const SizedBox(height: 4),
              Text(
                value, 
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600, 
                  color: hasIssue ? AppColors.deepCharcoal : AppColors.mediumGray,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- HISTORY TAB ---
  Widget _buildHistoryTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.patientUid)
          .collection('records')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        final records = snapshot.data!.docs;
        
        return Column(
          children: [
            // AI Clinical Assistant Button
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF00796B), const Color(0xFF009688)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF009688).withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DoctorClinicalAssistantScreen(
                          patientId: widget.patientUid,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.psychology,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ask AI about Patient',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Get clinical insights from medical history',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Records list
            if (records.isEmpty)
              const Expanded(
                child: Center(child: Text("No medical history available.")),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final data = records[index].data() as Map<String, dynamic>;
                    final date = (data['timestamp'] as Timestamp?)?.toDate();
                    final dateStr = date != null ? DateFormat('MMM dd, yyyy').format(date) : 'Unknown';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.deepCharcoal.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // Left gradient accent
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            child: Container(
                              width: 4,
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  bottomLeft: Radius.circular(16),
                                ),
                              ),
                            ),
                          ),
                          
                          // Content
                          ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            title: Text(
                              data['diagnosis'] ?? 'Clinical Note', 
                              style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                "Dr. ${data['doctorName'] ?? 'Unknown'} • $dateStr", 
                                style: AppTextStyles.bodySmall.copyWith(color: AppColors.mediumGray),
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.info.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.open_in_new, color: AppColors.info, size: 20),
                                onPressed: () async {
                                  if (data['fileUrl'] != null) {
                                    final uri = Uri.parse(data['fileUrl']);
                                    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: (50 * index).ms).slideX(begin: -0.1, end: 0);
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}