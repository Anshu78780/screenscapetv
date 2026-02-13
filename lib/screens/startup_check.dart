import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/vlc_checker.dart';
import '../utils/update_checker.dart';
import '../widgets/update_dialog.dart';
import '../main.dart';
import 'movies_screen.dart';

class StartupCheck extends StatefulWidget {
  const StartupCheck({super.key});

  @override
  State<StartupCheck> createState() => _StartupCheckState();
}

class _StartupCheckState extends State<StartupCheck> {
  String _statusMessage = 'Checking requirements...';

  @override
  void initState() {
    super.initState();
    _checkVlc();
  }

  Future<void> _checkVlc() async {
    // Add a delay to ensure context is ready and give more time for ad to load
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    // Show app open ad if ready
    if (globalAdManager.isAppOpenAdReady) {
      print('App open ad is ready, showing now');
      setState(() {
        _statusMessage = 'Loading...';
      });
      
      await globalAdManager.showAppOpenAd(
        onAdClosed: () {
          print('App open ad closed, proceeding with startup');
          if (mounted) {
            _proceedWithStartup();
          }
        },
        onAdFailedToShow: () {
          print('App open ad failed to show, proceeding with startup');
          if (mounted) {
            _proceedWithStartup();
          }
        },
      );
    } else {
      // If ad not ready after delay, proceed directly
      print('App open ad not ready, proceeding without ad');
      _proceedWithStartup();
    }
  }

  Future<void> _proceedWithStartup() async {
    if (!mounted) return;

    setState(() {
      _statusMessage = 'Checking VLC installation...';
    });

    final installed = await VlcChecker.isVlcInstalled();

    if (installed) {
      // Check for updates before navigating to home
      if (mounted) {
        setState(() {
          _statusMessage = 'Checking for updates...';
        });
      }
      await _checkForUpdates();
      if (mounted) {
        _navigateToHome();
      }
    } else {
      _showInstallDialog();
    }
  }

  Future<void> _checkForUpdates() async {
    try {
      final updateInfo = await UpdateChecker.checkForUpdate();
      
      if (updateInfo != null && mounted) {
        // Show update dialog if new version is available
        await UpdateDialog.show(context, updateInfo);
      }
    } catch (e) {
      // Silently fail if update check fails - don't block app startup
      debugPrint('Update check failed: $e');
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MoviesScreen()),
    );
  }

  void _showInstallDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber),
              SizedBox(width: 10),
              Text('VLC Needed', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hey, to play stream VLC is needed.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Please restart the app after installation.',
                        style: TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                 Uri url;
                 if (Platform.isAndroid) {
                    url = Uri.parse('market://details?id=org.videolan.vlc');
                 } else {
                    url = Uri.parse('https://www.videolan.org/vlc/'); 
                 }
                 
                 try {
                   if (await canLaunchUrl(url)) {
                     await launchUrl(url, mode: LaunchMode.externalApplication);
                   } else if (Platform.isAndroid) {
                      // Fallback to web link
                      final webUrl = Uri.parse('https://play.google.com/store/apps/details?id=org.videolan.vlc');
                      if (await canLaunchUrl(webUrl)) {
                         await launchUrl(webUrl, mode: LaunchMode.externalApplication);
                      }
                   }
                 } catch (e) {
                   debugPrint('Could not launch URL: $e');
                 }
              },
              child: const Text('Download', style: TextStyle(color: Colors.amber)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                final installed = await VlcChecker.isVlcInstalled();
                if (!context.mounted) return;
                
                if (installed) {
                   Navigator.of(context).pop();
                   _navigateToHome();
                } else {
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(
                       content: Text('VLC not detected. Please install and restart the app.'),
                       backgroundColor: Colors.red,
                     ),
                   );
                   // We don't verify forcefully if they say "Already Downloaded" but check fails.
                   // But since the requirement implies checking: "if user has installed vlc... cache... if no vlc... dialog"
                   // It implies we shouldn't proceed until we confirm it. 
                }
              },
               child: const Text('Already Downloaded'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.amber),
            const SizedBox(height: 20),
            Text(
              _statusMessage,
              style: const TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}
