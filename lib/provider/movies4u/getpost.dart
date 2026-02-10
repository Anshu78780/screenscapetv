import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../../models/movie.dart';
import '../../libs/baseurl.dart';
import 'headers.dart';

class Movies4uGetPost {
  /// Fetch movies from a category URL
  static Future<List<Movie>> fetchMovies(String categoryUrl) async {
    try {
      print('Movies4u: Fetching $categoryUrl');
      final response = await http.get(
        Uri.parse(categoryUrl),
        headers: Movies4uHeaders.getHeaders(),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to load movies: ${response.statusCode}');
      }

      print('Movies4u: Response received, parsing HTML');
      final movies = _parseMoviesFromHtml(response.body);
      print('Movies4u: Found ${movies.length} movies');
      return movies;
    } catch (e) {
      print('Movies4u Error: $e');
      throw Exception('Error fetching movies: $e');
    }
  }

  /// Search movies by query
  static Future<List<Movie>> searchMovies(String query) async {
    try {
      final baseUrl = await _getBaseUrl();
      final searchUrl = '$baseUrl/?s=${Uri.encodeComponent(query)}';
      
      final response = await http.get(
        Uri.parse(searchUrl),
        headers: Movies4uHeaders.getHeaders(),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to search movies: ${response.statusCode}');
      }

      return _parseMoviesFromHtml(response.body);
    } catch (e) {
      throw Exception('Error searching movies: $e');
    }
  }

  /// Parse movies from HTML content
  static List<Movie> _parseMoviesFromHtml(String htmlContent) {
    final document = html_parser.parse(htmlContent);
    final List<Movie> movies = [];

    // Find all article elements with class "post"
    final articles = document.querySelectorAll('article.post');

    for (var article in articles) {
      try {
        // Extract link from <a> tag with class "post-thumbnail"
        final linkElement = article.querySelector('a.post-thumbnail');
        if (linkElement == null) continue;
        
        final link = linkElement.attributes['href'] ?? '';
        if (link.isEmpty) continue;

        // Extract image from <img> tag
        final imgElement = article.querySelector('img');
        final imageUrl = imgElement?.attributes['src'] ?? '';

        // Extract title from <h2> tag with class "entry-title"
        final titleElement = article.querySelector('h2.entry-title a');
        final title = titleElement?.text.trim() ?? 'Unknown Title';

        // Extract quality label if present
        final qualityElement = article.querySelector('.video-label');
        final quality = qualityElement?.text.trim() ?? '';

        movies.add(Movie(
          title: title,
          link: link,
          imageUrl: imageUrl.isNotEmpty ? imageUrl : 'https://via.placeholder.com/500x750?text=ScreenScape',
          quality: quality,
        ));
      } catch (e) {
        // Skip invalid entries
        continue;
      }
    }

    return movies;
  }

  /// Get base URL for Movies4u
  static Future<String> _getBaseUrl() async {
    final baseUrl = await BaseUrl.getProviderUrl('movies4u');
    if (baseUrl == null) {
      throw Exception('Movies4u base URL not configured');
    }
    return baseUrl;
  }
}
