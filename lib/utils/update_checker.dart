import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class UpdateChecker {
  static const String _githubApiUrl = 
      'https://api.github.com/repos/Anshu78780/screenscapetv/releases/latest';

  /// Check if an update is available
  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // Fetch latest release from GitHub
      final response = await http.get(
        Uri.parse(_githubApiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = (data['tag_name'] as String).replaceAll('v', '');
        final downloadUrl = data['html_url'] as String;
        final releaseNotes = data['body'] as String? ?? '';
        final releaseName = data['name'] as String? ?? 'New Update';

        // Compare versions
        if (_isNewerVersion(currentVersion, latestVersion)) {
          return UpdateInfo(
            currentVersion: currentVersion,
            latestVersion: latestVersion,
            downloadUrl: downloadUrl,
            releaseNotes: releaseNotes,
            releaseName: releaseName,
          );
        }
      }

      return null; // No update available
    } catch (e) {
      print('Error checking for updates: $e');
      return null; // Return null on error to not block app
    }
  }

  /// Compare two semantic versions
  /// Returns true if newVersion is greater than currentVersion
  static bool _isNewerVersion(String current, String latest) {
    try {
      final currentParts = current.split('.').map(int.parse).toList();
      final latestParts = latest.split('.').map(int.parse).toList();

      // Ensure both have 3 parts (major.minor.patch)
      while (currentParts.length < 3) {
        currentParts.add(0);
      }
      while (latestParts.length < 3) {
        latestParts.add(0);
      }

      // Compare major version
      if (latestParts[0] > currentParts[0]) return true;
      if (latestParts[0] < currentParts[0]) return false;

      // Compare minor version
      if (latestParts[1] > currentParts[1]) return true;
      if (latestParts[1] < currentParts[1]) return false;

      // Compare patch version
      if (latestParts[2] > currentParts[2]) return true;

      return false;
    } catch (e) {
      print('Error comparing versions: $e');
      return false;
    }
  }
}

/// Model for update information
class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String downloadUrl;
  final String releaseNotes;
  final String releaseName;

  UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.releaseName,
  });

  String get versionDifference => 'v$currentVersion → v$latestVersion';
}
