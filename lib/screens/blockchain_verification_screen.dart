import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../services/blockchain_service.dart';
import '../services/merkle_tree_service.dart';

class BlockchainVerificationScreen extends StatelessWidget {
  const BlockchainVerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blockchain Verification'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(context),
            tooltip: 'How it works',
          ),
        ],
      ),
      body: Column(
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.deepPurple.withOpacity(0.1),
            child: Row(
              children: [
                const Icon(Icons.verified_user, color: Colors.deepPurple),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Blockchain-Verified Audit Trail',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Daily hashes posted to Polygon Amoy testnet',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // List of blockchain anchors
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('blockchain_anchors')
                  .orderBy('date', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final anchors = snapshot.data!.docs;

                if (anchors.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No blockchain posts yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Daily hashes will appear here automatically',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Scheduled: Daily at midnight UTC (05:30 IST)',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: anchors.length,
                  itemBuilder: (context, index) {
                    final data = anchors[index].data() as Map<String, dynamic>;
                    return _BlockchainAnchorCard(
                      data: data,
                      docId: anchors[index].id,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showVerificationDialog(context),
        icon: const Icon(Icons.verified_user),
        label: const Text('Verify Integrity'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.deepPurple),
            const SizedBox(width: 8),
            Flexible(
              child: const Text(
                'How Blockchain Verification Works',
                maxLines: 3,
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
              const Text(
                'Our hybrid blockchain system provides tamper-proof audit logs:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildInfoStep('1', 'Real-Time Logging',
                  'Every medical access is logged immediately in our database with hash chains.'),
              _buildInfoStep('2', 'Daily Aggregation',
                  'Every 24 hours, we compute a Merkle root hash of all that day\'s logs.'),
              _buildInfoStep('3', 'Blockchain Posting',
                  'We post this single hash to Polygon blockchain (public, immutable).'),
              _buildInfoStep('4', 'Verification',
                  'Anyone can verify our database matches the blockchain proof.'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'If hashes match = Data is authentic\nIf hashes differ = Tampering detected',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoStep(String number, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.deepPurple,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showVerificationDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify Audit Trail Integrity'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This will verify the latest daily hash:'),
            SizedBox(height: 12),
            Text('1. Fetch audit entries from database'),
            Text('2. Recompute Merkle root'),
            Text('3. Compare with blockchain hash'),
            SizedBox(height: 16),
            Text(
              'If hashes match ✅ = Data is authentic\nIf mismatch ⚠️ = Tampering detected',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              _performVerification(context);
            },
            child: const Text('Verify Now'),
          ),
        ],
      ),
    );
  }

  Future<void> _performVerification(BuildContext context) async {
    print('🔍 _performVerification called!');
    
    // CRITICAL: Save the overlay context BEFORE any async operations
    // This context persists even after widgets are disposed
    final overlayContext = Navigator.of(context).overlay!.context;
    
    // Show loading dialog and store its context
    late BuildContext dialogContext;
    
    print('📱 About to show dialog...');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        print('📱 Dialog builder called');
        dialogContext = ctx;
        return const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Verifying with blockchain...'),
                  SizedBox(height: 8),
                  Text(
                    'This may take a few seconds',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    
    // CRITICAL: Wait for dialog to actually render before continuing
    await Future.delayed(const Duration(milliseconds: 300));
    print('📱 Dialog rendered, starting verification...');

    try {
      print('🔍 Querying blockchain_anchors...');
      // Get latest blockchain anchor
      final latestAnchorQuery = await FirebaseFirestore.instance
          .collection('blockchain_anchors')
          .orderBy('date', descending: true)
          .limit(1)
          .get();

      print('✅ Query complete, got ${latestAnchorQuery.docs.length} results');

      // Handle empty case
      if (latestAnchorQuery.docs.isEmpty) {
        print('⚠️ No results, showing snackbar');
        // Close loading dialog
        try {
          Navigator.of(dialogContext).pop();
        } catch (e) {
          // Dialog already dismissed
        }
        
        await Future.delayed(const Duration(milliseconds: 100));
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No blockchain posts yet. Daily posting runs at midnight UTC (05:30 IST).',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      print('📊 Parsing anchor data...');
      final anchorData = latestAnchorQuery.docs.first.data();
      print('📊 Anchor data: $anchorData');
      
      final blockchainMerkleRoot = anchorData['merkleRoot'] as String;
      final date = anchorData['date'] as String;
      print('📊 Got merkleRoot: ${blockchainMerkleRoot.substring(0, 20)}..., date: $date');

      // Parse date and get audit entries for that day
      print('📅 Parsing date...');
      final dateObj = DateFormat('yyyy-MM-dd').parse(date);
      final startOfDay = Timestamp.fromDate(
        DateTime(dateObj.year, dateObj.month, dateObj.day, 0, 0, 0),
      );
      final endOfDay = Timestamp.fromDate(
        DateTime(dateObj.year, dateObj.month, dateObj.day, 23, 59, 59),
      );
      print('📅 Date range: $startOfDay to $endOfDay');

      // Fetch audit entries from that date
      print('🔍 Fetching audit entries...');
      final auditEntriesQuery = await FirebaseFirestore.instance
          .collection('audit_chain')
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .where('timestamp', isLessThanOrEqualTo: endOfDay)
          .get();

      print('✅ Got ${auditEntriesQuery.docs.length} audit entries');
      final entries = auditEntriesQuery.docs
          .map((doc) => doc.data())
          .toList();

      // Recompute Merkle root from current database
      print('🧮 Computing Merkle root...');
      final recomputedMerkleRoot =
          MerkleTreeService.computeFromAuditEntries(entries);
      print('🧮 Recomputed: ${recomputedMerkleRoot.substring(0, 20)}...');

      // Compare hashes
      final isValid = recomputedMerkleRoot == blockchainMerkleRoot;
      print('✅ Comparison result: isValid = $isValid');

      // CLOSE loading dialog FIRST
      print('🚪 Closing loading dialog...');
      try {
        Navigator.of(dialogContext).pop();
        print('🚪 Loading dialog closed');
      } catch (e) {
        print('⚠️ Error closing loading: $e');
      }
      
      // Wait for it to actually close
      await Future.delayed(const Duration(milliseconds: 300));
      
      // NOW show result dialog
      print('📋 Showing result dialog...');
      
      try {
        // Use the overlay context we saved at the start - it's still valid!
        showDialog(
          context: overlayContext,
          barrierDismissible: false,
          builder: (resultContext) {
            print('📋 Result dialog builder called!');
            
            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    isValid ? Icons.check_circle : Icons.error,
                    color: isValid ? Colors.green : Colors.red,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isValid ? 'Verified ✅' : 'Tampering Detected ⚠️',
                      style: TextStyle(
                        color: isValid ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildVerificationDetail('Date', date),
                    _buildVerificationDetail(
                      'Entries Verified',
                      '${entries.length} audit logs',
                    ),
                    const Divider(height: 24),
                    const Text(
                      'Blockchain Hash:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildHashDisplay(blockchainMerkleRoot),
                    const SizedBox(height: 12),
                    const Text(
                      'Computed Hash:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildHashDisplay(recomputedMerkleRoot),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isValid
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isValid ? Colors.green : Colors.red,
                        ),
                      ),
                      child: Text(
                        isValid
                            ? '✅ Hashes match! Audit trail is authentic and has not been tampered with.'
                            : '⚠️ Hashes DO NOT match! The audit data may have been modified after blockchain posting.',
                        style: TextStyle(
                          color: isValid ? Colors.green[900] : Colors.red[900],
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(resultContext),
                  child: const Text('Close'),
                ),
                if (!isValid)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.pop(resultContext);
                      _handleTamperingDetected(context, date);
                    },
                    child: const Text('Report Issue'),
                  ),
              ],
            );
          },
        );
        print('📋 showDialog completed!');
      } catch (e) {
        print('❌ Failed to show result dialog: $e');
        // At least close the loading dialog
        try {
          Navigator.of(dialogContext).pop();
        } catch (e2) {
          // Ignore
        }
      }
    } catch (e, stackTrace) {
      print('❌ VERIFICATION ERROR: $e');
      print('Stack trace: $stackTrace');
      
      // Close loading dialog  
      try {
        Navigator.of(dialogContext).pop();
      } catch (e) {
        // Dialog already dismissed
      }

      if (context.mounted) {
        await Future.delayed(const Duration(milliseconds: 100));
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 8),
                Text('Error'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Verification failed:'),
                  const SizedBox(height: 8),
                  Text(
                    e.toString(),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    }
  }

  Widget _buildVerificationDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHashDisplay(String hash) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: hash));
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                hash,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.copy, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _handleTamperingDetected(BuildContext context, String date) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Security Alert'),
          ],
        ),
        content: Text(
          'Tampering detected in audit logs for $date.\n\n'
          'This incident should be reported to:\n'
          '• Database administrator\n'
          '• Compliance officer\n'
          '• Legal team\n\n'
          'All access to the system should be reviewed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Acknowledge'),
          ),
        ],
      ),
    );
  }
}

