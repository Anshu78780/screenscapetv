import '../../libs/baseurl.dart';

class HdhubCatalog {
  static String? _baseUrl;
  
  // Category definitions (static)
  static const List<Map<String, String>> categories = [
    {'name': 'Bollywood Movies', 'path': 'category/bollywood-movies/'},
    {'name': 'Hollywood Movies', 'path': 'category/hollywood-movies/'},
    {'name': 'Web Series', 'path': 'category/web-series/'},
  ];

  /// Get base URL dynamically from providers.json
  static Future<String> get baseUrl async {
    if (_baseUrl != null) return _baseUrl!;
    final url = await BaseUrl.getProviderUrl('hdhub');
    if (url == null || url.isEmpty) {
      throw Exception('Failed to load hdhub URL from providers');
    }
    _baseUrl = url;
    return _baseUrl!;
  }
  
  /// Build full URL for a category path
  static Future<String> getCategoryUrl(String path) async {
    final base = await baseUrl;
    // Remove trailing slash from base if exists, ensure path doesn't start with slash
    final cleanBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return '$cleanBase/$cleanPath';
  }

  /// Clear cached base URL
  static void clearCache() {
    _baseUrl = null;
    BaseUrl.clearCache();
  }
}
