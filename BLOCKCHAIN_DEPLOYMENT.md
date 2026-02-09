# Polygon Amoy Blockchain Integration - Deployment Guide

## Overview

This guide walks you through deploying the blockchain verification system for ChainCare. Total estimated time: **30-45 minutes**.

## Prerequisites Checklist

- [ ] MetaMask wallet installed
- [ ] Test MATIC from faucet
- [ ] Contract deployed on Polygon Amoy
- [ ] Contract address and ABI saved
- [ ] Private key securely stored
- [ ] Firebase CLI installed

---

## Step 1: MetaMask Wallet Setup (15 minutes)

### Install MetaMask

1. Visit https://metamask.io/download/
2. Install browser extension
3. Click "Create a wallet"
4. **CRITICAL**: Save your seed phrase securely (write it down on paper!)
5. Set a strong password

### Add Polygon Amoy Network

1. Open MetaMask extension
2. Click network dropdown (top center)
3. Click "Add Network" → "Add a network manually"
4. Enter these **exact** details:
   ```
   Network Name: Amoy
   RPC URL: https://rpc-amoy.polygon.technology
   Chain ID: 80002
   Currency Symbol: POL
   Block Explorer: https://amoy.polygonscan.com
   ```
5. Click "Save"
6. Switch to "Amoy" network

> **Note**: Polygon recently rebranded from MATIC to POL. MetaMask may suggest these values automatically - that's correct!

### Copy Your Wallet Address

1. Click account name at top
2. Click address to copy
3. Should look like: `0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb`
4. Save this address - you'll need it multiple times

---

## Step 2: Get Test MATIC/POL (10 minutes)

You need test MATIC (now branded as POL) to deploy contracts and send transactions.

### Option 1: Official Polygon Faucet (Recommended)

1. Visit: https://faucet.polygon.technology
2. Select network: "Polygon Amoy"
3. Paste your wallet address
4. Complete CAPTCHA
5. Click "Submit"
6. Wait 30-60 seconds
7. Check MetaMask - you should see ~0.5 MATIC

### Option 2: Alchemy Faucet (Backup)

- Visit: https://www.alchemy.com/faucets/polygon-amoy
- Sign up (free)
- Enter wallet address
- Get 0.5 MATIC

### Verify Balance

1. Open MetaMask
2. Ensure "Amoy" network is selected
3. You should see: **0.5 POL** (or similar - may show as MATIC in some places)

---

## Step 3: Deploy Smart Contract (20 minutes)

### Open Remix IDE

1. Visit: https://remix.ethereum.org
2. Wait for IDE to load

### Create Contract File

1. In "File Explorer" (left sidebar)
2. Click "contracts" folder
3. Click "+" icon to create new file
4. Name it: `ChainCareAudit.sol`

### Paste Contract Code

1. Open `c:\projects\chaincare\contracts\ChainCareAudit.sol`
2. Copy all the code
3. Paste into Remix editor
4. Save (Ctrl+S or Cmd+S)

### Compile Contract

1. Click "Solidity Compiler" icon (left sidebar, 3rd icon)
2. Compiler version: Select **0.8.20 or higher**
3. Click "Compile ChainCareAudit.sol"
4. You should see green checkmark ✅

### Deploy Contract

1. Click "Deploy & Run" icon (left sidebar, 4th icon)
2. Environment: Select **"Injected Provider - MetaMask"**
3. MetaMask popup will appear → Click **"Connect"**
4. Verify network shows: "**Polygon Amoy (80002)**"
5. Contract dropdown: Should show "**ChainCareAudit**"
6. Click orange **"Deploy"** button
7. MetaMask popup → Click **"Confirm"**
8. Wait 5-10 seconds for deployment

### Save Contract Address

1. After deployment, see "Deployed Contracts" section at bottom
2. Click "Copy" icon next to contract address
3. Address looks like: `0x123abc...`
4. **SAVE THIS ADDRESS!** You'll need it in multiple places

