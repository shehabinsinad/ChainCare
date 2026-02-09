import 'package:web3dart/web3dart.dart' as web3;
import 'package:http/http.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Service for interacting with Polygon blockchain
/// Handles posting daily audit hashes and retrieving blockchain data
class BlockchainService {
  // Polygon Amoy Testnet Configuration
  static const String rpcUrl = 'https://rpc-amoy.polygon.technology';
  static const int chainId = 80002; // Amoy testnet chain ID
  
  // Contract details (update after deployment)
  static const String contractAddress = '0x56bBF330d155B30aAeb904B93D21EeBCb1f96aB6'; // TODO: Replace with deployed address
  
  // Wallet private key (TESTNET ONLY - for mainnet use secure storage)
  static const String privateKey = 'a98c930c5b9df1be4c7b187459dd7365cc47af04c12fa3b136325e82dc8bdae4'; // TODO: Replace with your key
  
  static web3.Web3Client? _client;
  static web3.DeployedContract? _contract;
  static web3.EthPrivateKey? _credentials;

  /// Initialize Web3 client and load contract
  static Future<void> initialize() async {
    if (_client != null) return; // Already initialized

    try {
      // Create HTTP client for RPC calls
      _client = web3.Web3Client(rpcUrl, Client());

      // Load contract ABI from assets
      final abiString = await rootBundle.loadString('assets/contracts/ChainCareAudit.json');
      final abiJson = json.decode(abiString);

      // Create contract instance
      _contract = web3.DeployedContract(
        web3.ContractAbi.fromJson(json.encode(abiJson), 'ChainCareAudit'),
        web3.EthereumAddress.fromHex(contractAddress),
      );

      // Create wallet credentials
      _credentials = web3.EthPrivateKey.fromHex(privateKey);

      print('✅ Blockchain service initialized');
      print('📍 Contract: $contractAddress');
      print('🔗 Network: Polygon Amoy (Chain ID: $chainId)');
    } catch (e) {
      print('❌ Failed to initialize blockchain service: $e');
      rethrow;
    }
  }

  /// Post daily Merkle root hash to blockchain
  /// 
  /// Parameters:
  /// - date: Date string in YYYY-MM-DD format
  /// - merkleRoot: 64-character hex hash (SHA-256)
  /// - entryCount: Number of audit entries included in hash
  /// 
  /// Returns: Transaction hash (can be viewed on PolygonScan)
  static Future<String> postDailyHash({
    required String date,
    required String merkleRoot,
    required int entryCount,
  }) async {
    if (_client == null || _contract == null) {
      await initialize();
    }

    try {
      print('📤 Posting to blockchain...');
      print('   Date: $date');
      print('   Merkle Root: $merkleRoot');
      print('   Entry Count: $entryCount');

      // Get the storeAuditHash function from contract
      final function = _contract!.function('storeAuditHash');

      // Create transaction
      final transaction = web3.Transaction.callContract(
        contract: _contract!,
        function: function,
        parameters: [
          date,
          merkleRoot,
          BigInt.from(entryCount),
        ],
      );

      // Send transaction to blockchain
      final txHash = await _client!.sendTransaction(
        _credentials!,
        transaction,
        chainId: chainId,
      );

      print('✅ Transaction sent: $txHash');
      print('🔍 View on explorer: ${getExplorerUrl(txHash)}');

      return txHash;
    } catch (e) {
      print('❌ Blockchain posting failed: $e');
      rethrow;
    }
  }

  /// Get audit entry from blockchain by index
  /// 
  /// Returns map with: date, merkleRoot, entryCount, timestamp
  static Future<Map<String, dynamic>> getAuditFromBlockchain(int index) async {
    if (_client == null || _contract == null) {
      await initialize();
    }

    try {
      final function = _contract!.function('getAudit');

      final result = await _client!.call(
        contract: _contract!,
        function: function,
        params: [BigInt.from(index)],
      );

      return {
        'date': result[0] as String,
        'merkleRoot': result[1] as String,
        'entryCount': (result[2] as BigInt).toInt(),
        'blockTimestamp': (result[3] as BigInt).toInt(),
      };
    } catch (e) {
      print('❌ Failed to get audit from blockchain: $e');
      rethrow;
    }
  }

