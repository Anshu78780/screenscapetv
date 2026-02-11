import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import '../../models/movie.dart';
import '../../libs/baseurl.dart';
import 'headers.dart';

Future<List<Movie>> khdHubGetPosts(String filter, int page) async {
  try {
    print('Attempting to get base URL for 4kHDHub...');
    final baseUrl = await BaseUrl.getProviderUrl('4kHDHub');
    print('Base URL result: $baseUrl');

    if (baseUrl == null || baseUrl.isEmpty) {
      print('No base URL found for 4kHDHub');
      return [];
    }

    // Clean base URL
    String cleanBaseUrl = baseUrl;
    if (cleanBaseUrl.endsWith('/')) {
      cleanBaseUrl = cleanBaseUrl.substring(0, cleanBaseUrl.length - 1);
    }

    // Build URL with pagination
    final url = page > 1
        ? '$cleanBaseUrl$filter?page=$page'
        : '$cleanBaseUrl$filter';

    print('khdHubGetPosts url: $url');

    return _fetchPosts(url, cleanBaseUrl);
  } catch (e) {
    print('khdHub error: $e');
    return [];
  }
}

Future<List<Movie>> khdHubGetPostsSearch(String searchQuery, int page) async {
  try {
    print('Attempting to get base URL for 4kHDHub...');
    final baseUrl = await BaseUrl.getProviderUrl('4kHDHub');
    print('Base URL result: $baseUrl');

    if (baseUrl == null || baseUrl.isEmpty) {
      print('No base URL found for 4kHDHub');
      return [];
    }

    // Clean base URL
    String cleanBaseUrl = baseUrl;
    if (cleanBaseUrl.endsWith('/')) {
      cleanBaseUrl = cleanBaseUrl.substring(0, cleanBaseUrl.length - 1);
    }

    final url = page > 1
        ? '$cleanBaseUrl/?s=${Uri.encodeComponent(searchQuery)}&page=$page'
        : '$cleanBaseUrl/?s=${Uri.encodeComponent(searchQuery)}';

    print('khdHubGetPostsSearch url: $url');

    return _fetchPosts(url, cleanBaseUrl);
  } catch (e) {
    print('khdHub search error: $e');
    return [];
  }
}

Future<List<Movie>> _fetchPosts(String url, String baseUrl) async {
  try {
    final response = await http.get(
      Uri.parse(url),
      headers: khdHubHeaders,
    );

    if (response.statusCode != 200) {
      print('HTTP error ${response.statusCode} when fetching $url');
      return [];
    }

    final document = html_parser.parse(response.body);
    final List<Movie> movies = [];

    // Extract movie cards from the card-grid container
    final cards = document.querySelectorAll('.card-grid .movie-card');

    for (var card in cards) {
      try {
        // Extract link (href attribute)
        final link = card.attributes['href'] ?? '';

        // Extract title from movie-card-title
        final title = card.querySelector('.movie-card-title')?.text.trim() ?? '';

        // Extract image from img tag
        final imageElement = card.querySelector('.movie-card-image img');
        final image = imageElement?.attributes['src'] ?? '';

        // Extract formats/quality from movie-card-formats
        final formatElements = card.querySelectorAll('.movie-card-format');
        final formats = formatElements.map((el) => el.text.trim()).toList();

        if (title.isNotEmpty && link.isNotEmpty) {
          final fullLink = link.startsWith('http') ? link : baseUrl + link;
          final fullImage = image.startsWith('http')
              ? image
              : image.isNotEmpty
                  ? baseUrl + image
                  : '';

          // Extract quality (looking for resolution like 1080p, 2160p, etc.)
          final quality = formats.firstWhere(
            (f) => f.contains('p'),
            orElse: () => '',
          );

          movies.add(Movie(
            title: title,
            imageUrl: fullImage,
            quality: quality,
            link: fullLink,
          ));
        }
      } catch (e) {
        print('Error parsing card: $e');
      }
    }

    print('Found ${movies.length} posts from khdhub');
    return movies;
  } catch (error) {
    print('khdhub posts fetch error: $error');
    return [];
  }
}
