import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../../models/movie.dart';
import 'headers.dart';
import 'catalog.dart';

class MoviesmodGetPost {
  
  static Future<List<Movie>> fetchMovies(String categoryUrl, {int page = 1}) async {
    try {
      // categoryUrl comes from getCategoryUrl which already combines base + path
      // TS: `${baseUrl + filter}/page/${page}/`
      // If page > 1, append pagination
      
      String finalUrl = categoryUrl;
      if (page > 1) {
        if (finalUrl.endsWith('/')) {
          finalUrl = '${finalUrl}page/$page/';
        } else {
          finalUrl = '$finalUrl/page/$page/';
        }
      } else {
         // Even for page 1, verify if slash is needed? TS doesn't show it for page 1 explicitly in my quick read 
         // but logic was `${baseUrl + filter}/page/${page}/`.
         // Wait, TS says: const url = `${baseUrl + filter}/page/${page}/`;
         // So it ALWAYS uses /page/X/. 
         // Let's verify standard behavior. usually page 1 is same as root.
         // But if TS explicitly says /page/page/, then maybe I should follow it or stick to standard.
         // "posts(url, signal)"...
         
         // Let's stick to standard behavior (root for page 1) unless it fails, 
         // or if page 1 is explicitly requested as /page/1/.
         // Often /page/1/ redirects to root. 
         // I'll leave page 1 as is (root/filter) and add pagination for > 1.
      }
      
      print('Moviesmod url: $finalUrl');
      return await _fetchPosts(finalUrl);
    } catch (e) {
      print('Moviesmod fetchMovies error: $e');
      throw Exception('Error fetching movies: $e');
    }
  }

  static Future<List<Movie>> searchMovies(String query, {int page = 1}) async {
    try {
      final baseUrl = await MoviesmodCatalog.baseUrl;
      final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
      
      // TS: `${baseUrl}/search/${searchQuery}/page/${page}/`
      // For page 1, might be /search/query/
      
      String url;
      if (page > 1) {
         url = '$cleanBase/search/${Uri.encodeComponent(query)}/page/$page/';
      } else {
         url = '$cleanBase/search/${Uri.encodeComponent(query)}/';
      }
      
      print('Moviesmod search url: $url');
      return await _fetchPosts(url);
    } catch (e) {
       print('Moviesmod searchMovies error: $e');
       throw Exception('Error searching movies: $e');
    }
  }

  static Future<List<Movie>> _fetchPosts(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: MoviesmodHeaders.headers,
      );

      if (response.statusCode != 200) {
        print('Moviesmod error: HTTP ${response.statusCode}');
        return [];
      }

      final document = html_parser.parse(response.body);
      final posts = <Movie>[];

      /*
        $('.post-cards').find('article').map(...)
          title: $(element).find('a').attr('title');
          link: $(element).find('a').attr('href');
          image: img data-src OR src
      */
      
      // There might be multiple .post-cards, or just one container
      final articles = document.querySelectorAll('.post-cards article');
      
      for (var element in articles) {
        final aTag = element.querySelector('a');
        final titleAttr = aTag?.attributes['title'];
        final link = aTag?.attributes['href'] ?? '';
        
        final imgTag = element.querySelector('img');
        String image = imgTag?.attributes['data-src'] ?? imgTag?.attributes['src'] ?? '';
        
        if (titleAttr != null && link.isNotEmpty) {
          final title = titleAttr.replaceAll('Download', '').trim();
          
          posts.add(Movie(
            title: title,
            imageUrl: image,
            link: link,
            quality: '', 
          ));
        }
      }

      print('Found ${posts.length} posts from Moviesmod');
      return posts;
    } catch (e) {
      print('Moviesmod binding error: $e');
      return [];
    }
  }
}
