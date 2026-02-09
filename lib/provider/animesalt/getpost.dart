import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import '../../models/movie.dart';
import '../../libs/baseurl.dart';
import 'headers.dart';

Future<List<Movie>> animesaltGetPosts(String filter, int page) async {
  try {
    // Get base URL dynamically
    final baseUrl = await BaseUrl.getProviderUrl('animesalt');
    if (baseUrl == null || baseUrl.isEmpty) {
      print('AnimeSalt: Failed to get base URL');
      return [];
    }

    // Clean base URL to avoid double slashes
    String cleanBaseUrl = baseUrl;
    if (cleanBaseUrl.endsWith('/')) {
      cleanBaseUrl = cleanBaseUrl.substring(0, cleanBaseUrl.length - 1);
    }

    // Handle undefined filter by using default path
    final pathFilter = filter.isEmpty ? '/' : filter;
    
    // Construct URL
    final pageParam = page > 1 ? '/page/$page/' : '';
    final url = '$cleanBaseUrl$pathFilter$pageParam';
    
    print('AnimeSalt URL: $url');

    return await _fetchPosts(url);
  } catch (e) {
    print('AnimeSalt error: $e');
    return [];
  }
}

Future<List<Movie>> animesaltGetPostsSearch(String searchQuery, int page) async {
  try {
    // Get base URL dynamically
    final baseUrl = await BaseUrl.getProviderUrl('animesalt');
    if (baseUrl == null || baseUrl.isEmpty) {
      print('AnimeSalt: Failed to get base URL for search');
      return [];
    }

    // Clean base URL to avoid double slashes
    String cleanBaseUrl = baseUrl;
    if (cleanBaseUrl.endsWith('/')) {
      cleanBaseUrl = cleanBaseUrl.substring(0, cleanBaseUrl.length - 1);
    }

    // Using standard WordPress search URL format
    final url = '$cleanBaseUrl/?s=${Uri.encodeComponent(searchQuery)}';
    
    print('AnimeSalt search URL: $url');

    return await _fetchPosts(url);
  } catch (e) {
    print('AnimeSalt search error: $e');
    return [];
  }
}

Future<List<Movie>> _fetchPosts(String url) async {
  try {
    final response = await http.get(
      Uri.parse(url),
      headers: animeSaltHeaders,
    );

    if (response.statusCode != 200) {
      print('AnimeSalt: Failed to fetch posts, status: ${response.statusCode}');
      return [];
    }

    final document = html_parser.parse(response.body);
    final posts = <Movie>[];

    // Based on WordPress article structure
    final articles = document.querySelectorAll('article[class^="post"]');
    
    for (var article in articles) {
      try {
        // Extract link from article
        final linkElement = article.querySelector('a');
        final link = linkElement?.attributes['href'];

        // Extract image - check data-src first (for lazy loading), then src
        final imgElement = article.querySelector('img');
        String? image = imgElement?.attributes['data-src'] ?? 
                       imgElement?.attributes['src'];

        // Fix protocol-relative URLs by adding https: prefix
        if (image != null && image.startsWith('//')) {
          image = 'https:$image';
        }

        // Extract title from title element first, then fallback to alt
        var title = article.querySelector('.entry-title, h2.entry-title, h3.entry-title')?.text.trim();

        if (title == null || title.isEmpty) {
          title = imgElement?.attributes['alt'] ?? '';
        }

        // Clean up "Image " prefix if present (common issue with alt text)
        title = title.replaceAll(RegExp(r'^Image\s+', caseSensitive: false), '');

        // Only add if we have both link and title
        if (title.isNotEmpty && link != null && link.isNotEmpty) {
          posts.add(Movie(
            title: title,
            link: link,
            imageUrl: image ?? '',
            quality: 'HD', // Default quality for anime
          ));
        }
      } catch (err) {
        print('Error processing anime post: $err');
      }
    }

    print('Found ${posts.length} posts from AnimeSalt');
    return posts;
  } catch (err) {
    print('AnimeSalt fetch error: $err');
    return [];
  }
}
