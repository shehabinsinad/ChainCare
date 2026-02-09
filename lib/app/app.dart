import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'routes.dart';
import 'app_lock_gate.dart'; 

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class ChainCareApp extends StatelessWidget {
  const ChainCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'ChainCare',
      home: const AppLockGate(),
      routes: appRoutes, 
      // ✅ Premium Material Design 3 Theme
      theme: AppTheme.lightTheme,
    );
  }
}