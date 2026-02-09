import '../../libs/baseurl.dart';

class MoviesmodCatalog {
  static String? _baseUrl;

  static const List<Map<String, String>> categories = [
    {
      'name': 'Latest',
      'path': '',
    },
    {
      'name': 'Netflix',
      'path': '/ott/netflix',
    },
    {
      'name': 'HBO Max',
      'path': '/ott/hbo-max',
    },
    {
      'name': 'Amazon Prime',
      'path': '/ott/amazon-prime-video',
    },
  ];

  static Future<String> get baseUrl async {
    if (_baseUrl != null) return _baseUrl!;
    // Using 'Moviesmod' as key based on TS code: getBaseUrl('Moviesmod')
    final url = await BaseUrl.getProviderUrl('Moviesmod');
    if (url == null || url.isEmpty) {
      throw Exception('Failed to load Moviesmod URL from providers');
    }
    _baseUrl = url;
    return _baseUrl!;
  }
  
  static Future<String> getCategoryUrl(String path) async {
    final base = await baseUrl;
    final cleanBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    // path from catalog list starts with / for some, likely needs to be handled
    
    if (path.isEmpty) return cleanBase;
    
    // TS logic: `${baseUrl + filter}`
    // If path starts with /, just append.
    if (path.startsWith('/')) {
      return '$cleanBase$path';
    } 
    return '$cleanBase/$path';
  }

  static void clearCache() {
    _baseUrl = null;
    BaseUrl.clearCache();
  }
}
