import '../../libs/baseurl.dart';

class DriveCatalog {
  static String? _baseUrl;
  
  // Category definitions (static)
  static const List<Map<String, String>> categories = [
    {'name': 'Latest', 'path': ''},
    {'name': 'Hollywood', 'path': '/category/hollywood/'},
    {'name': 'Web Series', 'path': '/category/web/'},
    {'name': 'Bollywood', 'path': '/category/bollywood/'},
  ];

  /// Get base URL dynamically
  static Future<String> get baseUrl async {
    if (_baseUrl != null) return _baseUrl!;
    _baseUrl = await BaseUrl.getDriveUrl();
    return _baseUrl!;
  }
  
  /// Build full URL for a category path
  static Future<String> getCategoryUrl(String path) async {
    final base = await baseUrl;
    return '$base$path';
  }

  /// Clear cached base URL
  static void clearCache() {
    _baseUrl = null;
    BaseUrl.clearCache();
  }
}
