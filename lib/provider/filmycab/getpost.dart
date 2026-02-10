import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../../models/movie.dart';
import 'headers.dart';
import 'catalog.dart';

class FilmyCabGetPost {
  /// Fetch and parse movies from a given category URL with pagination
  static Future<List<Movie>> fetchMovies(String filter, {int page = 1}) async {
    try {
      final baseUrl = await FilmyCabCatalog.baseUrl;
      final cleanBase = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;

      // Remove leading slash from filter if it exists and construct proper URL
      final cleanFilter = filter.startsWith('/') ? filter.substring(1) : filter;
      final url = page == 1
          ? '$cleanBase/$cleanFilter'
          : '$cleanBase/$cleanFilter/page/$page';

      print('FilmyCab URL: $url');
      return await _fetchPosts(url, cleanBase);
    } catch (e) {
      print('FilmyCab fetchMovies error: $e');
      throw Exception('Error fetching movies: $e');
    }
  }

  /// Search movies using the search query
  static Future<List<Movie>> searchMovies(String query, {int page = 1}) async {
    try {
      final baseUrl = await FilmyCabCatalog.baseUrl;
      final cleanBase = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;

      final url =
          '$cleanBase/site-search.html?to-search=${Uri.encodeComponent(query)}';
      print('FilmyCab Search URL: $url');

      return await _fetchPosts(url, cleanBase);
    } catch (e) {
      print('FilmyCab searchMovies error: $e');
      throw Exception('Error searching movies: $e');
    }
  }

  /// Internal method to fetch and parse posts
  static Future<List<Movie>> _fetchPosts(String url, String baseUrl) async {
    try {
      print('FilmyCab fetching: $url');
      final response = await http.get(
        Uri.parse(url),
        headers: FilmyCabHeaders.headers,
      );

      if (response.statusCode != 200) {
        print(
          'FilmyCab fetch failed: ${response.statusCode} ${response.reasonPhrase}',
        );
        return [];
      }

      final document = html_parser.parse(response.body);
      final catalog = <Movie>[];

      // Parse the home-wrapper thumbnail-wrapper structure
      final thumbElements = document.querySelectorAll('.home-wrapper .thumb');

      for (var element in thumbElements) {
        try {
          // Get title from figcaption p (inside the anchor)
          final title =
              element.querySelector('figcaption p')?.text.trim() ?? '';

          // Get link from the figure anchor
          final link =
              element.querySelector('figure a')?.attributes['href'] ?? '';

          // Get image from the figure img
          final image =
              element.querySelector('figure img')?.attributes['src'] ?? '';

          // Get quality and language info
          final quality = element.querySelector('.quality')?.text.trim() ?? '';
          final language = element.querySelector('.lang')?.text.trim() ?? '';

          print(
            'FilmyCab parsed: title=$title, link=$link, image=$image, quality=$quality, language=$language',
          );

          // Only add if we have all required fields
          if (title.isNotEmpty && link.isNotEmpty && image.isNotEmpty) {
            // Ensure full URLs
            final fullLink = link.startsWith('http') ? link : '$baseUrl$link';
            final fullImage = image.startsWith('http')
                ? image
                : '$baseUrl$image';

            catalog.add(
              Movie(
                title: title,
                link: fullLink,
                imageUrl: fullImage,
                quality: quality.isNotEmpty ? quality : 'N/A',
              ),
            );
          }
        } catch (e) {
          print('FilmyCab error parsing element: $e');
          continue;
        }
      }

      print('FilmyCab catalog length: ${catalog.length}');
      return catalog;
    } catch (e) {
      print('FilmyCab error: $e');
      return [];
    }
  }
}
