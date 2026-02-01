import '../provider/providers.dart';

class BaseUrl {
  static String? _cachedDriveUrl;

  /// Get the drive URL dynamically from providers.json
  static Future<String> getDriveUrl() async {
    if (_cachedDriveUrl != null) {
      return _cachedDriveUrl!;
    }

    final driveProvider = await Providers.getDriveProvider();
    if (driveProvider != null && driveProvider.url.isNotEmpty) {
      _cachedDriveUrl = driveProvider.url;
      return driveProvider.url;
    }

    throw Exception('Failed to load drive URL from providers');
  }

  /// Clear cached URL (useful for refreshing)
  static void clearCache() {
    _cachedDriveUrl = null;
  }

  /// Get a provider URL by key
  static Future<String?> getProviderUrl(String key) async {
    try {
      final provider = await Providers.getProvider(key);
      return provider?.url;
    } catch (e) {
      print('Error loading provider URL: $e');
      return null;
    }
  }
}
