import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class DocumentProcessorService {
  static final TextRecognizer _textRecognizer = TextRecognizer();

  /// Extract text from PDF file at given URL
  /// 
  /// Note: PDF text extraction requires additional dependencies.
  /// For now, returns a placeholder message.
  /// For production, consider using packages like:
  /// - syncfusion_flutter_pdf (requires license)
  /// - pdf_render + OCR on rendered images
  static Future<String> extractTextFromPDF(String fileUrl) async {
    try {
      // For now, return placeholder
      // In production, you could:
      // 1. Use syncfusion_flutter_pdf if you have a license
      // 2. Use pdf_render to convert PDF to images, then OCR those images
      // 3. Use server-side PDF processing
      return '[PDF document attached - text extraction requires additional setup]';
    } catch (e) {
      return '[PDF processing failed]';
    }
  }

  /// Extract text from image file at given URL using OCR
  /// 
  /// Downloads image and uses Google ML Kit for text recognition
  /// Returns extracted text with confidence check
  static Future<String> extractTextFromImage(String fileUrl) async {
    try {
      // Download image
      final response = await http.get(Uri.parse(fileUrl)).timeout(
        const Duration(seconds: 30),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to download image');
      }

      final bytes = response.bodyBytes;
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(bytes);

      try {
        // Perform OCR
        final inputImage = InputImage.fromFile(tempFile);
        final recognizedText = await _textRecognizer.processImage(inputImage);
        
        await tempFile.delete(); // Clean up temp file

        if (recognizedText.text.isEmpty) {
          return '[No text detected in image]';
        }

        // Check confidence (if available in blocks)
        double totalConfidence = 0;
        int blockCount = 0;
        for (var block in recognizedText.blocks) {
          // Note: ML Kit doesn't provide confidence scores in current version,
          // so we just extract all text
          blockCount++;
        }

        return recognizedText.text.trim();
      } catch (e) {
        await tempFile.delete(); // Clean up on error
        throw Exception('OCR processing failed: $e');
      }
    } catch (e) {
      throw Exception('Image download or OCR failed: $e');
    }
  }

  /// Create indexed medical summary from list of patient records
  /// 
  /// Processes all documents and creates a structured summary with dates
  /// Format: "Doc 1 (Date: YYYY-MM-DD, Type: X): [content]"
  static Future<String> createMedicalSummary(List<DocumentSnapshot> records) async {
    if (records.isEmpty) {
      return 'No medical records available.';
    }

    final List<String> summaries = [];
    int docIndex = 1;

    for (var record in records) {
      final data = record.data() as Map<String, dynamic>?;
      if (data == null) continue;

      final date = (data['timestamp'] as Timestamp?)?.toDate();
      final dateStr = date != null 
          ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
          : 'Unknown Date';
      
      final diagnosis = data['diagnosis'] ?? 'Clinical Note';
      final doctorName = data['doctorName'] ?? 'Unknown Doctor';
      final prescriptions = data['prescriptions'] ?? '';
      final notes = data['notes'] ?? '';
      final fileUrl = data['fileUrl'] as String?;
      final fileType = data['fileType'] as String?;

      // Build content string
      String content = 'Diagnosis: $diagnosis by Dr. $doctorName. ';
      if (prescriptions.isNotEmpty) {
        content += 'Prescriptions: $prescriptions. ';
      }
      if (notes.isNotEmpty) {
        content += 'Notes: $notes. ';
      }

      // Try to extract text from attached file if available
      if (fileUrl != null && fileUrl.isNotEmpty) {
        String extractedText = '';
        
        if (fileType == 'pdf') {
          extractedText = await extractTextFromPDF(fileUrl);
          if (extractedText.isEmpty) {
            content += '[PDF document attached - text extraction failed, may be scanned image]. ';
          } else {
            // Limit extracted text to avoid token overflow (first 500 chars per doc)
            final truncated = extractedText.length > 500 
                ? '${extractedText.substring(0, 500)}...' 
                : extractedText;
            content += 'Document content: $truncated ';
          }
        } else if (fileType == 'image' || fileType == 'jpg' || fileType == 'png') {
          try {
            extractedText = await extractTextFromImage(fileUrl);
            // Limit extracted text
            final truncated = extractedText.length > 500 
                ? '${extractedText.substring(0, 500)}...' 
                : extractedText;
            content += 'Image text (OCR): $truncated ';
          } catch (e) {
            content += '[Image attached - OCR failed]. ';
          }
        }
      }

      summaries.add('Doc $docIndex (Date: $dateStr, Type: $diagnosis): $content');
      docIndex++;
    }

    return summaries.join('\n\n');
  }

  /// Dispose text recognizer when no longer needed
  static void dispose() {
    _textRecognizer.close();
  }
}
