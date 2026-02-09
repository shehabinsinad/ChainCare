import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AdminVerificationDetail extends StatefulWidget {
  final String doctorUid;
  final Map<String, dynamic> doctorData;

  const AdminVerificationDetail({super.key, required this.doctorUid, required this.doctorData});

  @override
  State<AdminVerificationDetail> createState() => _AdminVerificationDetailState();
}

class _AdminVerificationDetailState extends State<AdminVerificationDetail> {
  bool _isProcessing = false;

  Future<void> _decide(bool approve) async {
    String? rejectionReason;
    if (!approve) {
      final TextEditingController reasonCtrl = TextEditingController();
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Rejection Reason'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please provide a reason for rejection:'),
              const SizedBox(height: 16),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'e.g., License document is unclear',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Reject', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      
      if (result != true) return;
      rejectionReason = reasonCtrl.text.trim();
    }

    setState(() => _isProcessing = true);
    try {
      if (approve) {
        await FirebaseFirestore.instance.collection('users').doc(widget.doctorUid).update({
          'isVerified': true,
          'isRejected': false,
          'verificationSubmitted': true,
          'verifiedAt': FieldValue.serverTimestamp(),
          'rejectionReason': FieldValue.delete(),
        });
      } else {
        await FirebaseFirestore.instance.collection('users').doc(widget.doctorUid).update({
          'isVerified': false,
          'isRejected': true,
          'verificationSubmitted': true,
          'rejectionReason': rejectionReason?.isNotEmpty == true ? rejectionReason : 'Your verification was not approved. Please review your documents.',
          'rejectedAt': FieldValue.serverTimestamp(),
        });
      }
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve ? "Doctor Approved ✅" : "Doctor Rejected ❌"),
            backgroundColor: approve ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doctorProfile = widget.doctorData['doctorProfile'] as Map<String, dynamic>?;
    
    final name = doctorProfile?['name'] ?? widget.doctorData['name'] ?? 'N/A';
    final email = widget.doctorData['email'] ?? 'N/A';
    final specialization = doctorProfile?['specialization'] ?? 'N/A';
    final licenseNumber = doctorProfile?['licenseNumber'] ?? 'N/A';
    final hospital = doctorProfile?['hospitalName'] ?? 'N/A';
    final phone = doctorProfile?['phone'] ?? 'N/A';
    final licenseImageUrl = doctorProfile?['idDocumentUrl'];
    final aiConfidence = (doctorProfile?['aiConfidenceScore'] ?? 0.0) as double;
    final aiFlags = (doctorProfile?['aiFlags'] ?? []) as List;
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Review Application", style: TextStyle(fontWeight: FontWeight.bold)),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF3949AB), Color(0xFF5E35B1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER CARD
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white, Colors.grey.shade50],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF3949AB), Color(0xFF5E35B1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF3949AB).withOpacity(0.3),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(Icons.person, size: 36, color: Colors.white),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          email,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                          softWrap: true,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),

            const SizedBox(height: 24),

            // DOCUMENT PREVIEW
            Text("Uploaded ID / License", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 12),
            Container(
              height: 280,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      color: Colors.grey[100],
                      child: licenseImageUrl != null && licenseImageUrl.toString().isNotEmpty
                          ? Image.network(
                              licenseImageUrl,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              loadingBuilder: (ctx, child, loading) {
                                if (loading == null) return child;
                                return const Center(child: CircularProgressIndicator());
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.broken_image, size: 50, color: Colors.grey[400]),
                                      const SizedBox(height: 12),
                                      Text(
                                        "Image failed to load",
                                        style: TextStyle(color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            )
                          : const Center(child: Text("No ID Document Uploaded")),
                    ),
                  ),
                  if (licenseImageUrl != null)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.zoom_in, size: 20, color: Colors.grey[700]),
                      ),
                    ),
                ],
              ),
            ).animate().fadeIn(delay: 200.ms),

            const SizedBox(height: 24),

            // AI VALIDATION CARD
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: aiConfidence > 0.7
                      ? [Colors.green.shade50, Colors.green.shade100]
                      : (aiConfidence > 0.4
                          ? [Colors.orange.shade50, Colors.orange.shade100]
                          : [Colors.red.shade50, Colors.red.shade100]),
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: aiConfidence > 0.7
                      ? Colors.green.withOpacity(0.3)
                      : (aiConfidence > 0.4 ? Colors.orange.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: aiConfidence > 0.7
                                ? [Colors.green.shade400, Colors.green.shade600]
                                : (aiConfidence > 0.4
                                    ? [Colors.orange.shade400, Colors.orange.shade600]
                                    : [Colors.red.shade400, Colors.red.shade600]),
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.psychology, color: Colors.white, size: 24),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          "AI Validation Report",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: aiConfidence > 0.7
                                ? [Colors.green, Colors.green.shade700]
                                : (aiConfidence > 0.4 ? [Colors.orange, Colors.orange.shade700] : [Colors.red, Colors.red.shade700]),
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: (aiConfidence > 0.7 ? Colors.green : (aiConfidence > 0.4 ? Colors.orange : Colors.red)).withOpacity(0.3),
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          "${(aiConfidence * 100).toInt()}% Match",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (aiFlags.isEmpty)
                    Text("No AI analysis available.", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[700]))
                  else
                    ...aiFlags.map((flag) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: flag.toString().contains("❌") || flag.toString().contains("⛔")
                                      ? Colors.red.withOpacity(0.2)
                                      : Colors.green.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  flag.toString().contains("❌") || flag.toString().contains("⛔") ? Icons.close : Icons.check,
                                  size: 16,
                                  color: flag.toString().contains("❌") || flag.toString().contains("⛔") ? Colors.red : Colors.green,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text(flag.toString(), style: const TextStyle(fontSize: 14))),
                            ],
                          ),
                        )),
                ],
              ),
            ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.1, end: 0),

            const SizedBox(height: 24),

            // DETAILS SECTION
            Text("Verification Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 12),
            _detailCard("Specialization", specialization, Icons.medical_services),
            _detailCard("License Number", licenseNumber, Icons.badge),
            _detailCard("Hospital", hospital, Icons.local_hospital),
            _detailCard("Phone", phone, Icons.phone),

            const SizedBox(height: 32),

            // ACTION BUTTONS
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.red.shade400, Colors.red.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.3),
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : () => _decide(false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isProcessing
                          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.close, color: Colors.white),
                                SizedBox(width: 8),
                                Text("REJECT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade400, Colors.green.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.3),
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : () => _decide(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isProcessing
                          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check, color: Colors.white),
                                SizedBox(width: 8),
                                Text("APPROVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0),
          ],
        ),
      ),
    );
  }

  Widget _detailCard(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3949AB).withOpacity(0.1), Color(0xFF5E35B1).withOpacity(0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: Color(0xFF3949AB)),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 350.ms).slideX(begin: 0.05, end: 0);
  }
}