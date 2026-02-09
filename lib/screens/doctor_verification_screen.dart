import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../app/app.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/premium_button.dart';


class DoctorVerificationScreen extends StatefulWidget {
  final Map<String, dynamic>? existingProfile;
  const DoctorVerificationScreen({super.key, this.existingProfile});

  @override
  State<DoctorVerificationScreen> createState() => _DoctorVerificationScreenState();
}

class _DoctorVerificationScreenState extends State<DoctorVerificationScreen> with AutomaticKeepAliveClientMixin {
  final _formKey = GlobalKey<FormState>();
  final nameCtrl = TextEditingController();
  final licenseCtrl = TextEditingController();
  final registrationCtrl = TextEditingController();
  final hospitalCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  
  String specialization = 'MBBS / Allopathy';
  PlatformFile? _pickedFile; 
  bool _isUploading = false;
  String? _profilePicUrl;
  
  bool _isAnalyzing = false;
  double _aiConfidence = 0.0;
  List<String> _aiFlags = [];
  bool _showAiWarning = false;
  
  // Phone OTP verification
  String _verificationId = '';
  bool _isVerifyingPhone = false;

  bool get isEditing => widget.existingProfile != null;
  final types = ['MBBS / Allopathy', 'Ayurveda', 'Homeopathy', 'Dental', 'Paramedical'];

