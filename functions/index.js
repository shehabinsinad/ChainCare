const { onObjectFinalized } = require('firebase-functions/v2/storage');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onCall } = require('firebase-functions/v2/https');
const { setGlobalOptions } = require('firebase-functions/v2');
const admin = require('firebase-admin');
const pdfParse = require('pdf-parse');
const { ethers } = require('ethers');
const crypto = require('crypto');

// Set global options for all functions
setGlobalOptions({
    region: 'us-central1',
    timeoutSeconds: 120,
    memory: '512MiB',
});

admin.initializeApp();

// ═══════════════════════════════════════════════════════════
// BLOCKCHAIN CONFIGURATION
// ═══════════════════════════════════════════════════════════

// Polygon Amoy Testnet Configuration
const RPC_URL = 'https://rpc-amoy.polygon.technology';
const CHAIN_ID = 80002;

// Contract deployed on Polygon Amoy testnet
// SECURITY: For production mainnet, use Firebase Secret Manager
const CONTRACT_ADDRESS = '0x56bBF330d155B30aAeb904B93D21EeBCb1f96aB6';
const PRIVATE_KEY = 'a98c930c5b9df1be4c7b187459dd7365cc47af04c12fa3b136325e82dc8bdae4';

// Contract ABI (only the functions we need)
const CONTRACT_ABI = [
    "function storeAuditHash(string memory _date, string memory _merkleRoot, uint256 _entryCount) public",
    "function getAuditCount() public view returns (uint256)",
    "function getLatestAudit() public view returns (string memory, string memory, uint256, uint256)"
];

/**
 * Triggers when a PDF is uploaded to patients/{uid}/documents/
 * Extracts text and saves to Firestore
 * 
 * Uses Cloud Functions v2 (2nd Gen) for better performance
 */
