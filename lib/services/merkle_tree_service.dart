import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Service for computing Merkle tree root hashes
/// Used to aggregate multiple audit log hashes into a single root hash
class MerkleTreeService {
  /// Compute Merkle root from a list of hashes
  /// 
  /// Algorithm:
  /// 1. Start with leaf hashes (bottom level)
  /// 2. Pair adjacent hashes and hash them together
  /// 3. If odd number, duplicate last hash
  /// 4. Repeat until single root hash remains
  /// 
  /// Example:
  /// Leaves: [A, B, C, D]
  /// Level 1: [hash(A+B), hash(C+D)]
  /// Level 2: [hash(hash(A+B)+hash(C+D))] ← Root
  static String computeMerkleRoot(List<String> hashes) {
    if (hashes.isEmpty) return _hash('EMPTY_BLOCK');
    if (hashes.length == 1) return hashes[0];

    List<String> currentLevel = List.from(hashes);

    // Build tree bottom-up until we have a single root
    while (currentLevel.length > 1) {
      List<String> nextLevel = [];
      
      for (int i = 0; i < currentLevel.length; i += 2) {
        if (i + 1 < currentLevel.length) {
          // We have a pair - hash them together
          String combinedHash = _hash(currentLevel[i] + currentLevel[i + 1]);
          nextLevel.add(combinedHash);
        } else {
          // Odd number of hashes - duplicate the last one
          String combinedHash = _hash(currentLevel[i] + currentLevel[i]);
          nextLevel.add(combinedHash);
        }
      }
      
      currentLevel = nextLevel;
    }

    return currentLevel[0]; // The root hash
  }

  /// SHA-256 hash helper function
  static String _hash(String input) {
    var bytes = utf8.encode(input);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Compute Merkle root directly from Firestore audit entry documents
  /// 
  /// This is a convenience method that extracts hashes from audit entries
  /// and computes the Merkle root in one step
  static String computeFromAuditEntries(List<Map<String, dynamic>> entries) {
    if (entries.isEmpty) return _hash('NO_ENTRIES_FOR_DAY');

    // Sort by index to ensure consistent ordering
    // This is CRITICAL - same data must always produce same root
    entries.sort((a, b) {
      final indexA = a['index'] as int? ?? 0;
      final indexB = b['index'] as int? ?? 0;
      return indexA.compareTo(indexB);
    });

    // Extract the hash field from each entry
    List<String> hashes = entries
        .map((entry) => entry['hash'] as String? ?? '')
        .where((hash) => hash.isNotEmpty)
        .toList();

    if (hashes.isEmpty) return _hash('NO_VALID_HASHES');

    return computeMerkleRoot(hashes);
  }

  /// Verify that a given hash matches the Merkle root of entries
  /// Returns true if data is authentic, false if tampered
  static bool verifyMerkleRoot(
    String expectedRoot,
    List<Map<String, dynamic>> entries,
  ) {
    final computedRoot = computeFromAuditEntries(entries);
    return computedRoot == expectedRoot;
  }
}
