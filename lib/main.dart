import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';
import 'screens/startup_check.dart';
import 'utils/ad_manager.dart';

// Global AdManager instance for app open ads
final globalAdManager = AdManager();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Google Mobile Ads on mobile platforms
  if (Platform.isAndroid || Platform.isIOS) {
    await MobileAds.instance.initialize();
    print('Google Mobile Ads initialized');
    
    // Preload app open ad for launch and wait for it to load
    await globalAdManager.loadAppOpenAd();
    print('App open ad loading initiated');
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
