import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Service for uploading and processing medical documents
/// 
/// - PDFs: Uploaded to Storage, processed server-side via Cloud Functions
/// - Images: Processed client-side using ML Kit OCR
class DocumentUploadService {
  /// Upload PDF and wait for server-side processing
  /// 
  /// Returns the Firestore record ID once processing completes
  /// Throws exception on timeout or processing failure
  static Future<String> uploadAndProcessPDF({
    required String userId,
    required File pdfFile,
    required String fileName,
  }) async {
    try {
      // 1. Upload to Storage at special path that triggers Cloud Function
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('patients/$userId/documents/$fileName');
      
      final uploadTask = await storageRef.putFile(pdfFile);
      print('✅ PDF uploaded: ${uploadTask.ref.fullPath}');

      // 2. Wait for Cloud Function to process (poll Firestore)
      return await _waitForProcessing(userId, fileName);
      
    } catch (e) {
      print('❌ Error uploading PDF: $e');
      rethrow;
    }
  }

  /// Poll Firestore for processing completion
  /// 
  /// Checks every 1 second for up to 30 seconds
  /// Returns record ID on success, throws on failure/timeout
  static Future<String> _waitForProcessing(String userId, String fileName) async {
    const maxAttempts = 30;
    const delayDuration = Duration(seconds: 1);
    
    for (int i = 0; i < maxAttempts; i++) {
      await Future.delayed(delayDuration);
      
      // Check if record with this fileName exists and is processed
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('records')
          .where('fileName', isEqualTo: fileName)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final status = doc.data()['processingStatus'];
        
        if (status == 'completed') {
          print('✅ PDF processing completed');
          return doc.id; // Return record ID
        } else if (status == 'failed') {
          throw Exception('PDF processing failed: ${doc.data()['errorMessage']}');
        }
      }
    }
    
    throw Exception('PDF processing timeout - check back later');
  }

  /// Upload image and process using client-side ML Kit OCR
  /// 
  /// Returns the Firestore record ID immediately after processing
  static Future<String> uploadAndProcessImage({
    required String userId,
    required File imageFile,
    required String fileName,
  }) async {
    try {
      // 1. Extract text using ML Kit OCR
      final extractedText = await _extractTextWithMLKit(imageFile);
      
      // 2. Upload image to Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('patients/$userId/documents/$fileName');
      
      await storageRef.putFile(imageFile);
      final fileUrl = await storageRef.getDownloadURL();
      
      // 3. Create Firestore record with extracted text
      final recordRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('records')
          .doc();
      
      await recordRef.set({
        'fileName': fileName,
        'fileUrl': fileUrl,
        'fileType': 'image',
        'extractedText': extractedText,
        'processingStatus': 'completed',
        'uploadedAt': FieldValue.serverTimestamp(),
        'processedAt': FieldValue.serverTimestamp(),
      });
      
      print('✅ Image processed and saved: ${recordRef.id}');
      return recordRef.id;
      
    } catch (e) {
      print('❌ Error processing image: $e');
      rethrow;
    }
  }
  
  /// Extract text from image using Google ML Kit OCR
  /// 
  /// Reuses the same OCR logic from doctor verification screen
  static Future<String> _extractTextWithMLKit(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final recognizedText = await textRecognizer.processImage(inputImage);
      
      // Clean up
      await textRecognizer.close();
      
      if (recognizedText.text.isEmpty) {
        return '[No text detected in image]';
      }
      
      return recognizedText.text.trim();
      
    } catch (e) {
      print('❌ ML Kit OCR failed: $e');
      return '[OCR processing failed]';
    }
  }
}
