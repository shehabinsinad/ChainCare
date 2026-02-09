import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../auth/auth_service.dart';
import '../app/app.dart';
import 'admin_verification_detail.dart';
import 'admin_global_audit_screen.dart';
import 'blockchain_verification_screen.dart';
 

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Admin Command Center", style: TextStyle(fontWeight: FontWeight.bold)),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF00897B), Color(0xFF00ACC1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService.signOut();
              navigatorKey.currentState?.pushNamedAndRemoveUntil('/landing', (route) => false);
            },
          )
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildStatsHeader(context)),
          
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _adminActionCard(
                context,
                title: "Global Blockchain Ledger",
                subtitle: "Audit system-wide access logs",
                icon: Icons.gavel_rounded,
                color: const Color(0xFF263238),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminGlobalAuditScreen())),
              ),
            ),
          ),

          // Blockchain Verification Card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _adminActionCard(
                context,
                title: "Blockchain Verification",
                subtitle: "View daily blockchain anchors",
                icon: Icons.verified_user,
                color: const Color(0xFF512DA8),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BlockchainVerificationScreen())),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Text("PENDING VERIFICATIONS", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.grey[600], letterSpacing: 1.2)),
            ),
          ),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users')
                .where('role', isEqualTo: 'doctor')
                .where('verificationSubmitted', isEqualTo: true)
                .where('isVerified', isEqualTo: false)
                .where('isRejected', isEqualTo: false) // ✅ Filter out rejected doctors
                .where('doctorProfile', isNull: false)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return SliverToBoxAdapter(child: Center(child: Text("Error: ${snapshot.error}")));
              
              final docs = snapshot.data?.docs ?? [];
              
              if (docs.isEmpty) {
                return SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(40),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Icon(Icons.verified_user_outlined, size: 60, color: Colors.green.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        Text("All Clear!", style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text("No pending doctor applications.", style: TextStyle(color: Colors.grey[400])),
                      ],
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final profile = data['doctorProfile'] ?? {};
                    return _buildDoctorCard(context, doc.id, data, profile);
                  },
                  childCount: docs.length,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorCard(BuildContext context, String uid, Map<String, dynamic> data, Map<String, dynamic> profile) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Card(
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminVerificationDetail(doctorUid: uid, doctorData: data))),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF00897B), Color(0xFF00ACC1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.person, color: Colors.white, size: 24),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile['name'] ?? 'Unknown',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 6),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Color(0xFF00897B).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              profile['specialization'] ?? 'Doctor',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF00897B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.grey[400], size: 24),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(color: Colors.grey[300]),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.badge_outlined, size: 16, color: Colors.grey[600]),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Registration: ${profile['registrationNumber'] ?? 'N/A'}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[600]),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        profile['hospitalAddress'] ?? profile['hospitalName'] ?? 'N/A',
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.phone_outlined, size: 16, color: Colors.grey[600]),
                    SizedBox(width: 8),
                    Text(
                      profile['phone'] ?? 'N/A',
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                    if (profile['phoneVerified'] == true) ...[
                      SizedBox(width: 6),
                      Icon(Icons.verified, size: 16, color: Colors.green),
                      SizedBox(width: 2),
                      Text(
                        'Verified',
                        style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.search, size: 16),
                        label: const Text('Google', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          side: BorderSide(color: Color(0xFF00897B)),
                          foregroundColor: Color(0xFF00897B),
                        ),
                        onPressed: () {
                          final name = profile['name'] ?? '';
                          final regNum = profile['registrationNumber'] ?? '';
                          final query = Uri.encodeComponent('$name $regNum doctor medical council');
                          launchUrl(Uri.parse('https://www.google.com/search?q=$query'));
                        },
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.map, size: 16),
                        label: const Text('Maps', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          side: BorderSide(color: Color(0xFF1976D2)),
                          foregroundColor: Color(0xFF1976D2),
                        ),
                        onPressed: () {
                          final address = profile['hospitalAddress'] ?? profile['hospitalName'] ?? '';
                          final query = Uri.encodeComponent(address);
                          launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=$query'));
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.1, end: 0),
    );
  }

  Widget _buildStatsHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF00897B), Color(0xFF00ACC1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF00897B).withOpacity(0.3),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dashboard_rounded, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Text(
                "System Overview",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.2, end: 0),
          const SizedBox(height: 24),
          Row(
            children: [
              _countTile("Doctors", 'users', 'doctor', Icons.medical_services, [Color(0xFF00897B), Color(0xFF00796B)]),
              const SizedBox(width: 12),
              _countTile("Patients", 'users', 'patient', Icons.people, [Color(0xFF1976D2), Color(0xFF1565C0)]),
              const SizedBox(width: 12),
              _recordCountTile(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _countTile(String label, String collection, String role, IconData icon, List<Color> gradientColors) {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: role == 'doctor'
            ? FirebaseFirestore.instance
                .collection(collection)
                .where('role', isEqualTo: role)
                .where('isVerified', isEqualTo: true)
                .snapshots()
            : FirebaseFirestore.instance
                .collection(collection)
                .where('role', isEqualTo: role)
                .snapshots(),
        builder: (context, snap) {
          final count = snap.data?.docs.length ?? 0;
          return _statBox(label, count.toString(), icon, gradientColors);
        },
      ),
    );
  }

  Widget _recordCountTile() {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collectionGroup('records').snapshots(),
        builder: (context, snap) {
          final count = snap.data?.docs.length ?? 0;
          return _statBox("Records", count.toString(), Icons.folder_open, [Color(0xFF7B1FA2), Color(0xFF6A1B9A)]);
        },
      ),
    );
  }

  Widget _statBox(String label, String count, IconData icon, List<Color> gradientColors) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withOpacity(0.4),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          SizedBox(height: 12),
          Text(
            count,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.95),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 600.ms).scale(begin: Offset(0.8, 0.8), end: Offset(1, 1));
  }

  Widget _adminActionCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.grey.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
          // Diagonal stripe pattern
          image: DecorationImage(
            image: NetworkImage('data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAiIGhlaWdodD0iNDAiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+PGRlZnM+PHBhdHRlcm4gaWQ9ImEiIHBhdHRlcm5Vbml0cz0idXNlclNwYWNlT25Vc2UiIHdpZHRoPSI0MCIgaGVpZ2h0PSI0MCIgcGF0dGVyblRyYW5zZm9ybT0icm90YXRlKDQ1KSI+PHJlY3QgeD0iMCIgeT0iMCIgd2lkdGg9IjIwIiBoZWlnaHQ9IjQwIiBmaWxsPSJyZ2JhKDAsIDAsIDAsIDAuMDIpIi8+PC9wYXR0ZXJuPjwvZGVmcz48cmVjdCB3aWR0aD0iMTAwJSIgaGVpZ2h0PSIxMDAlIiBmaWxsPSJ1cmwoI2EpIi8+PC9zdmc+'),
            repeat: ImageRepeat.repeat,
            opacity: 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, size: 32, color: Colors.white),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 20),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0);
  }
}