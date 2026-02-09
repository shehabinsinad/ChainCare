# ChainCare Cloud Functions

Firebase Cloud Functions for automated medical document processing.

## Functions

### `processMedicalPDF`
Automatically processes PDF files uploaded to Firebase Storage.

**Trigger**: Storage object finalize  
**Path**: `patients/{uid}/documents/*.pdf`  
**Runtime**: Node.js 18  

**What it does**:
1. Detects PDF uploads to the `patients/{uid}/documents/` path
2. Downloads PDF from Storage
3. Extracts text content using `pdf-parse` library
4. Saves extracted text to Firestore: `users/{uid}/records/{recordId}`
5. Handles errors gracefully, saving failed status when needed

**Firestore Record Schema**:
```javascript
{
  fileName: string,           // Original filename
  fileUrl: string,            // gs:// Storage URL
  fileType: 'pdf',           
  extractedText: string,      // Extracted PDF text
  pageCount: number,          // Number of pages
  processingStatus: 'completed' | 'failed',
  uploadedAt: Timestamp,
  processedAt: Timestamp,
  type: string,               // Inferred doc type (lab_test, prescription, etc.)
  errorMessage?: string       // Only present if failed
}
```

## Setup

### Prerequisites
- Node.js 18+ installed
- Firebase CLI: `npm install -g firebase-tools`
- Firebase project with Blaze (pay-as-you-go) plan

### Installation

```bash
# Install dependencies
npm install

# Login to Firebase
firebase login

# Deploy
firebase deploy --only functions
```

### Local Testing

```bash
# Install Firebase Functions shell
npm install -g firebase-functions

# Start emulator
firebase emulators:start --only functions
```

## Dependencies

- **firebase-admin** (^12.0.0) - Firestore and Storage access
- **firebase-functions** (^4.5.0) - Cloud Functions runtime
- **@google-cloud/storage** (^7.7.0) - Storage file operations  
- **pdf-parse** (^1.1.1) - PDF text extraction

## Monitoring

View logs:
```bash
# Real-time logs
firebase functions:log --only processMedicalPDF

# Last 10 entries
firebase functions:log --only processMedicalPDF --limit 10
```

View in Firebase Console:
- Functions → processMedicalPDF → Logs

## Cost Estimation

Free tier: 2M invocations/month

Typical costs:
- 100 PDFs/month: FREE
- 1,000 PDFs/month: ~$0.50
- 10,000 PDFs/month: ~$5.00

## Troubleshooting

**Issue**: Function not triggering  
**Solution**: Verify PDFs are uploaded to `patients/{uid}/documents/` path

**Issue**: Empty extracted text  
**Cause**: Scanned PDF without text layer  
**Solution**: Consider OCR preprocessing

**Issue**: Timeout  
**Cause**: Very large PDF (>50 pages)  
**Solution**: Increase timeout in function config

## Security

- Only processes files in `patients/` path
- Authenticated user uploads only
- Firestore rules enforce ownership
- No sensitive data in logs

## Maintenance

When updating the function:
1. Make changes to `index.js`
2. Test locally with emulator
3. Deploy: `firebase deploy --only functions`
4. Monitor logs for errors
5. Verify with test upload

## Support

- [Firebase Functions Docs](https://firebase.google.com/docs/functions)
- [pdf-parse on npm](https://www.npmjs.com/package/pdf-parse)
- See `../artifacts/deployment_guide.md` for full deployment instructions
