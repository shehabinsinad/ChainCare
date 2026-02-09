import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/premium_card.dart';
import '../widgets/premium_button.dart';

class PatientProfileScreen extends StatefulWidget {
  final bool isSetup;
  const PatientProfileScreen({super.key, this.isSetup = false});

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final nameCtrl = TextEditingController(); // ✅ Added name field
  final phoneCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  final heightCtrl = TextEditingController();
  final weightCtrl = TextEditingController();
  final conditionsCtrl = TextEditingController();
  final allergiesCtrl = TextEditingController();
  final emergencyNameCtrl = TextEditingController();
  final emergencyPhoneCtrl = TextEditingController();

  DateTime? _dateOfBirth; // ✅ Store selected date of birth
  String gender = 'Male';
  String bloodGroup = 'O+';
  bool _isSaving = false;
  bool _noKnownAllergies = false;
  bool _noKnownConditions = false;
  String? _profilePicUrl;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (doc.exists) {
      final data = doc.data()!['profile'] as Map<String, dynamic>?;
      _profilePicUrl = doc.data()!['profilePicUrl'];
      
      // ✅ Load name from profile or root document
      final rootName = doc.data()!['name'] as String?;
      
      if (data != null) {
        setState(() {
          nameCtrl.text = data['name'] ?? rootName ?? '';
          phoneCtrl.text = data['phone'] ?? '';
          addressCtrl.text = data['address'] ?? '';
          heightCtrl.text = data['height'] ?? '';
          weightCtrl.text = data['weight'] ?? '';
          conditionsCtrl.text = data['conditions'] ?? '';
          _noKnownConditions = (data['conditions'] == 'None');
          allergiesCtrl.text = data['allergies'] ?? '';
          _noKnownAllergies = (data['allergies'] == 'None');
          emergencyNameCtrl.text = data['emergencyContactName'] ?? '';
          emergencyPhoneCtrl.text = data['emergencyContactPhone'] ?? '';
          if (data['gender'] != null) gender = data['gender'];
          if (data['bloodGroup'] != null) bloodGroup = data['bloodGroup'];
          
          // ✅ Load date of birth
          if (data['dateOfBirth'] != null) {
            try {
              _dateOfBirth = DateTime.parse(data['dateOfBirth']);
            } catch (e) {
              debugPrint('Error parsing DOB: $e');
            }
          }
        });
      }
    }
  }

  // ✅ Show calendar date picker for DOB
  Future<void> _pickDateOfBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      helpText: 'Select Date of Birth',
    );
    
    if (picked != null) {
      setState(() {
        _dateOfBirth = picked;
      });
    }
  }

  // ✅ Calculate age from date of birth
  int? _calculateAge() {
    if (_dateOfBirth == null) return null;
    final now = DateTime.now();
    int age = now.year - _dateOfBirth!.year;
    if (now.month < _dateOfBirth!.month || 
        (now.month == _dateOfBirth!.month && now.day < _dateOfBirth!.day)) {
      age--;
    }
    return age;
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() => _isSaving = true);
      try {
        final user = FirebaseAuth.instance.currentUser!;
        final ref = FirebaseStorage.instance.ref().child('avatars/${user.uid}.jpg');
        await ref.putFile(File(image.path));
        final url = await ref.getDownloadURL();
        
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'profilePicUrl': url,
        });

        setState(() {
          _profilePicUrl = url;
          _isSaving = false;
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
        _showError("Failed to upload image: $e");
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      _showError("Please fix errors.");
      return;
    }
    
    if (phoneCtrl.text.trim() == emergencyPhoneCtrl.text.trim()) {
    _showError("Patient and emergency contact phone numbers must be different");
    return;
  }
  
    if (!_noKnownConditions && conditionsCtrl.text.isEmpty) {
      _showError("Enter conditions or check 'None'");
      return;
    }
    if (!_noKnownAllergies && allergiesCtrl.text.isEmpty) {
      _showError("Enter allergies or check 'None'");
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final profileData = {
        'name': nameCtrl.text.trim(), // ✅ Save name in profile
        'phone': phoneCtrl.text.trim(),
        'address': addressCtrl.text.trim(),
        'gender': gender,
        'dateOfBirth': _dateOfBirth?.toIso8601String(), // ✅ Save DOB as ISO string
        'height': heightCtrl.text.trim(),
        'weight': weightCtrl.text.trim(),
        'bloodGroup': bloodGroup,
        'conditions': _noKnownConditions ? "None" : conditionsCtrl.text.trim(),
        'allergies': _noKnownAllergies ? "None" : allergiesCtrl.text.trim(),
        'emergencyContactName': emergencyNameCtrl.text.trim(),
        'emergencyContactPhone': emergencyPhoneCtrl.text.trim(),
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'name': nameCtrl.text.trim(), // ✅ Update root name field too
        'profile': profileData,
        'profileCompleted': true,
      });

      await FirebaseFirestore.instance.collection('users').doc(user.uid)
          .collection('emergency').doc('data').set({
            'name': user.displayName ?? 'Unknown',
            'bloodGroup': bloodGroup,
            'allergies': profileData['allergies'],
            'conditions': profileData['conditions'],
            'emergencyContactName': emergencyNameCtrl.text.trim(),
            'emergencyContactPhone': emergencyPhoneCtrl.text.trim(),
          });

      if (mounted) {
        if (widget.isSetup) {
          Navigator.pushReplacementNamed(context, '/');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.white),
                  const SizedBox(width: 12),
                  Text('Profile Updated', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.white)),
                ],
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      _showError("Error: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.white)),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.isSetup,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _showError("Complete setup to continue.");
      },
      child: Scaffold(
        backgroundColor: AppColors.offWhite,
        appBar: AppBar(
          title: Text(
            widget.isSetup ? "Setup Profile" : "Edit Profile",
            style: AppTextStyles.titleMedium.copyWith(color: AppColors.white),
          ),
          automaticallyImplyLeading: !widget.isSetup,
          centerTitle: true,
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          elevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
            ),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.shadowMedium,
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 55,
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
                    )
                  ],
                ).animate().scale(delay: 100.ms),
              ),
              const SizedBox(height: 32),

              _sectionHeader("Personal Details"),
              _buildTextField("Full Name", nameCtrl, isCap: true), // ✅ Name as FIRST field
              const SizedBox(height: 16),
              _buildPhoneField("Phone Number", phoneCtrl), 
              const SizedBox(height: 16),
              _buildTextField("Home Address", addressCtrl, maxLines: 2, isCap: true),
              const SizedBox(height: 16),
              _buildDropdown("Gender", gender, ['Male', 'Female', 'Other'], (v) => setState(() => gender = v!)),
              const SizedBox(height: 16),
              
              // ✅ Date of Birth field with calendar picker
              InkWell(
                onTap: _pickDateOfBirth,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Date of Birth',
                    labelStyle: AppTextStyles.labelMedium.copyWith(color: AppColors.mediumGray),
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
                    suffixIcon: Icon(Icons.calendar_today, color: AppColors.primary),
                  ),
                  child: Text(
                    _dateOfBirth != null
                        ? '${_dateOfBirth!.day.toString().padLeft(2, '0')}-${_dateOfBirth!.month.toString().padLeft(2, '0')}-${_dateOfBirth!.year}'
                        : 'Select date of birth',
                    style: TextStyle(
                      color: _dateOfBirth != null ? AppColors.deepCharcoal : AppColors.mediumGray,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              
              // ✅ Display calculated age
              if (_dateOfBirth != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    'Age: ${_calculateAge()} years',
                    style: TextStyle(
                      color: Colors.teal.shade700,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 32),
              _sectionHeader("Vitals & History"),
              Row(
                children: [
                  Expanded(child: _buildTextField("Height (cm)", heightCtrl, isNumber: true)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField("Weight (kg)", weightCtrl, isNumber: true)),
                ],
              ),
              const SizedBox(height: 16),
              _buildDropdown("Blood Group", bloodGroup, ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'], (v) => setState(() => bloodGroup = v!)),
              const SizedBox(height: 16),
              _buildSmartField("Medical Conditions", conditionsCtrl, _noKnownConditions, (v) => setState(() => _noKnownConditions = v!)),
              const SizedBox(height: 16),
              _buildSmartField("Allergies", allergiesCtrl, _noKnownAllergies, (v) => setState(() => _noKnownAllergies = v!)),

              const SizedBox(height: 32),
              _sectionHeader("Emergency Contact"),
              _buildTextField("Contact Name", emergencyNameCtrl, isCap: true),
              const SizedBox(height: 16),
              _buildPhoneField("Contact Phone", emergencyPhoneCtrl),

              const SizedBox(height: 40),
              PremiumButton(
                text: "SAVE PROFILE",
                onPressed: _isSaving ? null : _saveProfile,
                isLoading: _isSaving,
                isFullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneField(String label, TextEditingController ctrl) {
    return TextFormField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      maxLength: 10,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTextStyles.labelMedium.copyWith(color: AppColors.mediumGray),
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
        filled: true,
        fillColor: AppColors.white,
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return "Required";
        if (v.length != 10) return "Must be exactly 10 digits";
        return null;
      },
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, {bool isNumber = false, int maxLines = 1, bool isCap = false}) {
    return TextFormField(
      controller: ctrl,
      textCapitalization: isCap ? TextCapitalization.words : TextCapitalization.none,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      maxLength: isNumber ? 3 : null,
      inputFormatters: isNumber ? [FilteringTextInputFormatter.digitsOnly] : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTextStyles.labelMedium.copyWith(color: AppColors.mediumGray),
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
        filled: true,
        fillColor: AppColors.white,
      ),
      validator: (v) => (v == null || v.isEmpty) ? "Required" : null,
    );
  }

  Widget _buildSmartField(String label, TextEditingController ctrl, bool isNone, ValueChanged<bool?> onNone) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTextStyles.labelLarge.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.deepCharcoal,
              ),
            ),
            Transform.scale(
              scale: 0.9,
              child: FilterChip(
                label: const Text("None"),
                selected: isNone,
                onSelected: (val) {
                  onNone(val);
                  if (val) ctrl.clear();
                },
                selectedColor: AppColors.primaryVeryLight,
                checkmarkColor: AppColors.primary,
              ),
            ),
          ],
        ),
        if (!isNone)
          TextFormField(
            controller: ctrl,
            decoration: InputDecoration(
              hintText: "Enter details...",
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
            ),
            validator: (v) => (!_noKnownConditions && v!.isEmpty) ? "Required" : null,
          ),
      ],
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTextStyles.labelMedium.copyWith(color: AppColors.mediumGray),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}