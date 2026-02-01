import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../../models/movie.dart';

class GetPost {
  /// Fetch and parse movies from a given URL
  static Future<List<Movie>> fetchMovies(String url) async {
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        return parseMoviesFromHtml(response.body);
      } else {
        throw Exception('Failed to load movies: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching movies: $e');
    }
  }

  /// Parse movies from HTML content
  static List<Movie> parseMoviesFromHtml(String htmlContent) {
    final List<Movie> movies = [];
    
    try {
      final document = html_parser.parse(htmlContent);
      
      // Find all movie cards in the grid
      final movieCards = document.querySelectorAll('.movies-grid a');

      for (var card in movieCards) {
        try {
          // Extract link
          final link = card.attributes['href'] ?? '';

          // Extract image
          final imgElement = card.querySelector('.poster-image img');
          final imageUrl = imgElement?.attributes['src'] ?? '';
          
          // Extract title
          final titleElement = card.querySelector('.poster-title');
          final title = titleElement?.text.trim() ?? '';

          // Extract quality
          final qualityElement = card.querySelector('.poster-quality');
          final quality = qualityElement?.text.trim() ?? '';

          // Only add if we have essential data
          if (link.isNotEmpty && title.isNotEmpty) {
            movies.add(Movie(
              title: title,
              imageUrl: imageUrl,
              quality: quality,
              link: link,
            ));
          }
        } catch (e) {
          print('Error parsing movie card: $e');
          continue;
        }
      }
    } catch (e) {
      print('Error parsing HTML: $e');
    }

    return movies;
  }

  /// Fetch movies from a specific category
  static Future<List<Movie>> fetchCategoryMovies(String categoryUrl) async {
    return await fetchMovies(categoryUrl);
  }
}
