# ChainCare: Blockchain-Secured Medical Records Management System

ChainCare is a comprehensive medical records ecosystem that bridges the trusting gap between patients and doctors using Blockchain technology and AI.

## 🚀 Key Features

*   **Secure Storage**: Cloud-based storage using Firebase with AES-256 encryption for data at rest and in transit.
*   **Blockchain Audit Trail**: A two-layer tamper-evident system using a real-time hash chain (Firestore) and daily anchoring on the Polygon Blockchain.
*   **AI-Powered Assistance**:
    *   **Doctor Clinical Assistant**: Analyzes patient records to provide clinical insights.
    *   **Patient Medical Assistant**: Educates patients about their health in simple terms.
    *   Powered by Google Gemini 2.0 Flash with RAG (Retrieval Augmented Generation).
*   **Smart Consent**: QR-based explicit patient consent mechanism for temporary doctor access.
*   **Biometric App Lock**: Banking-grade security using on-device biometrics (FaceID, Fingerprint).
*   **Doctor Verification**: ML-assisted verification of medical licenses using Google ML Kit.

## 🛠️ Technology Stack

*   **Frontend**: Flutter (iOS & Android)
*   **Backend**: Firebase Ecosystem
    *   Authentication (Email, Phone, Google)
    *   Cloud Firestore (NoSQL Database)
    *   Cloud Storage (Medical Documents)
    *   Cloud Functions (Node.js Serverless)
*   **Blockchain**: Polygon Amoy Testnet (Solidity Smart Contract)
*   **AI**: Google Gemini 2.0 Flash
*   **ML**: Google ML Kit (Text Recognition)

## 📦 Installation & Setup

### Prerequisites

*   Flutter SDK (3.0.0+)
*   Dart SDK
*   Firebase CLI
*   Node.js (for Cloud Functions)

### Steps

1.  **Clone the Repository**
    ```bash
    git clone https://github.com/yourusername/chaincare.git
    cd chaincare
    ```

2.  **Install Dependencies**
    ```bash
    flutter pub get
    ```

3.  **Environment Configuration**
    Create a `.env` file in the root directory and add your keys:
    ```env
    GEMINI_API_KEY=your_gemini_api_key
    ```

4.  **Run the App**
    ```bash
    flutter run
    ```

## 🔐 Security Architecture

ChainCare employs a defense-in-depth strategy:
1.  **Device Biometrics**: Secures local access.
2.  **Firebase Auth**: Secure user authentication.
3.  **Firestore Security Rules**: Server-side role-based access control.
4.  **Audit Logging**: Immutable internal logs.
5.  **Blockchain**: Public, decentralized verification of log integrity.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👥 Contributors

*   Authentication & User Management
*   Medical Records & Data Management
*   Blockchain Audit Trail & Verification
*   AI Clinical Assistants & Doctor Workflow
