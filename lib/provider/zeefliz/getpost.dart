import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../../models/movie.dart';
import 'headers.dart';
import 'catalog.dart';

class ZeeflizGetPost {
  /// Fetch and parse movies from a given category URL with pagination
  static Future<List<Movie>> fetchMovies(String filter, {int page = 1}) async {
    try {
      final baseUrl = await ZeeflizCatalog.baseUrl;
      final cleanBase = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;

      // Construct the URL based on filter and page
      String url = cleanBase;
      if (filter.isNotEmpty) {
        url = '$cleanBase$filter';
      }
      if (page > 1) {
        url = '${url}page/$page/';
      }

      print('Zeefliz URL: $url');
      return await _fetchPosts(url);
    } catch (e) {
      print('Zeefliz fetchMovies error: $e');
      throw Exception('Error fetching movies: $e');
    }
  }

  /// Search movies using the base URL search parameter
  static Future<List<Movie>> searchMovies(String query, {int page = 1}) async {
    try {
      final baseUrl = await ZeeflizCatalog.baseUrl;
      final cleanBase = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;

      // Use the WordPress search URL format: ?s=query
      String url = '$cleanBase/?s=${Uri.encodeComponent(query)}';
      if (page > 1) {
        url = '$url&page=$page';
      }

      print('Zeefliz Search URL: $url');
      return await _fetchPosts(url);
    } catch (e) {
      print('Zeefliz searchMovies error: $e');
      throw Exception('Error searching movies: $e');
    }
  }

  /// Internal method to fetch and parse posts from HTML
  static Future<List<Movie>> _fetchPosts(String url) async {
    try {
      print('Zeefliz fetching: $url');
      final response = await http.get(
        Uri.parse(url),
        headers: ZeeflizHeaders.headers,
      );

      if (response.statusCode != 200) {
        print(
          'Zeefliz fetch failed: ${response.statusCode} ${response.reasonPhrase}',
        );
        return [];
      }

      final document = html_parser.parse(response.body);
      final catalog = <Movie>[];

      // Parse articles based on the HTML structure: article.post
      final articles = document.querySelectorAll('article.post');

      for (var article in articles) {
        try {
          // Extract title from h3.entry-title a
          final titleElement = article.querySelector('h3.entry-title a');
          var title = titleElement?.text.trim() ?? '';
          final link = titleElement?.attributes['href'] ?? '';

          // Remove "Download" prefix from title if present
          title = title.replaceFirst(
            RegExp(r'^Download\s+', caseSensitive: false),
            '',
          );

          // Extract image from figure img (prioritize bv-data-src for lazy-loaded images)
          final imgElement = article.querySelector('figure img');
          final image =
              imgElement?.attributes['bv-data-src'] ??
              imgElement?.attributes['data-src'] ??
              imgElement?.attributes['src'] ??
              '';

          print('Zeefliz parsed: title=$title, link=$link, image=$image');

          // Only add if we have required fields
          if (title.isNotEmpty && link.isNotEmpty) {
            catalog.add(
              Movie(title: title, link: link, imageUrl: image, quality: 'N/A'),
            );
          }
        } catch (e) {
          print('Zeefliz error parsing article: $e');
          continue;
        }
      }

      print('Zeefliz catalog length: ${catalog.length}');
      return catalog;
    } catch (e) {
      print('Zeefliz error: $e');
      return [];
    }
  }
}