### Verify on PolygonScan (Optional but Recommended)

1. Visit: `https://amoy.polygonscan.com/address/[YOUR_CONTRACT_ADDRESS]`
2. Replace `[YOUR_CONTRACT_ADDRESS]` with your actual address
3. You should see:
   - Contract created
   - Transaction count: 1 (the deployment)

### Copy Contract ABI

1. In Remix, click "Solidity Compiler" icon
2. Scroll down to "Compilation Details"
3. Click "ABI" button
4. Copy the entire JSON array
5. Open `c:\projects\chaincare\assets\contracts\ChainCareAudit.json`
6. **Replace all content** with the copied ABI
7. Save the file

---

## Step 4: Configure ChainCare App (10 minutes)

### Update Blockchain Service

1. Open `c:\projects\chaincare\lib\services\blockchain_service.dart`
2. **Line 14**: Replace contract address:
   ```dart
   static const String contractAddress = '0xYOUR_DEPLOYED_CONTRACT_ADDRESS';
   ```
3. **Line 17**: Get your private key from MetaMask:
   - Click MetaMask → Three dots menu → Account Details
   - Click "Export Private Key"
   - Enter password
   - Copy private key (64 hex characters)
   - Paste in code:
   ```dart
   static const String privateKey = 'your_private_key_here';
   ```

> ⚠️ **WARNING**: This is for TESTNET ONLY! Never commit private keys to git!

### Verify Assets Folder

1. Ensure `c:\projects\chaincare\assets\contracts\ChainCareAudit.json` exists
2. Should contain the full ABI you copied from Remix

---

## Step 5: Deploy Firebase Functions (15 minutes)

### Install Firebase CLI (if not already installed)

```powershell
npm install -g firebase-tools
```

### Login to Firebase

```powershell
cd c:\projects\chaincare
firebase login
```

### Install Dependencies

```powershell
cd c:\projects\chaincare\functions
npm install ethers@5.7.2
```

> **IMPORTANT**: Must be ethers v5, not v6!

### Update Configuration

1. Open `c:\projects\chaincare\functions\index.js`
2. **Line 25**: Replace contract address:
   ```javascript
   const CONTRACT_ADDRESS = 'YOUR_DEPLOYED_CONTRACT_ADDRESS';
   ```
3. **Line 26**: Replace private key:
   ```javascript
   const PRIVATE_KEY = 'your_private_key_here';
   ```

### Deploy to Firebase

```powershell
cd c:\projects\chaincare
firebase deploy --only functions
```

This takes 2-5 minutes. You should see:
```
✔ functions[postDailyAuditHash(us-central1)] Successful create operation.
✔ functions[manualPostAuditHash(us-central1)] Successful create operation.
```

### Verify Deployment

1. Visit: https://console.firebase.google.com
2. Select your ChainCare project
3. Go to "Functions" section
4. You should see: `postDailyAuditHash` (scheduled function)

---

## Step 6: Test the Integration (30 minutes)

### Test 1: Run Flutter App

```powershell
cd c:\projects\chaincare
flutter pub get
flutter run
```

### Test 2: Navigate to Blockchain Verification

1. Login as admin
2. Navigate to Admin Dashboard
3. Click "Blockchain Verification" card
4. Screen should load without errors
5. You should see: "No blockchain posts yet"

### Test 3: Create Test Audit Entries

1. Login as a doctor
2. Scan a patient's QR code
3. View patient records (this creates audit entry)
4. Repeat 2-3 times to have multiple entries
5. Verify in Firebase Console:
   - Firestore → `audit_chain` collection
   - Should see new documents with today's timestamp

### Test 4: Manual Blockchain Post (Optional)

You can add a temporary test button to admin dashboard to post immediately without waiting for midnight:

