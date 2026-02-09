import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/emergency_model.dart';

class EmergencyService {
  static Future<EmergencyModel?> fetchEmergencyData(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('emergency')
        .doc('data')
        .get();

    if (!doc.exists) return null;

    return EmergencyModel.fromMap(doc.data()!);
  }
}