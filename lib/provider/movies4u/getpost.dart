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
    final Set<String> processedLinks = {};

    // Combine selectors to find movie items (articles, figures, or standalone thumbnails)
    // We select the thumbnail container as the anchor point
    final thumbnailElements = document.querySelectorAll('.post-thumbnail');

    for (var element in thumbnailElements) {
      try {
        // Determine the link element
        // The element itself might be the <a> tag (class="post-thumbnail")
        // OR it might be a div containing the <a> tag
        final linkElement = element.localName == 'a' 
            ? element 
            : element.querySelector('a'); // Try finding <a> inside
            
        if (linkElement == null) continue;
        
        final link = linkElement.attributes['href'] ?? '';
        if (link.isEmpty || processedLinks.contains(link)) continue;
        processedLinks.add(link);

        // Extract image
        final imgElement = element.querySelector('img');
        String imageUrl = imgElement?.attributes['src'] ?? 
                          imgElement?.attributes['data-src'] ?? 
                          imgElement?.attributes['data-original'] ?? '';

        // Extract Title
        String title = '';
        
        // Strategy 1: Look for standard title elements in the parent container
        // Traverse up to find a container (article/figure/li)
        var container = element.parent;
        // Limit traversal to avoid going too far up
        int levelsToCheck = 3; 
        while (container != null && levelsToCheck > 0) {
           final titleEl = container.querySelector('.entry-title a, .post-title a, h2 a, h3 a');
           if (titleEl != null && titleEl.text.trim().isNotEmpty) {
             title = titleEl.text.trim();
             break;
           }
           // Stop if we hit a likely container boundary
           if (container.localName == 'article' || container.localName == 'figure' || container.classes.contains('post')) {
              break; 
           }
           container = container.parent;
           levelsToCheck--;
        }

        // Strategy 2: Use Image Alt text (Common in <figure> layouts)
        if (title.isEmpty) {
           title = imgElement?.attributes['alt']?.trim() ?? '';
        }
        
        // Strategy 3: Link title attribute
        if (title.isEmpty) {
           title = linkElement.attributes['title']?.trim() ?? '';
        }

        if (title.isEmpty) continue;

        // Extract quality label
        // Usually inside the thumbnail element
        final qualityElement = element.querySelector('.video-label');
        final quality = qualityElement?.text.trim() ?? '';

        movies.add(Movie(
          title: title,
          link: link,
          imageUrl: imageUrl.isNotEmpty ? imageUrl : 'https://via.placeholder.com/500x750?text=No+Image',
          quality: quality,
        ));
      } catch (e) {
        print('Error parsing movie item: $e');
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