```dart
// Add to admin_dashboard.dart temporarily
ElevatedButton(
  onPressed: () async {
    try {
      await BlockchainService.initialize();
      
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final snapshot = await FirebaseFirestore.instance
          .collection('audit_chain')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();
      
      final entries = snapshot.docs.map((d) => d.data()).toList();
      final merkleRoot = MerkleTreeService.computeFromAuditEntries(entries);
      final dateString = DateFormat('yyyy-MM-dd').format(today);
      
      final txHash = await BlockchainService.postDailyHash(
        date: dateString,
        merkleRoot: merkleRoot,
        entryCount: entries.length,
      );
      
      await FirebaseFirestore.instance.collection('blockchain_anchors').add({
        'date': dateString,
        'merkleRoot': merkleRoot,
        'entryCount': entries.length,
        'transactionHash': txHash,
        'postedAt': FieldValue.serverTimestamp(),
        'network': 'Polygon Amoy',
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Posted! Tx: ${txHash.substring(0, 10)}...')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  },
  child: const Text('🧪 TEST: Post to Blockchain Now'),
)
```

### Test 5: Verify on PolygonScan

1. Copy transaction hash from success message
2. Visit: `https://amoy.polygonscan.com/tx/[YOUR_TX_HASH]`
3. Verify:
   - ✅ Status: Success
   - ✅ To: Your contract address
   - ✅ Method: `storeAuditHash`
4. Click "Logs" tab
5. Verify event: `AuditHashStored`

### Test 6: View in App

1. Navigate to "Blockchain Verification" screen
2. You should see your posted entry
3. Click "View on PolygonScan" → Opens browser correctly
4. Click "Verify Integrity" button
5. Should show: ✅ "Verified - Hashes match!"

---

## Troubleshooting Common Issues

### "Insufficient funds for gas"
- **Solution**: Get more test MATIC from faucet

### "Contract not found at address"
- **Solution**: Verify contract address is correct and deployed on Amoy (not mainnet)

### "Failed to load ABI"
- **Solution**: 
  - Check `assets/contracts/ChainCareAudit.json` exists
  - Run `flutter pub get`
  - Restart app (hot reload won't work for asset changes)

### "Network 80002 not supported"
- **Solution**: Verify MetaMask is on Amoy network, check chain ID is exactly 80002

### Firebase Function timeout
- **Solution**: Already configured with 540s timeout (max allowed)

---

## Security Checklist

### ✅ For Testnet (Current)
- Private key in code (test wallet only)
- Small amounts (~0.5 MATIC)
- Public contract address

### ⚠️ For Mainnet (Future)
- **NEVER** hardcode private key
- Use Firebase Secret Manager
- Dedicated wallet for automated posting
- Fund with only $10-20 MATIC at a time
- Add `.env` to `.gitignore`

---

## Next Steps

1. Wait until tomorrow (midnight UTC) for automatic posting
2. Or manually trigger via test button
3. Monitor Firebase Functions logs:
   ```powershell
   firebase functions:log --only postDailyAuditHash
   ```
4. Check `blockchain_anchors` collection grows daily

## Cost Breakdown

### Testnet (Current)
- Contract deployment: **FREE** (test MATIC)
- Daily transactions: **FREE** (test MATIC)
- Total: **₹0/month**

### Mainnet (Future)
- Contract deployment: $3-5 one-time
- Daily transaction: $0.05 × 30 days = $1.50/month
- **Total first year: ~$23 (₹1,840)**

---

## Migration to Mainnet (Future)

When ready for production:

1. Change 3 lines in `blockchain_service.dart`:
   ```dart
   static const String rpcUrl = 'https://polygon-rpc.com'; // Line 10
   static const int chainId = 137; // Line 11 (Polygon mainnet)
   ```
   
2. Change explorer URLs to `polygonscan.com` (remove `amoy.`)

3. Update `functions/index.js` similarly

4. Deploy contract on Polygon mainnet (costs ~$3-5)

5. Update configuration with new contract address

6. Deploy Firebase Functions

**That's it!** Cost: ~$1.50/month for daily posts.
