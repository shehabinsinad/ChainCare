import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuditBlock {
  final int index;
  final DateTime timestamp;
  final String action;
  final String details;
  final String previousHash;
  final String hash;

  AuditBlock({
    required this.index,
    required this.timestamp,
    required this.action,
    required this.details,
    required this.previousHash,
    required this.hash,
  });

  // SHA-256 Hashing Logic
  static String calculateHash(int index, String prevHash, DateTime time, String action, String details) {
    final input = '$index$prevHash${time.toIso8601String()}$action$details';
    return sha256.convert(utf8.encode(input)).toString();
  }

  Map<String, dynamic> toMap() {
    return {
      'index': index,
      'timestamp': Timestamp.fromDate(timestamp),
      'action': action,
      'details': details,
      'previousHash': previousHash,
      'hash': hash,
    };
  }
}