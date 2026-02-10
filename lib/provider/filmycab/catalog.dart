import '../../libs/baseurl.dart';

class FilmyCabCatalog {
  static String? _baseUrl;

  static const List<Map<String, String>> categories = [
    {'name': 'Home', 'path': '/'},
    {'name': 'Bollywood Movies', 'path': '/page-cat/1/Bollywood-Movies.html'},
    {'name': 'Punjabi Movies', 'path': '/page-cat/3/Punjabi-Movies.html'},
    {'name': 'Animation Movies', 'path': '/page-cat/6/Animation-Movies.html'},
  ];

  static Future<String> get baseUrl async {
    if (_baseUrl != null) return _baseUrl!;

    final url = await BaseUrl.getProviderUrl('filmyclub');
    if (url == null) {
      throw Exception('FilmyCab provider URL not found');
    }

    _baseUrl = url;
    return _baseUrl!;
  }

  static void clearCache() {
    _baseUrl = null;
  }
}
