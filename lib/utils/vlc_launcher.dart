import 'dart:io';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class VlcLauncher {
  static Future<void> launchVlc(String url, String title) async {
    try {
      if (Platform.isLinux) {
        await _openVLCOnLinux(url);
      } else if (Platform.isAndroid) {
        await _openVLCOnAndroid(url, title);
      } else if (Platform.isIOS) {
        await _openVLCOnIOS(url);
      } else {
        throw 'VLC integration not available for this platform';
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> _openVLCOnLinux(String url) async {
    bool launched = false;

    try {
      await Process.start('vlc', [url], mode: ProcessStartMode.detached);
      launched = true;
      return;
    } catch (e) {
      print('Standard VLC not found: $e');
    }

    if (!launched) {
      try {
        await Process.start('flatpak', [
          'run',
          'org.videolan.VLC',
          url,
        ], mode: ProcessStartMode.detached);
        launched = true;
        return;
      } catch (e) {
        print('Flatpak VLC not found: $e');
      }
    }

    if (!launched) {
      try {
        await Process.start('snap', [
          'run',
          'vlc',
          url,
        ], mode: ProcessStartMode.detached);
        launched = true;
        return;
      } catch (e) {
        print('Snap VLC not found: $e');
      }
    }

    if (!launched) {
      try {
        final whichResult = await Process.run('which', ['vlc']);
        if (whichResult.exitCode == 0 &&
            whichResult.stdout.toString().trim().isNotEmpty) {
          final vlcPath = whichResult.stdout.toString().trim();
          await Process.start(vlcPath, [url], mode: ProcessStartMode.detached);
          launched = true;
          return;
        }
      } catch (e) {
        print('Which command failed: $e');
      }
    }

    if (!launched) {
      try {
        await Process.start('xdg-open', [url], mode: ProcessStartMode.detached);
      } catch (e) {
        throw 'VLC not found. Please install VLC: sudo apt install vlc';
      }
    }
  }

  static Future<void> _openVLCOnAndroid(String url, String title) async {
    const platform = MethodChannel('com.example.screenscapetv/vlc');

    try {
      final bool? result = await platform.invokeMethod('launchVLC', {
        'url': url,
        'title': title,
      });

      if (result == true) {
        return;
      }
    } catch (e) {
      print('Platform channel failed: $e');
    }

    bool launched = false;

    try {
      final vlcScheme = 'vlc://${Uri.encodeComponent(url)}';
      final vlcUri = Uri.parse(vlcScheme);
      launched = await launchUrl(vlcUri, mode: LaunchMode.externalApplication);
      if (launched) {
        return;
      }
    } catch (e) {
      print('VLC URL scheme failed: $e');
    }

    try {
      final videoUri = Uri.parse(url);
      launched = await launchUrl(
        videoUri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) {
        return;
      }
    } catch (e) {
      print('Direct URL launch failed: $e');
    }

    if (!launched) {
      throw 'Could not open VLC. Ensure VLC is installed from Play Store.';
    }
  }

  static Future<void> _openVLCOnIOS(String url) async {
    try {
      final vlcUri = Uri.parse(
        'vlc-x-callback://x-callback-url/stream?url=${Uri.encodeComponent(url)}',
      );

      if (await canLaunchUrl(vlcUri)) {
        await launchUrl(vlcUri, mode: LaunchMode.externalApplication);
      } else {
        throw 'VLC not installed. Please install VLC from App Store.';
      }
    } catch (e) {
      throw 'Error: VLC app not found';
    }
  }
}
