import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables (optional - app will work without .env for now)
  try {
    await dotenv.load(fileName: ".env");
    debugPrint('✅ .env file loaded successfully');
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey != null && apiKey.isNotEmpty) {
      debugPrint('✅ API key found: ${apiKey.substring(0, 10)}...');
    } else {
      debugPrint('⚠️ API key is empty or null');
    }
  } catch (e) {
    // .env file not found - AI features will show error when used
    debugPrint('⚠️ .env file not found or error loading: $e');
  }
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ⚠️ DEBUG ONLY: Force sign out on restart for testing auth flows
  // TODO: Remove this entire block before production release
  if (kDebugMode) {
    debugPrint('🔧 DEBUG MODE: Forcing sign out on restart');
    await FirebaseAuth.instance.signOut();
  }

  runApp(const ChainCareApp());
}