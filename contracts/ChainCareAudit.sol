// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title ChainCareAudit
 * @dev Store daily Merkle root hashes of medical audit logs on Polygon blockchain
 * @notice This contract provides tamper-evident proof of audit trail integrity
 * 
 * Architecture:
 * - Daily aggregation of audit logs into Merkle tree
 * - Only root hash stored on-chain (privacy-preserving)
 * - Immutable, publicly verifiable proof of data existence
 * 
 * Deployed on: Polygon Amoy Testnet (Chain ID: 80002)
 * Network: https://rpc-amoy.polygon.technology
 * Explorer: https://amoy.polygonscan.com
 */
contract ChainCareAudit {
    
    /// @dev Structure representing a daily audit entry
    struct AuditEntry {
        string date;           // Date in YYYY-MM-DD format
        string merkleRoot;     // SHA-256 Merkle root hash (64-char hex string)
        uint256 entryCount;    // Number of audit logs aggregated
        uint256 timestamp;     // Block timestamp when posted
    }
    
    /// @dev Array storing all audit entries (indexed by post order)
    AuditEntry[] public audits;
    
    /// @dev Mapping from date string to audit index (for quick lookups)
    mapping(string => uint256) public dateToIndex;
    
    /// @dev Contract owner (for potential admin functions)
    address public owner;
    
    /**
     * @dev Emitted when a new audit hash is stored
     * @param index Position in audits array
     * @param date Date of the audit entries
     * @param merkleRoot Merkle root hash
     * @param entryCount Number of entries included
     * @param timestamp Block timestamp
     */
    event AuditHashStored(
        uint256 indexed index,
        string date,
        string merkleRoot,
        uint256 entryCount,
        uint256 timestamp
    );
    
    /**
     * @dev Constructor - sets contract deployer as owner
     */
    constructor() {
        owner = msg.sender;
    }
    
    /**
     * @dev Store a daily audit hash on the blockchain
     * @param _date Date in YYYY-MM-DD format (e.g., "2025-01-05")
     * @param _merkleRoot Merkle root hash as hex string (64 characters)
     * @param _entryCount Number of audit log entries included in this hash
     * 
     * Requirements:
     * - Date must not be empty
     * - Merkle root must be exactly 64 characters (SHA-256 hex)
     * - Entry count must be greater than 0
     * 
     * Emits: AuditHashStored event
     */
    function storeAuditHash(
        string memory _date,
        string memory _merkleRoot,
        uint256 _entryCount
    ) public {
        // Input validation
        require(bytes(_date).length > 0, "Date cannot be empty");
        require(bytes(_merkleRoot).length == 64, "Invalid merkle root length");
        require(_entryCount > 0, "Entry count must be positive");
        
        // Create audit entry
        audits.push(AuditEntry({
            date: _date,
            merkleRoot: _merkleRoot,
            entryCount: _entryCount,
            timestamp: block.timestamp
        }));
        
        // Store index for this date
        uint256 index = audits.length - 1;
        dateToIndex[_date] = index;
        
        // Emit event for indexing
        emit AuditHashStored(
            index,
            _date,
            _merkleRoot,
            _entryCount,
            block.timestamp
        );
    }
    
    /**
     * @dev Get total number of audit entries stored
     * @return count Total number of daily hashes posted
     */
    function getAuditCount() public view returns (uint256) {
        return audits.length;
    }
    
    /**
     * @dev Get audit entry by index
     * @param index Position in audits array (0-based)
     * @return date Date string
     * @return merkleRoot Merkle root hash
     * @return entryCount Number of entries
     * @return timestamp Block timestamp
     */
    function getAudit(uint256 index) public view returns (
        string memory date,
        string memory merkleRoot,
        uint256 entryCount,
        uint256 timestamp
    ) {
        require(index < audits.length, "Index out of bounds");
        AuditEntry memory entry = audits[index];
        return (
            entry.date,
            entry.merkleRoot,
            entry.entryCount,
            entry.timestamp
        );
    }
    
    /**
     * @dev Get the most recent audit entry
     * @return date Date string
     * @return merkleRoot Merkle root hash
     * @return entryCount Number of entries
     * @return timestamp Block timestamp
     */
    function getLatestAudit() public view returns (
        string memory date,
        string memory merkleRoot,
        uint256 entryCount,
        uint256 timestamp
    ) {
        require(audits.length > 0, "No audits stored yet");
        return getAudit(audits.length - 1);
    }
    
    /**
     * @dev Get audit entry by date
     * @param _date Date string in YYYY-MM-DD format
     * @return date Date string
     * @return merkleRoot Merkle root hash
     * @return entryCount Number of entries
     * @return timestamp Block timestamp
     */
    function getAuditByDate(string memory _date) public view returns (
        string memory date,
        string memory merkleRoot,
        uint256 entryCount,
        uint256 timestamp
    ) {
        uint256 index = dateToIndex[_date];
        require(index < audits.length, "Date not found");
        return getAudit(index);
    }
    
    /**
     * @dev Check if an audit exists for a specific date
     * @param _date Date string in YYYY-MM-DD format
     * @return exists True if audit exists for this date
     */
    function hasAuditForDate(string memory _date) public view returns (bool) {
        if (audits.length == 0) return false;
        uint256 index = dateToIndex[_date];
        if (index >= audits.length) return false;
        
        // Verify the date actually matches (mapping returns 0 for non-existent keys)
        return keccak256(bytes(audits[index].date)) == keccak256(bytes(_date));
    }
    
    /**
     * @dev Get multiple audit entries at once (pagination support)
     * @param startIndex Starting index
     * @param count Number of entries to retrieve
     * @return entries Array of audit entries
     */
    function getAuditRange(
        uint256 startIndex,
        uint256 count
    ) public view returns (AuditEntry[] memory) {
        require(startIndex < audits.length, "Start index out of bounds");
        
        uint256 endIndex = startIndex + count;
        if (endIndex > audits.length) {
            endIndex = audits.length;
        }
        
        uint256 resultCount = endIndex - startIndex;
        AuditEntry[] memory result = new AuditEntry[](resultCount);
        
        for (uint256 i = 0; i < resultCount; i++) {
            result[i] = audits[startIndex + i];
        }
        
        return result;
    }
}
