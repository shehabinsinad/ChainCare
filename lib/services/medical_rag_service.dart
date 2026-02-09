import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'document_processor_service.dart';


class MedicalRAGService {
  // Cache for processed medical summaries
  static final Map<String, _CachedSummary> _cache = {};
  static const Duration _cacheTTL = Duration(minutes: 10);

  /// Fetch and index all patient records
  /// 
  /// [patientId] - Patient's user ID
  /// [isDoctor] - If true, creates clinical summary; if false, patient-friendly summary
  /// 
  /// Returns formatted summary of all medical records
  static Future<String> fetchAndIndexPatientRecords(
    String patientId, {
    bool isDoctor = false,
  }) async {
    try {
      // Fetch all records from Firestore (limit to prevent overload)
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(patientId)
          .collection('records')
          .orderBy('timestamp', descending: true)
          .limit(50) // Prevent loading too many documents
          .get();

      if (snapshot.docs.isEmpty) {
        return 'No medical records found.';
      }

      // Check cache
      final cacheKey = '${patientId}_${isDoctor ? 'doctor' : 'patient'}';
      final cached = _cache[cacheKey];
      final now = DateTime.now();

      if (cached != null &&
          now.difference(cached.cachedAt) < _cacheTTL &&
          cached.recordCount == snapshot.docs.length) {
        return cached.summary;
      }

      // Generate new summary
      String summary;
      if (isDoctor) {
        summary = await _createClinicalSummary(snapshot.docs);
      } else {
        summary = await _createPatientFriendlySummary(snapshot.docs);
      }

      // Compress if needed (rough estimate: 4 chars = 1 token)
      final maxTokens = isDoctor ? 25000 : 30000;
      summary = _compressToTokenLimit(summary, maxTokens);

      // Cache the result
      _cache[cacheKey] = _CachedSummary(
        summary: summary,
        cachedAt: now,
        recordCount: snapshot.docs.length,
      );

      return summary;
    } catch (e) {
      return 'Error loading medical records: $e';
    }
  }

  /// Create patient-friendly summary
  static Future<String> _createPatientFriendlySummary(
    List<DocumentSnapshot> records,
  ) async {
    final buffer = StringBuffer();
    buffer.writeln('=== YOUR MEDICAL RECORDS ===\n');

    for (var record in records) {
      final data = record.data() as Map<String, dynamic>?;
      if (data == null) continue;

      final date = (data['timestamp'] as Timestamp?)?.toDate();
      final dateStr = date != null
          ? DateFormat('MMM dd, yyyy').format(date)
          : 'Unknown Date';

      final diagnosis = data['diagnosis'] ?? 'Medical Record';
      final doctorName = data['doctorName'] ?? 'Unknown Doctor';
      final notes = data['notes'] ?? '';
      final extractedText = data['extractedText'] ?? '';

      buffer.writeln('📄 Document from $dateStr');
      buffer.writeln('   Type: $diagnosis');
      buffer.writeln('   Doctor: Dr. $doctorName');
      
      if (notes.isNotEmpty) {
        buffer.writeln('   Notes: $notes');
      }
      
      if (extractedText.isNotEmpty && !extractedText.startsWith('[')) {
        // Include actual document content (first 500 chars for patient view)
        // ✅ FIXED: Safe substring with length check to prevent RangeError
        final maxLength = 500;
        final preview = extractedText.length > maxLength 
            ? '${extractedText.substring(0, maxLength)}...' 
            : extractedText;
        buffer.writeln('   Content: $preview');
      }
      
      buffer.writeln(); // Empty line between records
    }

    return buffer.toString();
  }

