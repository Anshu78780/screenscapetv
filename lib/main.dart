import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';
import 'screens/startup_check.dart';
import 'utils/ad_manager.dart';

// Global AdManager instance for Unity Ads
final globalAdManager = AdManager();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Unity Ads on mobile platforms
  if (Platform.isAndroid || Platform.isIOS) {
    await globalAdManager.initialize();
    print('Unity Ads initialization initiated');
    
    // Preload app open ad for launch
    await globalAdManager.loadAppOpenAd();
    print('Unity app open ad loading initiated');
  }
  
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    MediaKit.ensureInitialized();
    // Initialize window_manager for desktop fullscreen support
    await windowManager.ensureInitialized();
  }
  
  // Suppress image loading errors in console
  FlutterError.onError = (FlutterErrorDetails details) {
    // Filter out NetworkImageLoadException errors
    if (details.exception.toString().contains('NetworkImageLoadException') ||
        details.exception.toString().contains('HTTP request failed')) {
      // Silently ignore image loading errors
      return;
    }
    // For other errors, use the default handler
    FlutterError.presentError(details);
  };
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScreenScapeTV',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.red,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.outfitTextTheme(
          ThemeData.dark().textTheme,
        ),
      ),
      home: const StartupCheck(),
    );
  }
}