exports.processMedicalPDF = onObjectFinalized(async (event) => {
    const filePath = event.data.name;
    const contentType = event.data.contentType;

    if (!contentType || !contentType.includes('pdf')) {
        console.log('Not a PDF, skipping');
        return null;
    }

    const pathParts = filePath.split('/');
    if (pathParts[0] !== 'patients' || pathParts.length < 4) {
        console.log('Invalid path structure, skipping');
        return null;
    }

    const userId = pathParts[1];
    const fileName = pathParts[pathParts.length - 1];

    console.log(`Processing PDF for user ${userId}: ${fileName}`);

    try {
        const bucket = admin.storage().bucket(event.data.bucket);
        const file = bucket.file(filePath);
        const [buffer] = await file.download();

        // Extract text
        const data = await pdfParse(buffer);
        const extractedText = data.text;
        const pageCount = data.numpages;

        console.log(`Extracted ${extractedText.length} characters from ${pageCount} pages`);

        // Get public download URL (simpler than signed URLs, no IAM permission needed)
        const fileUrl = `https://firebasestorage.googleapis.com/v0/b/${event.data.bucket}/o/${encodeURIComponent(filePath)}?alt=media`;

        // Create record in Firestore
        const recordRef = admin.firestore()
            .collection('users')
            .doc(userId)
            .collection('records')
            .doc();

        await recordRef.set({
            fileName: fileName,
            fileUrl: fileUrl, // Public HTTPS URL
            fileType: 'pdf',
            extractedText: extractedText,
            pageCount: pageCount,
            processingStatus: 'completed',
            uploadedAt: admin.firestore.FieldValue.serverTimestamp(),
            processedAt: admin.firestore.FieldValue.serverTimestamp(),
            type: inferDocumentType(fileName),
            // Placeholder fields (Flutter will update these)
            doctorId: null,
            doctorName: null,
            patientId: userId,
            diagnosis: null,
            notes: null,
            timestamp: admin.firestore.FieldValue.serverTimestamp(), // Critical for UI queries
        });

        console.log(`Successfully saved record ${recordRef.id}`);
        return null;

    } catch (error) {
        console.error('Error processing PDF:', error);

        await admin.firestore()
            .collection('users')
            .doc(userId)
            .collection('records')
            .doc()
            .set({
                fileName: fileName,
                fileUrl: `gs://${event.data.bucket}/${filePath}`,
                processingStatus: 'failed',
                errorMessage: error.message,
                uploadedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

        throw error;
    }
});

function inferDocumentType(fileName) {
    const lower = fileName.toLowerCase();
    if (lower.includes('lab') || lower.includes('test')) return 'lab_test';
    if (lower.includes('prescription') || lower.includes('rx')) return 'prescription';
    if (lower.includes('xray') || lower.includes('scan') || lower.includes('mri')) return 'imaging';
    if (lower.includes('discharge') || lower.includes('summary')) return 'summary';
    return 'other';
}

// ═══════════════════════════════════════════════════════════
// BLOCKCHAIN POSTING FUNCTIONS
// ═══════════════════════════════════════════════════════════

/**
 * Runs daily at midnight UTC (00:00)
 * Posts previous day's audit log Merkle root to Polygon blockchain
 */
exports.postDailyAuditHash = onSchedule({
    schedule: '0 0 * * *', // Every day at midnight UTC
    timeZone: 'UTC',
    timeoutSeconds: 540, // 9 minutes max
    memory: '1GiB',
}, async (event) => {
    console.log('═══════════════════════════════════════════════════');
    console.log('🔗 DAILY BLOCKCHAIN POSTING STARTED');
    console.log('═══════════════════════════════════════════════════');
    console.log(`⏰ Trigger time: ${new Date().toISOString()}`);

    try {
        // Calculate date range for yesterday
        const now = new Date();
        const yesterday = new Date(now);
        yesterday.setDate(yesterday.getDate() - 1);

        const dateString = formatDate(yesterday);
        console.log(`📅 Processing audit logs for: ${dateString}`);

        const startOfDay = new Date(yesterday);
        startOfDay.setHours(0, 0, 0, 0);

        const endOfDay = new Date(yesterday);
        endOfDay.setHours(23, 59, 59, 999);

        console.log(`📊 Time range: ${startOfDay.toISOString()} to ${endOfDay.toISOString()}`);

        // Fetch all audit entries from yesterday
        const snapshot = await admin.firestore()
            .collection('audit_chain')
            .where('timestamp', '>=', admin.firestore.Timestamp.fromDate(startOfDay))
            .where('timestamp', '<=', admin.firestore.Timestamp.fromDate(endOfDay))
            .orderBy('timestamp', 'asc')
            .get();

        if (snapshot.empty) {
            console.log('⚠️ No audit entries found for yesterday');
            console.log('ℹ️ This is normal if no medical access occurred');
            console.log('✅ Skipping blockchain posting');
            return null;
        }

        const entries = snapshot.docs.map(doc => doc.data());
        console.log(`📋 Found ${entries.length} audit entries`);

        // Sort by index to ensure consistent ordering
        entries.sort((a, b) => {
            const indexA = a.index || 0;
            const indexB = b.index || 0;
            return indexA - indexB;
        });

        // Extract hashes from entries
        const hashes = entries
            .map(entry => entry.hash || '')
            .filter(hash => hash.length > 0);

        if (hashes.length === 0) {
            throw new Error('No valid hashes found in audit entries');
        }

        console.log(`🔢 Extracted ${hashes.length} hashes`);

        // Compute Merkle root
        const merkleRoot = computeMerkleRoot(hashes);
        console.log(`🌳 Computed Merkle root: ${merkleRoot}`);

        // Post to blockchain
        console.log('📤 Posting to Polygon Amoy blockchain...');
        const txHash = await postToBlockchain(dateString, merkleRoot, entries.length);
        console.log(`✅ Transaction confirmed: ${txHash}`);
        console.log(`🔍 View on explorer: https://amoy.polygonscan.com/tx/${txHash}`);

        // Store blockchain anchor in Firestore
        await admin.firestore().collection('blockchain_anchors').add({
            date: dateString,
            merkleRoot: merkleRoot,
            entryCount: entries.length,
            transactionHash: txHash,
            explorerUrl: `https://amoy.polygonscan.com/tx/${txHash}`,
            postedAt: admin.firestore.FieldValue.serverTimestamp(),
            network: 'Polygon Amoy Testnet',
            chainId: CHAIN_ID,
        });

        console.log('💾 Blockchain anchor saved to Firestore');
        console.log('═══════════════════════════════════════════════════');
        console.log('✅ DAILY BLOCKCHAIN POSTING COMPLETED SUCCESSFULLY');
        console.log('═══════════════════════════════════════════════════');

        return null;

    } catch (error) {
        console.error('═══════════════════════════════════════════════════');
        console.error('❌ ERROR IN DAILY BLOCKCHAIN POSTING');
        console.error('═══════════════════════════════════════════════════');
        console.error('Error details:', error);
        console.error('Stack trace:', error.stack);

        // Log error to Firestore for admin monitoring
        try {
            await admin.firestore().collection('blockchain_errors').add({
                error: error.message,
                stack: error.stack,
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
                function: 'postDailyAuditHash',
            });
        } catch (logError) {
            console.error('Failed to log error to Firestore:', logError);
        }

        throw error;
    }
});

/**
 * Manual trigger for blockchain posting (admin/doctor testing)
 */
exports.manualPostAuditHash = onCall(async (request) => {
    // Verify caller is authenticated
    if (!request.auth) {
        throw new Error('User must be authenticated');
    }

    console.log(`🔧 Manual trigger by user: ${request.auth.uid}`);

    // Check if user is admin or doctor (for testing purposes)
    const userDoc = await admin.firestore()
        .collection('users')
        .doc(request.auth.uid)
        .get();

    if (!userDoc.exists) {
        throw new Error('User not found');
    }

    const userRole = userDoc.data().role;
    if (userRole !== 'admin' && userRole !== 'doctor') {
        throw new Error('Only admins and doctors can manually trigger blockchain posting');
    }

    console.log(`👤 User role: ${userRole}`);

    // Use provided date or yesterday (default behavior)
    const targetDateObj = request.data?.date
        ? new Date(request.data.date)
        : (() => { const d = new Date(); d.setDate(d.getDate() - 1); return d; })();

    const targetDate = formatDate(targetDateObj);

    try {
        console.log('═══════════════════════════════════════════════════');
        console.log('🔧 MANUAL BLOCKCHAIN POSTING STARTED');
        console.log('═══════════════════════════════════════════════════');
        console.log(`📅 Processing audit logs for: ${targetDate}`);
        console.log(`👤 Triggered by: ${request.auth.uid} (${userRole})`);

        const startOfDay = new Date(targetDateObj);
        startOfDay.setHours(0, 0, 0, 0);

        const endOfDay = new Date(targetDateObj);
        endOfDay.setHours(23, 59, 59, 999);

        console.log(`📊 Time range: ${startOfDay.toISOString()} to ${endOfDay.toISOString()}`);

        // Fetch all audit entries from target date
        const snapshot = await admin.firestore()
            .collection('audit_chain')
            .where('timestamp', '>=', admin.firestore.Timestamp.fromDate(startOfDay))
            .where('timestamp', '<=', admin.firestore.Timestamp.fromDate(endOfDay))
            .orderBy('timestamp', 'asc')
            .get();

        if (snapshot.empty) {
            console.log('⚠️ No audit entries found for this date');
            return {
                success: false,
                message: `No audit entries found for ${targetDate}. Blockchain posting requires at least one audit entry.`,
                date: targetDate,
                entryCount: 0,
            };
        }

        const entries = snapshot.docs.map(doc => doc.data());
        console.log(`📋 Found ${entries.length} audit entries`);

        // Sort by index
        entries.sort((a, b) => {
            const indexA = a.index || 0;
            const indexB = b.index || 0;
            return indexA - indexB;
        });

        // Extract hashes
        const hashes = entries
            .map(entry => entry.hash || '')
            .filter(hash => hash.length > 0);

        if (hashes.length === 0) {
            throw new Error('No valid hashes found in audit entries');
        }

        console.log(`🔢 Extracted ${hashes.length} hashes`);

        // Compute Merkle root
        const merkleRoot = computeMerkleRoot(hashes);
        console.log(`🌳 Computed Merkle root: ${merkleRoot}`);

        // Post to blockchain
        console.log('📤 Posting to Polygon Amoy blockchain...');
        const txHash = await postToBlockchain(targetDate, merkleRoot, entries.length);
        console.log(`✅ Transaction confirmed: ${txHash}`);

        // Store blockchain anchor in Firestore
        await admin.firestore().collection('blockchain_anchors').add({
            date: targetDate,
            merkleRoot: merkleRoot,
            entryCount: entries.length,
            transactionHash: txHash,
            explorerUrl: `https://amoy.polygonscan.com/tx/${txHash}`,
            postedAt: admin.firestore.FieldValue.serverTimestamp(),
            network: 'Polygon Amoy Testnet',
            chainId: CHAIN_ID,
            triggeredBy: request.auth.uid,
            triggerType: 'manual',
        });

        console.log('💾 Blockchain anchor saved to Firestore');
        console.log('═══════════════════════════════════════════════════');
        console.log('✅ MANUAL BLOCKCHAIN POSTING COMPLETED');
        console.log('═══════════════════════════════════════════════════');

        return {
            success: true,
            message: `Successfully posted ${entries.length} audit entries to blockchain`,
            date: targetDate,
            entryCount: entries.length,
            merkleRoot: merkleRoot,
            transactionHash: txHash,
            explorerUrl: `https://amoy.polygonscan.com/tx/${txHash}`,
        };

    } catch (error) {
        console.error('═══════════════════════════════════════════════════');
        console.error('❌ ERROR IN MANUAL BLOCKCHAIN POSTING');
        console.error('═══════════════════════════════════════════════════');
        console.error('Error details:', error);
        console.error('Stack trace:', error.stack);

        throw new Error(`Blockchain posting failed: ${error.message}`);
    }
});

/**
 * Get blockchain status and health check (all authenticated users)
 */
exports.getBlockchainStatus = onCall(async (request) => {
    if (!request.auth) {
        throw new Error('User must be authenticated');
    }

    try {
        console.log(`📊 Status check by user: ${request.auth.uid}`);

        // Get latest blockchain anchor
        const latestAnchorQuery = await admin.firestore()
            .collection('blockchain_anchors')
            .orderBy('postedAt', 'desc')
            .limit(1)
            .get();

        // Count pending audit entries (today)
        const today = new Date();
        const startOfToday = new Date(today);
        startOfToday.setHours(0, 0, 0, 0);

        const pendingEntriesQuery = await admin.firestore()
            .collection('audit_chain')
            .where('timestamp', '>=', admin.firestore.Timestamp.fromDate(startOfToday))
            .get();

        // Get recent errors
        const errorsQuery = await admin.firestore()
            .collection('blockchain_errors')
            .orderBy('timestamp', 'desc')
            .limit(3)
            .get();

        const result = {
            hasAnyPosts: !latestAnchorQuery.empty,
            pendingEntriesToday: pendingEntriesQuery.size,
            latestPost: null,
            recentErrors: [],
        };

        if (!latestAnchorQuery.empty) {
            const latest = latestAnchorQuery.docs[0].data();
            result.latestPost = {
                date: latest.date,
                entryCount: latest.entryCount,
                transactionHash: latest.transactionHash,
                postedAt: latest.postedAt?.toDate()?.toISOString(),
            };
        }

        if (!errorsQuery.empty) {
            result.recentErrors = errorsQuery.docs.map(doc => ({
                error: doc.data().error,
                timestamp: doc.data().timestamp?.toDate()?.toISOString(),
            }));
        }

        console.log(`✅ Status check complete`);
        return result;

    } catch (error) {
        console.error('Status check error:', error);
        throw new Error(`Status check failed: ${error.message}`);
    }
});

// ═══════════════════════════════════════════════════════════
// HELPER FUNCTIONS
// ═══════════════════════════════════════════════════════════

/**
 * Compute Merkle root from array of hashes
 */
function computeMerkleRoot(hashes) {
    if (hashes.length === 0) {
        return hash('EMPTY_BLOCK');
    }

    if (hashes.length === 1) {
        return hashes[0];
    }

    let currentLevel = [...hashes];

    while (currentLevel.length > 1) {
        const nextLevel = [];

        for (let i = 0; i < currentLevel.length; i += 2) {
            if (i + 1 < currentLevel.length) {
                // Pair exists - hash them together
                const combined = hash(currentLevel[i] + currentLevel[i + 1]);
                nextLevel.push(combined);
            } else {
                // Odd number - duplicate last hash
                const combined = hash(currentLevel[i] + currentLevel[i]);
                nextLevel.push(combined);
            }
        }

        currentLevel = nextLevel;
    }

    return currentLevel[0];
}

/**
 * SHA-256 hash function
 */
function hash(input) {
    return crypto
        .createHash('sha256')
        .update(input)
        .digest('hex');
}

/**
 * Post Merkle root to Polygon blockchain
 */
async function postToBlockchain(date, merkleRoot, entryCount) {
    console.log('🔧 Initializing blockchain connection...');

    // Create provider (RPC connection)
    const provider = new ethers.providers.JsonRpcProvider(RPC_URL);

    // Create wallet from private key
    const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
    console.log(`👛 Using wallet: ${wallet.address}`);

    // Check wallet balance
    const balance = await wallet.getBalance();
    console.log(`💰 Wallet balance: ${ethers.utils.formatEther(balance)} MATIC`);

    if (balance.isZero()) {
        throw new Error('Wallet has no MATIC. Get test tokens from https://faucet.polygon.technology');
    }

    // Create contract instance
    const contract = new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, wallet);
    console.log(`📝 Contract: ${CONTRACT_ADDRESS}`);

    // Estimate gas for the transaction
    try {
        const gasEstimate = await contract.estimateGas.storeAuditHash(
            date,
            merkleRoot,
            entryCount
        );
        console.log(`⛽ Estimated gas: ${gasEstimate.toString()}`);
    } catch (error) {
        console.error('⚠️ Gas estimation failed:', error.message);
        console.log('Proceeding with transaction anyway...');
    }

    // ✅ FIX: Fetch current gas prices to avoid "gas price below minimum" error
    console.log('💸 Fetching current gas prices...');
    const feeData = await provider.getFeeData();

    // Polygon Amoy requires minimum 25 Gwei priority fee
    // Set to 30 Gwei to have buffer above minimum
    const minPriorityFee = ethers.utils.parseUnits('30', 'gwei');
    const maxPriorityFee = feeData.maxPriorityFeePerGas && feeData.maxPriorityFeePerGas.gt(minPriorityFee)
        ? feeData.maxPriorityFeePerGas
        : minPriorityFee;

    const maxFeePerGas = feeData.maxFeePerGas && feeData.maxFeePerGas.gt(minPriorityFee)
        ? feeData.maxFeePerGas
        : ethers.utils.parseUnits('50', 'gwei'); // 50 Gwei max

    console.log(`⛽ Max Priority Fee: ${ethers.utils.formatUnits(maxPriorityFee, 'gwei')} Gwei`);
    console.log(`⛽ Max Fee Per Gas: ${ethers.utils.formatUnits(maxFeePerGas, 'gwei')} Gwei`);

    // Send transaction with proper gas configuration
    console.log('📤 Sending transaction...');
    const tx = await contract.storeAuditHash(date, merkleRoot, entryCount, {
        gasLimit: 500000, // Set reasonable gas limit
        maxPriorityFeePerGas: maxPriorityFee, // ✅ Priority fee (tip to miners)
        maxFeePerGas: maxFeePerGas, // ✅ Maximum total fee per gas
    });

    console.log(`⏳ Transaction sent: ${tx.hash}`);
    console.log('⏱️ Waiting for confirmation...');

    // Wait for confirmation (1 block on Polygon)
    const receipt = await tx.wait(1);

    console.log(`✅ Transaction confirmed in block ${receipt.blockNumber}`);
    console.log(`⛽ Gas used: ${receipt.gasUsed.toString()}`);

    return tx.hash;
}

/**
 * Format date as YYYY-MM-DD
 */
function formatDate(date) {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
}