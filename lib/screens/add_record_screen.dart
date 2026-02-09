import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/blockchain_service.dart';
import '../services/document_upload_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/premium_button.dart';

class AddRecordScreen extends StatefulWidget {
  final String patientUid;
  const AddRecordScreen({super.key, required this.patientUid});

  @override
  State<AddRecordScreen> createState() => _AddRecordScreenState();
}

class _AddRecordScreenState extends State<AddRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  final diagnosisController = TextEditingController();
  final notesController = TextEditingController();
  PlatformFile? pickedFile;
  bool isUploading = false;

  Future<void> pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'pdf', 'png']);
    if (result != null) setState(() => pickedFile = result.files.first);
  }

  Future<void> _saveRecord() async {
    if (!_formKey.currentState!.validate() || pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill all fields & upload file', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.white)),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => isUploading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${pickedFile!.name}';
      final fileExtension = pickedFile!.extension?.toLowerCase() ?? '';
      
      String recordId;
      
      // Show processing dialog for PDFs
      if (fileExtension == 'pdf') {
        // Show loading dialog
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Expanded(child: Text('Processing PDF...\nThis may take up to 30 seconds.')),
                ],
              ),
            ),
          );
        }

        // Upload and wait for server-side processing
        recordId = await DocumentUploadService.uploadAndProcessPDF(
          userId: widget.patientUid,
          pdfFile: File(pickedFile!.path!),
          fileName: fileName,
        );

        // Close loading dialog
        if (mounted) Navigator.pop(context);
        
      } else if (fileExtension == 'jpg' || fileExtension == 'png') {
        // Process image with client-side OCR
        recordId = await DocumentUploadService.uploadAndProcessImage(
          userId: widget.patientUid,
          imageFile: File(pickedFile!.path!),
          fileName: fileName,
        );
      } else {
        throw Exception('Unsupported file type: $fileExtension');
      }

      // Update the record with doctor information and diagnosis
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.patientUid)
          .collection('records')
          .doc(recordId)
          .update({
        'doctorId': user?.uid,
        'doctorName': user?.displayName ?? 'Dr. Unknown',
        'patientId': widget.patientUid,
        'diagnosis': diagnosisController.text.trim(),
        'notes': notesController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(), // Added for UI queries
      });

      await BlockchainService.logTransaction(
        action: "ADD_MEDICAL_RECORD",
        patientId: widget.patientUid,
        doctorId: user?.uid ?? 'UNKNOWN',
        fileHash: recordId.hashCode.toString(),
        details: "Diagnosis: ${diagnosisController.text.trim()}",
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.white),
                const SizedBox(width: 12),
                Text('Record Saved & Processed', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.white)),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } on Exception catch (e) {
      // Close loading dialog if open
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().contains('timeout') 
              ? 'Processing is taking longer than expected. The record will be available soon.'
              : 'Error: $e'),
            backgroundColor: e.toString().contains('timeout') ? Colors.orange : Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if open
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: const Text("New Clinical Entry"),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.primaryGradient,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Diagnosis field with premium styling
              TextFormField(
                controller: diagnosisController,
                decoration: InputDecoration(
                  labelText: 'Diagnosis / Title',
                  labelStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.mediumGray),
                  floatingLabelStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.primary),
                  filled: true,
                  fillColor: AppColors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.softGray),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.softGray),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.error, width: 2),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.error, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ).animate().fadeIn(delay: 50.ms).slideY(begin: 0.1, end: 0),
              
              const SizedBox(height: 20),
              
              // Clinical notes field with premium styling
              TextFormField(
                controller: notesController,
                decoration: InputDecoration(
                  labelText: 'Clinical Notes',
                  labelStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.mediumGray),
                  floatingLabelStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.primary),
                  filled: true,
                  fillColor: AppColors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.softGray),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.softGray),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                maxLines: 4,
              ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),
              
              const SizedBox(height: 24),
              
              // Premium upload section
              InkWell(
                onTap: pickFile,
                child: Container(
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
                  child: Stack(
                    children: [
                      // Left gradient accent border
                      if (pickedFile != null)
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: 4,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppColors.success, AppColors.success.withOpacity(0.7)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                bottomLeft: Radius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      
                      // Content
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            // Icon with gradient background
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: pickedFile != null 
                                  ? LinearGradient(
                                      colors: [AppColors.success, AppColors.success.withOpacity(0.8)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : LinearGradient(
                                      colors: [AppColors.mediumGray.withOpacity(0.3), AppColors.mediumGray.withOpacity(0.2)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: pickedFile != null
                                  ? [
                                      BoxShadow(
                                        color: AppColors.success.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : [],
                              ),
                              child: Icon(
                                pickedFile != null ? Icons.check_circle : Icons.cloud_upload,
                                color: AppColors.white,
                                size: 28,
                              ),
                            ),
                            
                            const SizedBox(width: 16),
                            
                            // File info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pickedFile != null ? pickedFile!.name : "Upload Report (PDF/Image)",
                                    style: AppTextStyles.titleSmall.copyWith(
                                      color: pickedFile != null ? AppColors.success : AppColors.deepCharcoal,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    pickedFile != null ? 'File selected' : 'Tap to select file',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.mediumGray,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.2, end: 0),
              
              const SizedBox(height: 32),
              PremiumButton(
                text: "SECURE & SAVE",
                onPressed: isUploading ? null : _saveRecord,
                isLoading: isUploading,
                isFullWidth: true,
                icon: const Icon(Icons.shield, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}