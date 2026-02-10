import 'dart:io';
import 'package:installed_apps/installed_apps.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VlcChecker {
  static const String _vlcPackageName = 'org.videolan.vlc';
  static const String _vlcInstalledKey = 'vlcinstalled';

  static Future<bool> isVlcInstalled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isCached = prefs.getBool(_vlcInstalledKey) ?? false;

      if (isCached) {
        return true;
      }

      bool installed = false;

      if (Platform.isAndroid) {
        bool? isAppInstalled = await InstalledApps.isAppInstalled(_vlcPackageName);
        installed = isAppInstalled ?? false;
      } else if (Platform.isLinux) {
        installed = await _isVlcInstalledLinux();
      } else {
        // Assume true for other platforms or not applicable
        return true;
      }

      if (installed) {
        await prefs.setBool(_vlcInstalledKey, true);
      }

      return installed;
    } catch (e) {
      print('Error checking VLC: $e');
      return false;
    }
  }

  static Future<bool> _isVlcInstalledLinux() async {
    try {
      final result = await Process.run(
        'which',
        ['vlc'],
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markAsInstalled() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_vlcInstalledKey, true);
  }
}
