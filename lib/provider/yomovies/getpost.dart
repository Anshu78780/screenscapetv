import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import '../../models/movie.dart';
import '../../libs/baseurl.dart';
import 'headers.dart';

Future<List<Movie>> yoMoviesGetPosts(String filter, int page) async {
  try {
    final baseUrl = await BaseUrl.getProviderUrl('yomovies');
    if (baseUrl == null || baseUrl.isEmpty) {
      print('YoMovies: Failed to get base URL');
      return [];
    }

    // Clean base URL
    String cleanBaseUrl = baseUrl;
    if (cleanBaseUrl.endsWith('/')) {
      cleanBaseUrl = cleanBaseUrl.substring(0, cleanBaseUrl.length - 1);
    }

    // Build URL with pagination
    String url = '$cleanBaseUrl$filter';
    if (page > 1) {
      url = '${url}page/$page/';
    }

    print('YoMovies URL: $url');

    final response = await http.get(
      Uri.parse(url),
      headers: yoMoviesHeaders,
    );

    if (response.statusCode != 200) {
      print('YoMovies: Failed to fetch posts, status: ${response.statusCode}');
      return [];
    }

    return _parsePosts(response.body, baseUrl);
  } catch (e) {
    print('YoMovies error: $e');
    return [];
  }
}

Future<List<Movie>> yoMoviesGetPostsSearch(String searchQuery, int page) async {
  try {
    final baseUrl = await BaseUrl.getProviderUrl('yomovies');
    if (baseUrl == null || baseUrl.isEmpty) {
      print('YoMovies: Failed to get base URL for search');
      return [];
    }

    // Clean base URL
    String cleanBaseUrl = baseUrl;
    if (cleanBaseUrl.endsWith('/')) {
      cleanBaseUrl = cleanBaseUrl.substring(0, cleanBaseUrl.length - 1);
    }

    final url = '$cleanBaseUrl/page/$page/?s=${Uri.encodeComponent(searchQuery)}';

    print('YoMovies search URL: $url');

    final response = await http.get(
      Uri.parse(url),
      headers: yoMoviesHeaders,
    );

    if (response.statusCode != 200) {
      print('YoMovies: Failed to search, status: ${response.statusCode}');
      return [];
    }

    return _parsePosts(response.body, baseUrl);
  } catch (e) {
    print('YoMovies search error: $e');
    return [];
  }
}

List<Movie> _parsePosts(String html, String baseUrl) {
  final document = html_parser.parse(html);
  final List<Movie> movies = [];

  // Target the movie items - .ml-item class
  final items = document.querySelectorAll('.ml-item');

  for (var item in items) {
    try {
      final linkElement = item.querySelector('a');
      final link = linkElement?.attributes['href'] ?? '';
      
      // Try oldtitle first, then title attribute
      String title = linkElement?.attributes['oldtitle'] ?? 
                     linkElement?.attributes['title'] ?? '';

      // Extract image - try data-original first, then src
      final imgElement = item.querySelector('img');
      String image = imgElement?.attributes['data-original'] ?? 
                     imgElement?.attributes['src'] ?? '';

      if (title.isNotEmpty && link.isNotEmpty) {
        movies.add(Movie(
          title: title.trim(),
          imageUrl: image,
          quality: '', // YoMovies doesn't provide quality in listing
          link: link,
        ));
      }
    } catch (e) {
      print('YoMovies: Error parsing item: $e');
    }
  }

  return movies;
}
