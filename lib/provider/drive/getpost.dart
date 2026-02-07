import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'dart:convert';
import '../../models/movie.dart';
import '../../libs/baseurl.dart';

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

  /// Search movies using the search API
  static Future<List<Movie>> searchMovies(String query) async {
    try {
      final url = 'https://new1.moviesdrive.surf/searchapi.php?q=$query&page=1';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        return await _parseMoviesFromJson(response.body);
      } else {
        throw Exception('Failed to search movies: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error searching movies: $e');
    }
  }

  static Future<List<Movie>> _parseMoviesFromJson(String jsonContent) async {
    final List<Movie> movies = [];
    try {
      final data = json.decode(jsonContent);
      if (data['hits'] is List) {
        final baseUrl = await BaseUrl.getDriveUrl();
        // Remove trailing slash from base url if present to avoid double slashes
        final cleanBaseUrl = baseUrl.endsWith('/') 
            ? baseUrl.substring(0, baseUrl.length - 1) 
            : baseUrl;

        for (var hit in data['hits']) {
          try {
            final doc = hit['document'];
            if (doc != null) {
              final title = doc['post_title']?.toString() ?? '';
              final thumbnail = doc['post_thumbnail']?.toString() ?? '';
              final permalink = doc['permalink']?.toString() ?? '';
              
              // Handle quality from category tags if needed, or leave empty
              String quality = '';
              if (doc['category'] is List) {
                final categories = List<String>.from(doc['category']);
                 // Try to find quality-like tags
                 for (var cat in categories) {
                   if (cat.contains('4K') || cat.contains('1080p') || cat.contains('720p')) {
                     quality = cat;
                     break;
                   }
                 }
              }

              if (title.isNotEmpty && permalink.isNotEmpty) {
                 final fullLink = permalink.startsWith('http') 
                    ? permalink 
                    : '$cleanBaseUrl$permalink';

                 movies.add(Movie(
                   title: title,
                   imageUrl: thumbnail,
                   quality: quality,
                   link: fullLink,
                 ));
              }
            }
          } catch (e) {
            print('Error parsing search hit: $e');
          }
        }
      }
    } catch (e) {
      print('Error parsing search JSON: $e');
    }
    return movies;
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
