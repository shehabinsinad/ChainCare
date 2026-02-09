import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PatientProfileService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }
    return user.uid;
  }

  /// Create or update patient profile
  static Future<void> saveProfile({
    required int heightCm,
    required int weightKg,
    required String bloodGroup,
    required List<String> conditions,
    required String emergencyContact,
  }) async {
    await _db.collection('patients').doc(_uid).set({
      'heightCm': heightCm,
      'weightKg': weightKg,
      'bloodGroup': bloodGroup,
      'conditions': conditions,
      'emergencyContact': emergencyContact,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Fetch patient profile
  static Future<Map<String, dynamic>?> getProfile() async {
    final snap = await _db.collection('patients').doc(_uid).get();
    return snap.exists ? snap.data() : null;
  }
}