import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../../models/movie.dart';
import '../../libs/baseurl.dart';
import 'headers.dart';
import 'catalog.dart';

class XdmoviesGetPost {
  /// Fetch and parse movies from a given category URL with pagination
  static Future<List<Movie>> fetchMovies(String url, {int page = 1}) async {
    try {
      // Logic from: const url = `${baseUrl}${page > 1 ? `?page=${page}` : ''}`;
      // Note: url passed here usually comes from XdmoviesCatalog.getCategoryUrl which is just baseUrl
      
      final String finalUrl = page > 1 
          ? '$url?page=$page' 
          : url;

      print('xdmoviesGetPosts: $finalUrl');
      return await _parsePosts(finalUrl);
    } catch (e) {
      throw Exception('Error fetching movies: $e');
    }
  }

  /// Search movies using the search query
  static Future<List<Movie>> searchMovies(String query, {int page = 1}) async {
    try {
      final baseUrl = await XdmoviesCatalog.baseUrl;
      final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;

      // Logic from: `${baseUrl}/php/search_api.php?query=${encodeURIComponent(searchQuery)}&fuzzy=true&limit=50`
      final apiUrl = '$cleanBase/php/search_api.php?query=${Uri.encodeComponent(query)}&fuzzy=true&limit=50';
      
      final searchHeaders = Map<String, String>.from(XdmoviesHeaders.headers);
      searchHeaders['Referer'] = '$cleanBase/search.html?q=${Uri.encodeComponent(query)}';
      
      print('xdmoviesSearch: $apiUrl');

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: searchHeaders,
      );

      if (response.statusCode != 200) {
        print('xdmovies search error: HTTP ${response.statusCode}');
        return [];
      }

      final text = response.body;
      dynamic data;
      try {
        data = json.decode(text);
      } catch (e) {
        print('xdmovies search: Failed to parse JSON response: $e');
        return [];
      }

      final posts = <Movie>[];

      /*
        data.forEach((item: any) => {
          const title = item.title;
          const path = item.path;
          const poster = item.poster;

          if (title && path) {
            const image = poster 
              ? `https://image.tmdb.org/t/p/w500${poster}` 
              : '';
            const link = baseUrl + path;
            posts.push({ title, link, image });
          }
        });
      */

      if (data is List) {
        for (var item in data) {
          final title = item['title']?.toString();
          final path = item['path']?.toString();
          final poster = item['poster']?.toString();

          if (title != null && path != null && title.isNotEmpty && path.isNotEmpty) {
             final image = (poster != null && poster.isNotEmpty)
                ? 'https://image.tmdb.org/t/p/w500$poster'
                : '';
             
             final fullLink = path.startsWith('http') ? path : '$cleanBase$path';

             posts.add(Movie(
               title: title,
               imageUrl: image,
               link: fullLink,
               quality: '',
             ));
          }
        }
      }

      return posts;
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
        headers: {
            ...XdmoviesHeaders.headers,
            // Add other headers if needed
        }
      );

      if (response.statusCode != 200) {
        print('xdmovies error: HTTP ${response.statusCode}');
        return [];
      }
      
      final baseUrl = await XdmoviesCatalog.baseUrl;
      final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;

      final document = html_parser.parse(response.body);
      final catalog = <Movie>[];

      /*
        $('.movie-link').each((i, element) => {
          const link = $elem.attr('href');
          const title = $elem.find('h3').text().trim();
          const image = $elem.find('img').attr('src') || '';
          if (link && title) { ... }
        });
      */

      final elements = document.querySelectorAll('.movie-link');
      for (var element in elements) {
         final href = element.attributes['href'];
         final titleElem = element.querySelector('h3');
         final imgElem = element.querySelector('img');
         
         final title = titleElem?.text.trim() ?? '';
         var image = imgElem?.attributes['src'] ?? '';
         
         if (href != null && href.isNotEmpty && title.isNotEmpty) {
           final fullLink = href.startsWith('http') ? href : '$cleanBase$href';
           
           // Ensure image is fully qualified if it's relative? 
           // TS code: const image = $elem.find('img').attr('src') || '';
           // Sometimes images are relative.
           if (image.isNotEmpty && !image.startsWith('http')) {
             image = '$cleanBase$image';
           }

           catalog.add(Movie(
             title: title,
             imageUrl: image,
             link: fullLink,
             quality: '', 
           ));
         }
      }

      return catalog;
    } catch (e) {
      print('Error parsing posts: $e');
      return [];
    }
  }
}