  /// Create clinical summary for doctors (categorized by type)
  static Future<String> _createClinicalSummary(
    List<DocumentSnapshot> records,
  ) async {
    final medications = <String>[];
    final labResults = <String>[];
    final diagnoses = <String>[];
    final vitals = <String>[];
    final procedures = <String>[];
    final other = <String>[];

    for (var record in records) {
      final data = record.data() as Map<String, dynamic>?;
      if (data == null) continue;

      final date = (data['timestamp'] as Timestamp?)?.toDate();
      final dateStr = date != null
          ? DateFormat('MMM dd, yyyy').format(date)
          : 'Unknown';

      final diagnosis = data['diagnosis'] ?? 'Unknown';
      final doctorName = data['doctorName'] ?? 'Unknown';
      final prescriptions = data['prescriptions'] ?? '';
      final notes = data['notes'] ?? '';
      final extractedText = data['extractedText'] ?? ''; // Read server-processed text

      // Build content string
      String content = notes.isNotEmpty ? notes : '';
      if (extractedText.isNotEmpty && !extractedText.startsWith('[')) {
        // ✅ FIXED: Safe substring with length check to prevent RangeError
        final maxLength = 300;
        final preview = extractedText.length > maxLength 
            ? '${extractedText.substring(0, maxLength)}...'
            : extractedText;
        // Add extracted PDF/image text if available (skip error messages like "[PDF processing failed]")
        content += content.isNotEmpty ? ' | Document: $preview' : 'Document: $preview';
      }

      // Categorize based on type/content
      final diagnosisLower = diagnosis.toLowerCase();

      if (diagnosisLower.contains('prescription') ||
          diagnosisLower.contains('medication') ||
          prescriptions.isNotEmpty) {
        medications.add('[$dateStr] $diagnosis - $prescriptions ${content.isNotEmpty ? "($content)" : ""} (Dr. $doctorName)');
      } else if (diagnosisLower.contains('lab') ||
          diagnosisLower.contains('test') ||
          diagnosisLower.contains('blood')) {
        labResults.add('[$dateStr] $diagnosis - ${content.isNotEmpty ? content : "No details"} (Dr. $doctorName)');
      } else if (diagnosisLower.contains('vital') ||
          diagnosisLower.contains('bp') ||
          diagnosisLower.contains('blood pressure')) {
        vitals.add('[$dateStr] $diagnosis - ${content.isNotEmpty ? content : "No details"}');
      } else if (diagnosisLower.contains('procedure') ||
          diagnosisLower.contains('surgery') ||
          diagnosisLower.contains('operation')) {
        procedures.add('[$dateStr] $diagnosis - ${content.isNotEmpty ? content : "No details"} (Dr. $doctorName)');
      } else if (diagnosisLower != 'clinical note' && diagnosisLower != 'unknown') {
        diagnoses.add('[$dateStr] $diagnosis - ${content.isNotEmpty ? content : "No details"} (Dr. $doctorName)');
      } else {
        other.add('[$dateStr] $diagnosis - ${content.isNotEmpty ? content : "No details"} (Dr. $doctorName)');
      }
    }

    // Build categorized summary
    final buffer = StringBuffer();

    buffer.writeln('=== CLINICAL SUMMARY ===\n');

    if (medications.isNotEmpty) {
      buffer.writeln('MEDICATIONS:');
      for (var med in medications) {
        buffer.writeln('  • $med');
      }
      buffer.writeln();
    }

    if (labResults.isNotEmpty) {
      buffer.writeln('LAB RESULTS:');
      for (var lab in labResults) {
        buffer.writeln('  • $lab');
      }
      buffer.writeln();
    }

    if (diagnoses.isNotEmpty) {
      buffer.writeln('DIAGNOSES:');
      for (var dx in diagnoses) {
        buffer.writeln('  • $dx');
      }
      buffer.writeln();
    }

    if (vitals.isNotEmpty) {
      buffer.writeln('VITAL SIGNS:');
      for (var vital in vitals) {
        buffer.writeln('  • $vital');
      }
      buffer.writeln();
    }

    if (procedures.isNotEmpty) {
      buffer.writeln('PROCEDURES:');
      for (var proc in procedures) {
        buffer.writeln('  • $proc');
      }
      buffer.writeln();
    }

    if (other.isNotEmpty) {
      buffer.writeln('OTHER CLINICAL NOTES:');
      for (var note in other) {
        buffer.writeln('  • $note');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Compress text to fit within token limit
  /// 
  /// Rough estimate: 4 characters ≈ 1 token
  static String _compressToTokenLimit(String text, int maxTokens) {
    final maxChars = maxTokens * 4;
    if (text.length <= maxChars) {
      return text;
    }

    // Truncate and add notice
    final truncated = text.substring(0, maxChars - 200);
    return '$truncated\n\n[Note: Summary truncated due to length. Showing most recent records.]';
  }

  /// Clear cache (useful for testing or manual refresh)
  static void clearCache() {
    _cache.clear();
  }
}

/// Internal class for caching summaries
class _CachedSummary {
  final String summary;
  final DateTime cachedAt;
  final int recordCount;

  _CachedSummary({
    required this.summary,
    required this.cachedAt,
    required this.recordCount,
  });
}
