import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EmergencyView extends StatelessWidget {
  final String patientUid;
  const EmergencyView({super.key, required this.patientUid});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red[50],
      appBar: AppBar(
        title: const Text("Critical Medical Info"), 
        backgroundColor: Colors.red, 
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // Prevent going back easily
        actions: [
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
        ],
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(patientUid).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.red));
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Patient ID Not Found in Database"));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          // Handle both root level and profile map level data
          final profile = data['profile'] as Map<String, dynamic>? ?? {};
          
          final name = profile['name'] ?? data['name'] ?? "Unknown";
          final blood = profile['bloodGroup'] ?? "Unknown";
          final allergies = profile['allergies'] ?? "None";
          final conditions = profile['conditions'] ?? "None";
          final contactName = profile['emergencyContactName'];
          final contactPhone = profile['emergencyContactPhone'];

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200)),
                child: Column(
                  children: [
                    const Icon(Icons.medical_services, size: 50, color: Colors.red),
                    const SizedBox(height: 8),
                    Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const Text("Patient Identity Verified", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _alertCard("Blood Group", blood, isHighlight: true),
              _alertCard("Allergies", allergies, isHighlight: true),
              _alertCard("Medical Conditions", conditions),
              
              const Divider(height: 40, thickness: 2),
              const Text("EMERGENCY CONTACT", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 16)),
              const SizedBox(height: 12),
              Card(
                elevation: 2,
                child: ListTile(
                  leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.phone, color: Colors.white)),
                  title: Text(contactName ?? "Not Listed", style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(contactPhone ?? "No Phone"),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _alertCard(String title, String value, {bool isHighlight = false}) {
    return Card(
      color: isHighlight ? Colors.red.shade100 : Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isHighlight ? Colors.red.shade900 : Colors.black)),
      ),
    );
  }
}