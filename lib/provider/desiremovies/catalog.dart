import '../../libs/baseurl.dart';

class DesireMoviesCatalog {
  static String? _baseUrl;

  static const List<Map<String, String>> categories = [
    {
      'name': 'Latest',
      'path': '',
    },
    {
      'name': 'South Movies',
      'path': 'south-movieshindi/',
    },
    {
      'name': 'Bollywood',
      'path': 'bollywood-movies-desiremovie/',
    },
    {
      'name': 'Hollywood Hindi',
      'path': 'hollywood-movies-download-hindi/',
    },
    {
      'name': 'Korean Hindi',
      'path': 'korean-movie-hindi/',
    },
    {
      'name': 'Web Series',
      'path': 'web-series/',
    },
  ];

  static Future<String> get baseUrl async {
    if (_baseUrl != null) return _baseUrl!;
    final url = await BaseUrl.getProviderUrl('DesiReMovies');
    if (url == null || url.isEmpty) {
      throw Exception('Failed to load desiremovies URL from providers');
    }
    _baseUrl = url;
    return _baseUrl!;
  }
  
  static Future<String> getCategoryUrl(String path) async {
    final base = await baseUrl;
    final cleanBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    
    // Ensure path ends with slash if not empty, as per TS code structure usually
    // TS code: `${baseUrl}${filter}${page > 1 ? `page/${page}/` : ''}`
    // Filter in TS starts with / usually (except Latest which is empty)
    
    // Using simple concatenation compatible with previous providers
    if (cleanPath.isEmpty) return cleanBase;
    return '$cleanBase/$cleanPath';
  }

  static void clearCache() {
    _baseUrl = null;
    BaseUrl.clearCache();
  }
}
