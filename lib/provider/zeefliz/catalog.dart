import '../../libs/baseurl.dart';

class ZeeflizCatalog {
  static String? _baseUrl;

  static const List<Map<String, String>> categories = [
    {'name': 'Latest', 'path': ''},
    {'name': 'Action', 'path': '/category/action/'},
    {'name': 'Animation', 'path': '/category/animation/'},
    {'name': 'Web Series', 'path': '/category/web-series/'},
  ];

  static Future<String> get baseUrl async {
    if (_baseUrl != null) return _baseUrl!;

    final url = await BaseUrl.getProviderUrl('zeefliz');
    if (url == null) {
      throw Exception('Zeefliz provider URL not found');
    }

    _baseUrl = url;
    return _baseUrl!;
  }

  static void clearCache() {
    _baseUrl = null;
  }
}