  // ✅ Keep state alive when widget is rebuilt (e.g., after app resume)
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  void _loadInitialData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      nameCtrl.text = user.displayName!;
    }

    // Load profile picture
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data()?['profilePicUrl'] != null) {
        setState(() {
          _profilePicUrl = doc.data()!['profilePicUrl'];
        });
      }
    }

    if (widget.existingProfile != null) {
      debugPrint('📋 Loading existing profile: ${widget.existingProfile}');
      nameCtrl.text = widget.existingProfile!['name'] ?? nameCtrl.text;
      licenseCtrl.text = widget.existingProfile!['licenseNumber'] ?? '';
      registrationCtrl.text = widget.existingProfile!['registrationNumber'] ?? '';
      hospitalCtrl.text = widget.existingProfile!['hospitalAddress'] ?? widget.existingProfile!['hospitalName'] ?? '';
      phoneCtrl.text = widget.existingProfile!['phone'] ?? '';
      debugPrint('🏥 Hospital loaded: "${hospitalCtrl.text}"');
      debugPrint('📞 Phone loaded: "${phoneCtrl.text}"');
      if (types.contains(widget.existingProfile!['specialization'])) {
        specialization = widget.existingProfile!['specialization'];
      }
    }
  }

  Future<void> _pickFile() async {
    if (isEditing) return; 

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'png'], 
    );
    
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _showAiWarning = false;
        _aiFlags = [];
        _aiConfidence = 0.0;
        _pickedFile = result.files.first;
      });
      
      if (result.files.first.path != null) {
        _analyzeImage(File(result.files.first.path!));
      }
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() => _isUploading = true);
      try {
        final user = FirebaseAuth.instance.currentUser!;
        final ref = FirebaseStorage.instance.ref().child('doctor_avatars/${user.uid}.jpg');
        await ref.putFile(File(image.path));
        final url = await ref.getDownloadURL();
        
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'profilePicUrl': url,
        });

        setState(() {
          _profilePicUrl = url;
          _isUploading = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.white),
                  const SizedBox(width: 12),
                  Text('Profile Photo Updated', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.white)),
                ],
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload image: $e'), backgroundColor: AppColors.error),
          );
        }
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _analyzeImage(File imageFile) async {
    setState(() => _isAnalyzing = true);
    
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      
      String fullText = recognizedText.text.toLowerCase();
      double score = 0.0;
      List<String> flags = [];

      final inputName = nameCtrl.text.trim().toLowerCase().replaceAll("dr.", "").trim();
      final nameParts = inputName.split(' ');
      int nameMatches = 0;
      
      for (var part in nameParts) {
        if (part.length > 2 && fullText.contains(part)) {
          nameMatches++;
        }
      }

      if (nameMatches >= 1) {
        score += 0.4;
        flags.add("✅ Name found on document");
      } else {
        score = 0.0;
        flags.add("⛔ REJECTED: Name mismatch");
      }

      if (score > 0) {
        if (fullText.contains("license") || fullText.contains("registration")) {
          score += 0.3;
          flags.add("✅ License Terms Found");
        }
      }

      await textRecognizer.close();

      setState(() {
        _aiConfidence = score;
        _aiFlags = flags;
        _isAnalyzing = false;
        _showAiWarning = score < 0.3;
      });

    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _aiFlags.add("Error processing image");
        _showAiWarning = true;
      });
    }
  }

  Future<void> _verifyPhoneNumber() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload your license document first')),
      );
      return;
    }

    // ✅ Check if phone number is already in use by another account
    final phone = phoneCtrl.text.trim();
    final isDuplicate = await _isPhoneAlreadyUsed(phone);
    
    if (isDuplicate) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning, color: Colors.red, size: 24),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Phone Already Registered',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: SingleChildScrollView(
                child: Text(
              'This phone number (+91-$phone) is already associated with another doctor account.\n\n'
              'Each phone number can only be used for one account.\n\n'
              'If this is your number and you\'ve forgotten your account, please contact support.',
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return; // Stop here, don't send OTP
    }

    setState(() => _isVerifyingPhone = true);

    final phoneWithCode = '+91$phone'; // India country code

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneWithCode,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification (happens on some Android devices)
          await _onOtpVerified();
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() => _isVerifyingPhone = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Phone verification failed: ${e.message}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _isVerifyingPhone = false;
          });
          _showOtpDialog();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      setState(() => _isVerifyingPhone = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// ✅ Check if phone number is already used by another doctor account
  Future<bool> _isPhoneAlreadyUsed(String phone) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      
      // Query all users to find if this phone is already used by a doctor
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'doctor')
          .where('doctorProfile.phone', isEqualTo: phone)
          .get();
      
      if (query.docs.isEmpty) {
        return false; // ✅ Phone is available
      }
      
      // Check if it's the SAME user updating their profile
      if (isEditing && query.docs.length == 1 && query.docs.first.id == currentUserId) {
        return false; // ✅ User is updating their own profile with same phone
      }
      
      return true; // ❌ Phone is already used by someone else
    } catch (e) {
      debugPrint('Error checking phone uniqueness: $e');
      // On error, allow (fail open for better UX)
      // This prevents blocking users if Firestore is temporarily unavailable
      return false;
    }
  }

  void _showOtpDialog() {
    final otpCtrl = TextEditingController();
    bool isVerifying = false;
    bool isResending = false;
    int countdown = 60;
    Timer? countdownTimer;

    // Start countdown timer
    void startCountdown(StateSetter setDialogState) {
      countdown = 60;
      countdownTimer?.cancel();
      countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (countdown > 0) {
          if (mounted) {
            setDialogState(() => countdown--);
          }
        } else {
          timer.cancel();
        }
      });
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Start timer on first build
          if (countdownTimer == null) {
            startCountdown(setDialogState);
          }

          return AlertDialog(
            title: const Text('Enter OTP'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('OTP sent to +91${phoneCtrl.text}'),
                const SizedBox(height: 8),
                if (countdown > 0)
                  Text(
                    'Code expires in ${countdown}s',
                    style: TextStyle(
                      fontSize: 12,
                      color: countdown < 20 ? Colors.red : Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: otpCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: '6-digit OTP',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                if (countdown == 0 || isResending)
                  TextButton.icon(
                    onPressed: isResending || isVerifying
                        ? null
                        : () async {
                            setDialogState(() => isResending = true);
                            otpCtrl.clear();
                            
                            final phone = '+91${phoneCtrl.text.trim()}';
                            
                            try {
                              await FirebaseAuth.instance.verifyPhoneNumber(
                                phoneNumber: phone,
                                timeout: const Duration(seconds: 60),
                                verificationCompleted: (PhoneAuthCredential credential) async {
                                  Navigator.pop(context);
                                  await _onOtpVerified();
                                },
                                verificationFailed: (FirebaseAuthException e) {
                                  setDialogState(() => isResending = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Resend failed: ${e.message}'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                },
                                codeSent: (String verificationId, int? resendToken) {
                                  _verificationId = verificationId;
                                  setDialogState(() {
                                    isResending = false;
                                  });
                                  startCountdown(setDialogState);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('New OTP sent!'),
                                      backgroundColor: Colors.green,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                                codeAutoRetrievalTimeout: (String verificationId) {
                                  _verificationId = verificationId;
                                },
                              );
                            } catch (e) {
                              setDialogState(() => isResending = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Resend error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                    icon: isResending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 18),
                    label: Text(isResending ? 'Resending...' : 'Resend OTP'),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isVerifying || isResending
                    ? null
                    : () {
                        countdownTimer?.cancel();
                        Navigator.pop(context);
                      },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isVerifying || isResending
                    ? null
                    : () async {
                        if (otpCtrl.text.length != 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter 6-digit OTP')),
                          );
                          return;
                        }

                        setDialogState(() => isVerifying = true);

                        try {
                          final credential = PhoneAuthProvider.credential(
                            verificationId: _verificationId,
                            smsCode: otpCtrl.text.trim(),
                          );

                          // Try to link the credential to validate the OTP
                          // This validates the OTP is correct without signing out the user
                          try {
                            await FirebaseAuth.instance.currentUser?.linkWithCredential(credential);
                          } catch (linkError) {
                            // If linking fails because phone is already in use, that's fine
                            // The OTP was still validated successfully
                            if (linkError is FirebaseAuthException && 
                                linkError.code != 'invalid-verification-code' &&
                                linkError.code != 'session-expired') {
                              // Any error OTHER than invalid OTP means the OTP was valid
                              debugPrint('Link error (OTP valid): ${linkError.code}');
                            } else {
                              // Re-throw if it's an actual OTP error
                              rethrow;
                            }
                          }
                          
                          // If we reach here, OTP is valid
                          countdownTimer?.cancel();
                          Navigator.pop(context);
                          await _onOtpVerified();
                        } on FirebaseAuthException catch (e) {
                          setDialogState(() => isVerifying = false);
                          
                          String errorMessage;
                          if (e.code == 'invalid-verification-code') {
                            errorMessage = 'Invalid OTP. Please check and try again.';
                          } else if (e.code == 'session-expired') {
                            errorMessage = 'OTP expired. Please click "Resend OTP" to get a new code.';
                            setDialogState(() => countdown = 0);
                          } else {
                            errorMessage = 'Verification failed: ${e.message}';
                          }
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(errorMessage),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        } catch (e) {
                          setDialogState(() => isVerifying = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Unexpected error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                child: isVerifying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Verify'),
              ),
            ],
          );
        },
      ),
    ).then((_) {
      // Clean up timer when dialog closes
      countdownTimer?.cancel();
    });
  }


  Future<void> _onOtpVerified() async {
    // OTP verified, now proceed with document upload
    await _submitVerification();
  }

  Future<void> _submitVerification() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pickedFile == null) return; 

    setState(() => _isUploading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final path = 'doctor_ids/${user.uid}/${_pickedFile!.name}';
      final file = File(_pickedFile!.path!);
      final ref = FirebaseStorage.instance.ref().child(path);
      await ref.putFile(file);
      String downloadUrl = await ref.getDownloadURL();

      await user.updateDisplayName(nameCtrl.text.trim());

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'name': nameCtrl.text.trim(),
        'doctorProfile': {
          'name': nameCtrl.text.trim(),
          'specialization': specialization,
          'licenseNumber': licenseCtrl.text.trim(),
          'registrationNumber': registrationCtrl.text.trim(),
          'hospitalName': hospitalCtrl.text.trim(),
          'hospitalAddress': hospitalCtrl.text.trim(),
          'phone': phoneCtrl.text.trim(),
          'phoneVerified': true,
          'phoneVerifiedAt': FieldValue.serverTimestamp(),
          'idDocumentUrl': downloadUrl,
          'aiConfidenceScore': _aiConfidence,
          'aiFlags': _aiFlags,
          'aiVerifiedAt': FieldValue.serverTimestamp(),
        },
        'verificationSubmitted': true,
        'isRejected': false, // ✅ Initialize rejection flag
        'submittedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      
      // ✅ Navigate to pending screen (stay logged in)
      navigatorKey.currentState?.pushReplacementNamed('/doctor_pending');

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _updateMinorDetails() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'doctorProfile.hospitalName': hospitalCtrl.text.trim(),
      'doctorProfile.hospitalAddress': hospitalCtrl.text.trim(),
      'doctorProfile.phone': phoneCtrl.text.trim(),
    });
    
    if(mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile Updated')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // ✅ Required for AutomaticKeepAliveClientMixin
    return PopScope(
      canPop: isEditing, // ✅ Allow back button when editing existing profile
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !isEditing) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Complete verification to continue."),
              backgroundColor: Colors.orange,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.offWhite,
        appBar: AppBar(
          title: Text(
            isEditing ? 'Update Profile' : 'Professional Verification',
            style: AppTextStyles.titleMedium.copyWith(color: AppColors.white),
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          elevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
            ),
          ),
          automaticallyImplyLeading: isEditing,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Profile Picture Upload (Update Mode Only)
                if (isEditing) ...[
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.primaryGradient,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(3),
                          child: CircleAvatar(
                            radius: 55,
                            backgroundColor: AppColors.white,
                            child: CircleAvatar(
                              radius: 53,
                              backgroundColor: AppColors.primaryVeryLight,
                              backgroundImage: _profilePicUrl != null ? NetworkImage(_profilePicUrl!) : null,
                              child: _profilePicUrl == null
                                  ? Icon(
                                      Icons.person,
                                      size: 60,
                                      color: AppColors.primary.withOpacity(0.5),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: InkWell(
                            onTap: _pickImage,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.shadowMedium,
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 20,
                                color: AppColors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ).animate().scale(delay: 100.ms),
                  ),
                  const SizedBox(height: 32),
                ],
                
                TextFormField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  readOnly: isEditing,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    labelStyle: AppTextStyles.labelMedium.copyWith(color: AppColors.mediumGray),
                    floatingLabelStyle: AppTextStyles.labelMedium.copyWith(color: AppColors.primary),
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
                    filled: true,
                    fillColor: isEditing ? AppColors.softGray.withOpacity(0.3) : AppColors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ).animate().fadeIn(delay: 50.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: 20),

                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Specialization',
                    labelStyle: AppTextStyles.labelMedium.copyWith(color: AppColors.mediumGray),
                    floatingLabelStyle: AppTextStyles.labelMedium.copyWith(color: AppColors.primary),
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
                    filled: true,
                    fillColor: isEditing ? AppColors.softGray.withOpacity(0.3) : AppColors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  value: specialization,
                  items: types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: isEditing ? null : (v) {
                    if (v != null) setState(() => specialization = v);
                  },
                ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: 20),

                TextFormField(
                  controller: licenseCtrl,
                  readOnly: isEditing,
                  decoration: InputDecoration(
                    labelText: 'License Number',
                    labelStyle: AppTextStyles.labelMedium.copyWith(color: AppColors.mediumGray),
                    floatingLabelStyle: AppTextStyles.labelMedium.copyWith(color: AppColors.primary),
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
                    filled: true,
                    fillColor: isEditing ? AppColors.softGray.withOpacity(0.3) : AppColors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: 20),

                TextFormField(
                  controller: registrationCtrl,
                  readOnly: isEditing,
                  decoration: InputDecoration(
                    labelText: 'Medical Council Registration Number',
                    hintText: 'e.g., MCI/12345/2020 or state council number',
                    labelStyle: AppTextStyles.labelMedium.copyWith(color: AppColors.mediumGray),
                    floatingLabelStyle: AppTextStyles.labelMedium.copyWith(color: AppColors.primary),
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
                    filled: true,
                    fillColor: isEditing ? AppColors.softGray.withOpacity(0.3) : AppColors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (v.length < 6) return 'Must be at least 6 characters';
                    return null;
                  },
                ).animate().fadeIn(delay: 175.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: 20),

                TextFormField(
                  controller: hospitalCtrl,
                  textCapitalization: TextCapitalization.words,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Hospital / Clinic Name',
                    hintText: 'Include full address with city and pincode',
                    labelStyle: AppTextStyles.labelMedium.copyWith(color: AppColors.mediumGray),
                    floatingLabelStyle: AppTextStyles.labelMedium.copyWith(color: AppColors.primary),
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
                    filled: true,
                    fillColor: AppColors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (v.length < 20) return 'Please provide complete address';
                    return null;
                  },
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: 20),

                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 10,
                  decoration: InputDecoration(
                    labelText: 'Phone',
                    labelStyle: AppTextStyles.labelMedium.copyWith(color: AppColors.mediumGray),
                    floatingLabelStyle: AppTextStyles.labelMedium.copyWith(color: AppColors.primary),
                    counterText: "",
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
                    filled: true,
                    fillColor: AppColors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (v.length != 10) return 'Must be exactly 10 digits';
                    return null;
                  },
                ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.1, end: 0),
                
                const SizedBox(height: 24),
                
                if (!isEditing) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _showAiWarning ? AppColors.error.withOpacity(0.05) : AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _showAiWarning ? AppColors.error : (_pickedFile != null && !_isAnalyzing ? AppColors.success : AppColors.softGray),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.deepCharcoal.withOpacity(0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        if (_pickedFile != null) ...[
                          if (_isAnalyzing)
                            Column(
                              children: [
                                CircularProgressIndicator(color: AppColors.primary),
                                const SizedBox(height: 12),
                                Text('Analyzing document...', style: AppTextStyles.bodyMedium),
                              ],
                            )
                          else if (_showAiWarning)
                            Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 48),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  "Low Confidence Scan",
                                  style: AppTextStyles.titleSmall.copyWith(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Name mismatch detected.",
                                  style: AppTextStyles.bodyMedium,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                TextButton.icon(
                                  onPressed: _pickFile,
                                  icon: Icon(Icons.refresh, color: AppColors.primary),
                                  label: Text('Try Again', style: TextStyle(color: AppColors.primary)),
                                ),
                              ],
                            )
                          else
                            Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.check_circle, color: AppColors.success, size: 48),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  "Document Verified",
                                  style: AppTextStyles.titleSmall.copyWith(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "File: ${_pickedFile!.name}",
                                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.mediumGray),
                                ),
                                const SizedBox(height: 16),
                                TextButton.icon(
                                  onPressed: _pickFile,
                                  icon: Icon(Icons.edit, color: AppColors.primary),
                                  label: Text('Change File', style: TextStyle(color: AppColors.primary)),
                                ),
                              ],
                            )
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppColors.primary.withOpacity(0.1), AppColors.primary.withOpacity(0.05)],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.cloud_upload, color: AppColors.primary, size: 32),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Upload Medical License / ID Card",
                            style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          TextButton.icon(
                            onPressed: _pickFile,
                            icon: Icon(Icons.image, color: AppColors.primary, size: 18),
                            label: Text(
                              'Select Image (JPG/PNG)',
                              style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary),
                            ),
                          ),
                        ]
                      ],
                    ),
                  ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
                  const SizedBox(height: 32),
                  PremiumButton(
                    text: _isVerifyingPhone ? 'SENDING OTP...' : 'SUBMIT FOR APPROVAL',
                    onPressed: (_isUploading || _isAnalyzing || _isVerifyingPhone || (_pickedFile != null && _showAiWarning) || _pickedFile == null) 
                        ? null 
                        : _verifyPhoneNumber,
                    isLoading: _isUploading || _isVerifyingPhone,
                    isFullWidth: true,
                    icon: const Icon(Icons.shield, size: 20),
                  )
                ] else
                  PremiumButton(
                    text: 'UPDATE PROFILE',
                    onPressed: _updateMinorDetails,
                    isFullWidth: true,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}