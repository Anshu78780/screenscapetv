import '../../libs/baseurl.dart';

class XdmoviesCatalog {
  static String? _baseUrl;

  static const List<Map<String, String>> categories = [
    {'name': 'Latest', 'path': ''},
  ];

  static Future<String> get baseUrl async {
    if (_baseUrl != null) return _baseUrl!;
    final url = await BaseUrl.getProviderUrl('xdmovies');
    if (url == null || url.isEmpty) {
      throw Exception('Failed to load xdmovies URL from providers');
    }
    _baseUrl = url;
    return _baseUrl!;
  }
  
  static Future<String> getCategoryUrl(String path) async {
    final base = await baseUrl;
    final cleanBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    if (cleanPath.isEmpty) return cleanBase;
    return '$cleanBase/$cleanPath';
  }

  static void clearCache() {
    _baseUrl = null;
    BaseUrl.clearCache();
  }
}
