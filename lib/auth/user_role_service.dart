import 'package:cloud_firestore/cloud_firestore.dart';

class UserRoleService {
  static Future<String?> getUserRole(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    return doc.data()?['role'];
  }
}