import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String role; // 'user' or 'model'
  final String content;
  final DateTime timestamp;
  final int recordsAnalyzed; // Snapshot of how many documents were in context

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    required this.recordsAnalyzed,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'role': role,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'recordsAnalyzed': recordsAnalyzed,
    };
  }

  // Create from Firestore DocumentSnapshot
  factory ChatMessage.fromMap(String id, Map<String, dynamic> map) {
    return ChatMessage(
      id: id,
      role: map['role'] ?? 'user',
      content: map['content'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      recordsAnalyzed: map['recordsAnalyzed'] ?? 0,
    );
  }

  // Check if message is from user
  bool get isFromUser => role == 'user';
}
