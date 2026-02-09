import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../../models/movie.dart';
import 'headers.dart';
import 'catalog.dart';

class DesireMoviesGetPost {
  /// Fetch and parse movies from a given category URL with pagination
  static Future<List<Movie>> fetchMovies(String url, {int page = 1}) async {
    try {
      final baseUrl = await DesireMoviesCatalog.baseUrl;
      final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
      
      // Reconstruct URL for pagination if needed
      // TS: `${baseUrl}${filter}${page > 1 ? `page/${page}/` : ''}`
      // The passed 'url' here is likely already 'baseUrl/filter'
      
      String finalUrl = url;
      if (page > 1) {
        if (finalUrl.endsWith('/')) {
          finalUrl = '${finalUrl}page/$page/';
        } else {
          finalUrl = '$finalUrl/page/$page/';
        }
      }
      
      print('dmGetPosts url: $finalUrl');
      return await _fetchPosts(finalUrl, cleanBase);
    } catch (e) {
      print('DesiReMovies fetchMovies error: $e');
      throw Exception('Error fetching movies: $e');
    }
  }

  /// Search movies using the search query
  static Future<List<Movie>> searchMovies(String query, {int page = 1}) async {
    try {
      final baseUrl = await DesireMoviesCatalog.baseUrl;
      final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;

      // TS Logic:
      // const url = page > 1 
      //   ? `${baseUrl}/?s=${encodeURIComponent(searchQuery)}`
      //   : `${baseUrl}?s=${encodeURIComponent(searchQuery)}`;
      
      // Note: The TS logic seems to ignore pagination for search. 
      // We will follow it but append typical WP pagination if we wanted to fix it.
      // For now, strict conversion of logic.
      final url = page > 1
          ? '$cleanBase/?s=${Uri.encodeComponent(query)}'
          : '$cleanBase?s=${Uri.encodeComponent(query)}';

      print('dmGetPostsSearch url: $url');

      return await _fetchPosts(url, cleanBase, useSearchCookie: true);
    } catch (e) {
      print('DesiReMovies searchMovies error: $e');
      throw Exception('Error searching movies: $e');
    }
  }

  static Future<List<Movie>> _fetchPosts(String url, String baseUrl, {bool useSearchCookie = false}) async {
    try {
      final headers = Map<String, String>.from(DesireMoviesHeaders.headers);
      headers['Referer'] = baseUrl;
      
      if (useSearchCookie) {
        headers['Cookie'] = DesireMoviesHeaders.searchCookie;
      }

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode != 200) {
        print('DesiReMovies error: HTTP ${response.statusCode}');
        return [];
      }

      final document = html_parser.parse(response.body);
      final posts = <Movie>[];

      /*
        $('article.mh-loop-item').each((index, element) => {
          const post = {
            title: $(element).find('.entry-title a').text().trim(),
            link: $(element).find('.entry-title a').attr('href') || '',
            image: $(element).find('.mh-loop-thumb img').attr('src') || '',
          };
          if (post.title && post.link) { ... }
        });
      */

      final elements = document.querySelectorAll('article.mh-loop-item');
      for (var element in elements) {
        final titleElem = element.querySelector('.entry-title a');
        final title = titleElem?.text.trim() ?? '';
        final link = titleElem?.attributes['href'] ?? '';
        
        final imgElem = element.querySelector('.mh-loop-thumb img');
        final image = imgElem?.attributes['src'] ?? '';

        if (title.isNotEmpty && link.isNotEmpty) {
           posts.add(Movie(
             title: title,
             imageUrl: image,
             link: link,
             quality: '', 
           ));
        }
      }

      print('Found ${posts.length} posts from DesiReMovies');
      return posts;
    } catch (e) {
      print('DesiReMovies binding error: $e');
      return [];
    }
  }
}
