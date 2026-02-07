import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'screens/movies_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
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
      ),
      home: const MoviesScreen(),
    );
  }
}
