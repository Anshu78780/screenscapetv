import '../../libs/baseurl.dart';

class Movies4uCatalog {
  static final List<Map<String, String>> categories = [
    {'name': 'Home', 'path': ''},
    {'name': 'Action', 'path': '/category/action/'},
    {'name': 'Anime', 'path': '/category/anime/'},
    {'name': 'Hollywood', 'path': '/category/hollywood/'},
    {'name': 'TV Shows', 'path': '/category/tv-shows/'},
  ];

  static Future<String> getCategoryUrl(String path) async {
    final baseUrl = await BaseUrl.getProviderUrl('movies4u');
    if (baseUrl == null) {
      throw Exception('Movies4u base URL not configured');
    }
    return '$baseUrl$path';
  }
}
