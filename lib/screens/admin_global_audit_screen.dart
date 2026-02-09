import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

class AdminGlobalAuditScreen extends StatefulWidget {
  const AdminGlobalAuditScreen({super.key});

  @override
  State<AdminGlobalAuditScreen> createState() => _AdminGlobalAuditScreenState();
}

class _AdminGlobalAuditScreenState extends State<AdminGlobalAuditScreen> {
  bool _showOnlyEmergencies = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('System Audit Ledger', style: TextStyle(fontWeight: FontWeight.bold)),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF263238), Color(0xFF37474F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_showOnlyEmergencies ? Icons.filter_alt : Icons.filter_alt_outlined),
            tooltip: _showOnlyEmergencies ? 'Show All' : 'Emergency Only',
            onPressed: () => setState(() => _showOnlyEmergencies = !_showOnlyEmergencies),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 80, color: Colors.green.withOpacity(0.3)),
                  SizedBox(height: 16),
                  Text("No audit logs found", style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              return _AdminLogCard(data: docs[index].data() as Map<String, dynamic>)
                  .animate()
                  .fadeIn(delay: (50 * index).ms, duration: 400.ms)
                  .slideX(begin: 0.1, end: 0);
            },
          );
        },
      ),
    );
  }

  Stream<QuerySnapshot> _getStream() {
    var ref = FirebaseFirestore.instance.collection('audit_chain').orderBy('timestamp', descending: true);
    if (_showOnlyEmergencies) return ref.where('action', isEqualTo: 'EMERGENCY_VIEW').snapshots();
    return ref.snapshots();
  }
}

class _AdminLogCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AdminLogCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final action = data['action'] ?? 'UNKNOWN';
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
    final timeStr = timestamp != null ? DateFormat('MMM dd, HH:mm').format(timestamp) : '--';
    final isEmergency = action == 'EMERGENCY_VIEW';

    String hash = data['hash'] ?? '';
    String displayHash = hash.length > 10 ? "${hash.substring(0, 10)}..." : hash;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(
            color: isEmergency ? Colors.red : Colors.grey.shade300,
            width: 4,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: (isEmergency ? Colors.red : Colors.grey).withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isEmergency
                    ? [Colors.red.shade400, Colors.red.shade600]
                    : [Colors.green.shade400, Colors.green.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isEmergency ? Icons.warning_rounded : Icons.check_circle,
              color: Colors.white,
              size: 20,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  action,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isEmergency ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isEmergency ? 'EMERGENCY' : 'SUCCESS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isEmergency ? Colors.red.shade700 : Colors.green.shade700,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(
                  timeStr,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                SizedBox(width: 12),
                Icon(Icons.fingerprint, size: 14, color: Colors.grey[600]),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    displayHash,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.description, size: 16, color: Colors.grey[700]),
                      SizedBox(width: 8),
                      Text(
                        "DETAILS PAYLOAD:",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      data['details'] ?? 'No details',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.lock, size: 16, color: Colors.grey[700]),
                      SizedBox(width: 8),
                      Text(
                        "BLOCKCHAIN HASH:",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: SelectableText(
                      hash,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}