  /// Get total number of audit entries stored on blockchain
  static Future<int> getAuditCount() async {
    if (_client == null || _contract == null) {
      await initialize();
    }

    try {
      final function = _contract!.function('getAuditCount');

      final result = await _client!.call(
        contract: _contract!,
        function: function,
        params: [],
      );

      return (result[0] as BigInt).toInt();
    } catch (e) {
      print('❌ Failed to get audit count: $e');
      return 0;
    }
  }

  /// Get the latest audit entry from blockchain
  static Future<Map<String, dynamic>?> getLatestAudit() async {
    final count = await getAuditCount();
    if (count == 0) return null;
    return getAuditFromBlockchain(count - 1);
  }

  /// Build PolygonScan Amoy explorer URL for a transaction
  static String getExplorerUrl(String txHash) {
    return 'https://amoy.polygonscan.com/tx/$txHash';
  }

  /// Build PolygonScan Amoy explorer URL for the contract
  static String getContractExplorerUrl() {
    return 'https://amoy.polygonscan.com/address/$contractAddress';
  }

  // ═══════════════════════════════════════════════════════════
  // BACKWARD COMPATIBILITY - Audit Chain Creation
  // ═══════════════════════════════════════════════════════════
  
  /// Legacy method for creating audit entries in Firestore
  /// This maintains backward compatibility with existing code
  static Future<void> logTransaction({
    required String action,
    required String details,
    String? patientId,
    String? doctorId,
    String? reason,
    String? fileHash,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;
      
      // Get the last block to continue the chain
      final lastBlockQuery = await firestore
          .collection('audit_chain')
          .orderBy('index', descending: true)
          .limit(1)
          .get();

      int newIndex = 0;
      String previousHash = '0'; // Genesis block

      if (lastBlockQuery.docs.isNotEmpty) {
        final lastBlock = lastBlockQuery.docs.first.data();
        newIndex = (lastBlock['index'] as int) + 1;
        previousHash = lastBlock['hash'] as String;
      }

      // Format detailed information for display
      final detailsBuffer = StringBuffer();
      
      if (patientId != null && patientId.isNotEmpty) {
        detailsBuffer.writeln('PID:$patientId');
      }
      if (doctorId != null && doctorId.isNotEmpty) {
        detailsBuffer.writeln('DID:$doctorId');
      }
      if (reason != null && reason.isNotEmpty) {
        detailsBuffer.writeln('REASON:$reason');
      }
      if (fileHash != null && fileHash.isNotEmpty) {
        detailsBuffer.writeln('HASH:$fileHash');
      }
      
      // Add the main details
      detailsBuffer.write(details);
      
      final formattedDetails = detailsBuffer.toString();

      // Create new audit entry
      final timestamp = DateTime.now();
      final newHash = _calculateHash(
        index: newIndex,
        previousHash: previousHash,
        timestamp: timestamp,
        action: action,
        details: formattedDetails,
      );

      // Store in Firestore
    await firestore.collection('audit_chain').add({
      'index': newIndex,
      'timestamp': Timestamp.fromDate(timestamp),
      'action': action,
      'details': formattedDetails,
      'previousHash': previousHash,
      'hash': newHash,
      // ✅ FIX: Add top-level fields for queries (patient transparency logs)
      'patientId': patientId,
      'doctorId': doctorId,
      'reason': reason,
    });

      print('✅ Audit entry created: $action (Block #$newIndex)');
    } catch (e) {
      print('❌ Failed to create audit entry: $e');
      rethrow;
    }
  }

  /// Calculate SHA-256 hash for audit entry
  static String _calculateHash({
    required int index,
    required String previousHash,
    required DateTime timestamp,
    required String action,
    required String details,
  }) {
    final input = '$index$previousHash${timestamp.toIso8601String()}$action$details';
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Dispose of resources
  static Future<void> dispose() async {
    await _client?.dispose();
    _client = null;
    _contract = null;
    _credentials = null;
  }
}
