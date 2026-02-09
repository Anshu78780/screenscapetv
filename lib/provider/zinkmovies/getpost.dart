import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import '../../libs/baseurl.dart';
import '../../models/movie.dart';
import 'headers.dart';

Future<List<Movie>> zinkmoviesGetPosts(
  String filter,
  int page,
) async {
  final baseUrl = await BaseUrl.getProviderUrl('zinkmovies');
  if (baseUrl == null) {
    print('ZinkMovies: Base URL not available');
    return [];
  }

  // Remove trailing slash from baseUrl if it exists
  final cleanBaseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;

  try {
    String url;

    switch (filter) {
      case 'featured':
        url = '$cleanBaseUrl/page/$page/';
        break;
      case 'movies':
        url = '$cleanBaseUrl/movies/page/$page/';
        break;
      case 'tvshows':
        url = '$cleanBaseUrl/tvshows/page/$page/';
        break;
      case 'latest':
        url = '$cleanBaseUrl/page/$page/';
        break;
      default:
        // For genres
        url = '$cleanBaseUrl/genre/$filter/page/$page/';
        break;
    }

    print('ZinkMovies getPosts URL: $url');

    final response = await http.get(
      Uri.parse(url),
      headers: zinkmoviesHeaders,
    );

    if (response.statusCode != 200) {
      print('ZinkMovies getPosts failed with status: ${response.statusCode}');
      return [];
    }

    final document = parser.parse(response.body);
    final posts = <Movie>[];

    final articles = document.querySelectorAll('article.item');
    for (var article in articles) {
      final titleElement = article.querySelector('h3 a');
      final title = titleElement?.text.trim() ?? '';
      final link = titleElement?.attributes['href'] ?? '';

      final posterImg = article.querySelector('.poster img');
      String image = posterImg?.attributes['data-src'] ??
          posterImg?.attributes['data-lazy-src'] ??
          posterImg?.attributes['data-original'] ??
          posterImg?.attributes['src'] ??
          '';

      // Filter out base64 SVG placeholders
      if (image.startsWith('data:image/svg+xml')) {
        image = posterImg?.attributes['data-src'] ??
            posterImg?.attributes['data-lazy-src'] ??
            posterImg?.attributes['data-original'] ??
            '';
      }

      if (title.isNotEmpty && link.isNotEmpty && image.isNotEmpty) {
        posts.add(Movie(
          title: title,
          link: link,
          imageUrl: image,
          quality: '',
        ));
      }
    }

    print('ZinkMovies found ${posts.length} posts');
    return posts;
  } catch (error) {
    print('ZinkMovies getPosts error: $error');
    return [];
  }
}

Future<List<Movie>> zinkmoviesGetPostsSearch(
  String searchQuery,
  int page,
) async {
  final baseUrl = await BaseUrl.getProviderUrl('zinkmovies');
  if (baseUrl == null) {
    print('ZinkMovies: Base URL not available');
    return [];
  }

  // Remove trailing slash from baseUrl if it exists
  final cleanBaseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;

  try {
    final encodedQuery = Uri.encodeComponent(searchQuery.replaceAll(' ', '+'));
    final url = '$cleanBaseUrl/?s=$encodedQuery';
    print('ZinkMovies search URL: $url');

    final response = await http.get(
      Uri.parse(url),
      headers: zinkmoviesHeaders,
    );

    if (response.statusCode != 200) {
      print('ZinkMovies search failed with status: ${response.statusCode}');
      return [];
    }

    final document = parser.parse(response.body);
    final posts = <Movie>[];

    // Search results use .result-item
    var resultItems = document.querySelectorAll('.result-item');
    for (var item in resultItems) {
      final titleElement = item.querySelector('.title a');
      final title = titleElement?.text.trim() ?? '';
      final link = titleElement?.attributes['href'] ?? '';

      final thumbnailImg = item.querySelector('.thumbnail img');
      String image = thumbnailImg?.attributes['data-src'] ??
          thumbnailImg?.attributes['data-lazy-src'] ??
          thumbnailImg?.attributes['data-original'] ??
          thumbnailImg?.attributes['src'] ??
          '';

      // Filter out base64 SVG placeholders
      if (image.startsWith('data:image/svg+xml')) {
        image = thumbnailImg?.attributes['data-src'] ??
            thumbnailImg?.attributes['data-lazy-src'] ??
            thumbnailImg?.attributes['data-original'] ??
            '';
      }

      if (title.isNotEmpty && link.isNotEmpty && image.isNotEmpty) {
        posts.add(Movie(
          title: title,
          link: link,
          imageUrl: image,
          quality: '',
        ));
      }
    }

    // Fallback to article.item if no results found
    if (posts.isEmpty) {
      print('No results with .result-item, trying fallback...');
      final articles = document.querySelectorAll('article.item');
      for (var article in articles) {
        final titleElement = article.querySelector('h3 a');
        final title = titleElement?.text.trim() ?? '';
        final link = titleElement?.attributes['href'] ?? '';

        final posterImg = article.querySelector('.poster img');
        String image = posterImg?.attributes['data-src'] ??
            posterImg?.attributes['data-lazy-src'] ??
            posterImg?.attributes['data-original'] ??
            posterImg?.attributes['src'] ??
            '';

        if (image.startsWith('data:image/svg+xml')) {
          image = posterImg?.attributes['data-src'] ??
              posterImg?.attributes['data-lazy-src'] ??
              posterImg?.attributes['data-original'] ??
              '';
        }

        if (title.isNotEmpty && link.isNotEmpty && image.isNotEmpty) {
          posts.add(Movie(
            title: title,
            link: link,
            imageUrl: image,
            quality: '',
          ));
        }
      }
    }

    print('ZinkMovies search found ${posts.length} posts');
    return posts;
  } catch (error) {
    print('ZinkMovies search error: $error');
    return [];
  }
}
