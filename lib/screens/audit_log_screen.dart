import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AuditLogScreen extends StatelessWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Blockchain Audit Trail', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('audit_chain').orderBy('index', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text("Ledger Empty"));

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            // ✅ FIX: Changed (_, __) to (_, index)
            separatorBuilder: (_, index) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Icon(Icons.link, color: Colors.grey.shade300),
            ),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return _AuditBlockCard(data: data);
            },
          );
        },
      ),
    );
  }
}

class _AuditBlockCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AuditBlockCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
    final timeStr = timestamp != null ? DateFormat('yyyy-MM-dd HH:mm:ss UTC').format(timestamp.toUtc()) : 'Unknown';
    
    String details = data['details'] ?? '';
    if (data['action'] == 'EMERGENCY_VIEW') {
      details = details.replaceAll(RegExp(r'DoctorID:.*'), "ResponderID: ANONYMOUS");
    }
    String formattedDetails = details.replaceAll("|", "\n").trim();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("BLOCK #${data['index']}", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.blueGrey.shade800, fontFamily: 'monospace')),
                Text(timeStr, style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600, fontFamily: 'monospace')),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Text("ACTION: ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  Text(data['action'] ?? 'UNKNOWN', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                ]),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E), 
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade800)
                  ),
                  child: Text(
                    formattedDetails.isEmpty ? "No additional details payload." : formattedDetails,
                    style: const TextStyle(
                      fontFamily: 'monospace', 
                      fontSize: 11, 
                      color: Color(0xFF00FF00), 
                      height: 1.4 
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(),
                _hashInfo("PREV HASH", data['previousHash']),
                _hashInfo("BLOCK HASH", data['hash']),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hashInfo(String label, String? hash) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 70, child: Text("$label:", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))),
          Expanded(child: Text(hash ?? 'NULL', style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.black87), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}