class _BlockchainAnchorCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;

  const _BlockchainAnchorCard({
    required this.data,
    required this.docId,
  });

  @override
  Widget build(BuildContext context) {
    final date = data['date'] as String? ?? 'Unknown';
    final merkleRoot = data['merkleRoot'] as String? ?? 'N/A';
    final txHash = data['transactionHash'] as String?;
    final entryCount = data['entryCount'] as int? ?? 0;
    final timestamp = (data['postedAt'] as Timestamp?)?.toDate();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.calendar_today,
                        size: 20,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      date,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Chip(
                  label: Text('$entryCount logs'),
                  backgroundColor: Colors.deepPurple.withOpacity(0.1),
                  labelStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Merkle root section
            const Text(
              'Merkle Root Hash:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: merkleRoot));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Hash copied to clipboard'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        merkleRoot,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.copy, size: 16, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Timestamp row
            if (timestamp != null)
              Row(
                children: [
                  const Icon(Icons.access_time, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    'Posted: ${DateFormat('MMM dd, yyyy • HH:mm').format(timestamp)} UTC',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),

            // Transaction hash and explorer button
            if (txHash != null) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.receipt_long,
                    size: 14,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Tx: ${txHash.substring(0, 10)}...${txHash.substring(txHash.length - 8)}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _openPolygonScan(txHash),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('View on PolygonScan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.pending, color: Colors.orange, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Transaction pending confirmation',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openPolygonScan(String txHash) {
    final url = 'https://amoy.polygonscan.com/tx/$txHash';
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}
