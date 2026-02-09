import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/blockchain_service.dart';
import 'doctor_patient_view.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  bool _isScanned = false;

  void _onDetect(BarcodeCapture capture) async {
    if (_isScanned) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        final String code = barcode.rawValue!;
        if (code.length > 20) {
          setState(() => _isScanned = true);
          
          await BlockchainService.logTransaction(
            action: "EMERGENCY_VIEW",
            patientId: code,
            doctorId: "ANONYMOUS_RESPONDER",
            details: "Access via Public Emergency Scanner",
            reason: "Unconscious / Unresponsive", 
          );

          if (!mounted) return;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => DoctorPatientView(
                patientUid: code,
                isReadOnly: true,
              ),
            ),
          );
          return;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Emergency Scanner"), backgroundColor: Colors.red),
      body: MobileScanner(onDetect: _onDetect),
    );
  }
}