import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/blockchain_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/premium_button.dart';
import 'emergency_view.dart';

/// Premium Emergency Access Gate
/// Red gradient background with critical warning design
class EmergencyGate extends StatefulWidget {
  const EmergencyGate({super.key});

  @override
  State<EmergencyGate> createState() => _EmergencyGateState();
}

class _EmergencyGateState extends State<EmergencyGate> {
  final _idCtrl = TextEditingController();
  bool _loading = false;

  /// Handles the Access Logic: Reason -> Log -> Navigate
  Future<void> _processAccess(String uid) async {
    if (uid.trim().isEmpty) return;

    // 1. Mandatory Reason Selection
    final reason = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.emergency,
                size: 48,
                color: AppColors.error,
              ),
              const SizedBox(height: 16),
              Text(
                "Select Emergency Reason",
                style: AppTextStyles.titleLarge.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              _reasonOption("Unconscious / Unresponsive"),
              _reasonOption("Severe Trauma / Accident"),
              _reasonOption("Cardiac Arrest"),
              _reasonOption("Respiratory Failure"),
              _reasonOption("Other Critical Emergency"),
            ],
          ),
        ),
      ),
    );

    if (reason == null) return;

    setState(() => _loading = true);

    try {
      // 2. Log to Blockchain
      await BlockchainService.logTransaction(
        action: "EMERGENCY_VIEW",
        patientId: uid.trim(),
        doctorId: "ANONYMOUS_RESPONDER",
        reason: reason,
        details: "Emergency Access via Public Gateway",
      );

      if (!mounted) return;

      // 3. Navigate to Critical View
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => EmergencyView(patientUid: uid.trim()),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Error: $e",
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.white),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        setState(() => _loading = false);
      }
    }
  }

  Widget _reasonOption(String text) {
    return InkWell(
      onTap: () => Navigator.pop(context, text),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.error.withOpacity(0.2)),
        ),
        child: Text(
          text,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  /// Opens the Camera Scanner
  void _openScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: AppColors.deepCharcoal,
          appBar: AppBar(
            title: const Text("Scan Patient QR"),
            backgroundColor: AppColors.error,
            foregroundColor: AppColors.white,
          ),
          body: MobileScanner(
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  Navigator.pop(ctx);
                  _processAccess(barcode.rawValue!);
                  break;
                }
              }
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.errorGradient,
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Main Content
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Emergency Icon
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.emergency,
                          size: 64,
                          color: AppColors.white,
                        ),
                      ).animate().scale(curve: Curves.elasticOut).then()
                        .shimmer(duration: 1500.ms, color: AppColors.white.withOpacity(0.3)),

                      const SizedBox(height: 32),

                      // Title
                      Text(
                        "Emergency Override",
                        textAlign: TextAlign.center,
                        style: AppTextStyles.displayMedium.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ).animate().fadeIn(delay: 100.ms),

                      const SizedBox(height: 12),

                      // Warning Text
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.white.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: AppColors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                "Use only for medical emergencies",
                                textAlign: TextAlign.center,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 200.ms),

                      const SizedBox(height: 8),

                      Text(
                        "All actions are permanently logged on blockchain",
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.white.withOpacity(0.8),
                        ),
                      ).animate().fadeIn(delay: 300.ms),

                      const SizedBox(height: 40),

                      // Floating Card with Controls
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: AppColors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Scanner Button
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.error.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.error.withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _openScanner,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Padding(
                                    padding: const EdgeInsets.all(18),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.qr_code_scanner,
                                          size: 32,
                                          color: AppColors.error,
                                        ),
                                        const SizedBox(width: 16),
                                        Text(
                                          "SCAN PATIENT QR",
                                          style: AppTextStyles.titleSmall.copyWith(
                                            color: AppColors.error,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Divider
                            Row(
                              children: [
                                const Expanded(child: Divider()),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    "OR",
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.mediumGray,
                                    ),
                                  ),
                                ),
                                const Expanded(child: Divider()),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // Manual Entry
                            TextField(
                              controller: _idCtrl,
                              style: AppTextStyles.bodyLarge,
                              decoration: InputDecoration(
                                labelText: "Manual Patient ID (UID)",
                                labelStyle: AppTextStyles.bodyMedium,
                                prefixIcon: const Icon(Icons.keyboard),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppColors.softGray),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.error,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Access Button
                            Container(
                              decoration: BoxDecoration(
                                gradient: AppColors.errorGradient,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.error.withOpacity(0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _loading ? null : () => _processAccess(_idCtrl.text),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 18),
                                    child: Center(
                                      child: _loading
                                          ? const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                color: AppColors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : Text(
                                              "ACCESS CRITICAL DATA",
                                              style: AppTextStyles.labelLarge.copyWith(
                                                color: AppColors.white,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),
                    ],
                  ),
                ),
              ),

              // Back Button (on top)
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.white),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}