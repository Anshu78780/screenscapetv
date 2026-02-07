import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../../models/movie.dart';
import '../../libs/baseurl.dart';
import 'headers.dart';

class HdhubGetPost {
  /// Fetch and parse movies from a given category URL with pagination
  static Future<List<Movie>> fetchMovies(String url, {int page = 1}) async {
    try {
      final paginatedUrl = '${url}page/$page/';
      print('hdhubGetPosts: $paginatedUrl');
      return await _parsePosts(paginatedUrl);
    } catch (e) {
      throw Exception('Error fetching movies: $e');
    }
  }

  /// Search movies using the search query with pagination
  static Future<List<Movie>> searchMovies(String query, {int page = 1}) async {
    try {
      final baseUrl = await BaseUrl.getProviderUrl('hdhub');
      if (baseUrl == null || baseUrl.isEmpty) {
        throw Exception('Failed to load hdhub URL from providers');
      }
      
      // Use the Pingora search API
      final searchUrl = 'https://search.pingora.fyi/collections/post/documents/search?q=$query&query_by=post_title';
      print('hdhubGetPostsSearch: $searchUrl');
      
      // Create custom headers with base URL as referer and origin
      final searchHeaders = Map<String, String>.from(HdhubHeaders.headers);
      searchHeaders['Referer'] = baseUrl;
      searchHeaders['Origin'] = baseUrl;
      
      final response = await http.get(
        Uri.parse(searchUrl),
        headers: searchHeaders,
      );

      if (response.statusCode != 200) {
        print('hdhub search error: HTTP ${response.statusCode}');
        return [];
      }

      // Parse JSON response
      final data = json.decode(response.body);
      final catalog = <Movie>[];
      
      // Clean base URL (remove trailing slash)
      final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
      
      // Extract hits array
      if (data['hits'] != null && data['hits'] is List) {
        for (var hit in data['hits']) {
          try {
            final doc = hit['document'];
            if (doc != null) {
              final title = doc['post_title']?.toString() ?? '';
              final permalink = doc['permalink']?.toString() ?? '';
              final thumbnail = doc['post_thumbnail']?.toString() ?? '';
              
              if (title.isNotEmpty && permalink.isNotEmpty) {
                // Construct full link by prepending base URL to permalink
                final fullLink = '$cleanBase$permalink';
                
                catalog.add(Movie(
                  title: title.replaceAll('Download', '').trim(),
                  imageUrl: thumbnail,
                  quality: '', // Quality not available in search results
                  link: fullLink,
                ));
              }
            }
          } catch (e) {
            print('Error parsing search result: $e');
            continue;
          }
        }
      }
      
      print('hdhub search found ${catalog.length} results');
      return catalog;
    } catch (e) {
      print('Error searching movies: $e');
      throw Exception('Error searching movies: $e');
    }
  }

  /// Parse posts from HTML content
  static Future<List<Movie>> _parsePosts(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: HdhubHeaders.headers,
      );

      if (response.statusCode != 200) {
        print('hdhub error: HTTP ${response.statusCode}');
        return [];
      }

      final document = html_parser.parse(response.body);
      final catalog = <Movie>[];

      // Find all posts in .recent-movies container
      final recentMovies = document.querySelectorAll('.recent-movies');
      
      for (var container in recentMovies) {
        final children = container.children;
        
        for (var element in children) {
          try {
            // Extract title from figure > img alt attribute
            final titleElement = element.querySelector('figure img');
            final title = titleElement?.attributes['alt']?.trim() ?? '';
            
            // Extract link from anchor tag
            final linkElement = element.querySelector('a');
            final link = linkElement?.attributes['href']?.trim() ?? '';
            
            // Extract image from figure > img src attribute
            final imageElement = element.querySelector('figure img');
            final image = imageElement?.attributes['src']?.trim() ?? '';

            if (title.isNotEmpty && link.isNotEmpty && image.isNotEmpty) {
              // Remove "Download" prefix from title if present
              final cleanTitle = title.replaceAll('Download', '').trim();
              
              catalog.add(Movie(
                title: cleanTitle,
                imageUrl: image,
                quality: '', // Quality not available in catalog view for hdhub
                link: link,
              ));
            }
          } catch (e) {
            print('Error parsing movie element: $e');
            continue;
          }
        }
      }

      print('hdhub parsed ${catalog.length} movies');
      return catalog;
    } catch (err) {
      print('hdhub error: $err');
      return [];
    }
  }
}
