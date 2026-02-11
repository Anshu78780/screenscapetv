import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/movie.dart';
import 'headers.dart';

const String _apiBase = 'https://screenscapeapi.dev/api/animepahe';

Future<List<Movie>> animepaheGetPosts(String filter, int page) async {
  try {
    final url = Uri.parse(_apiBase).replace(queryParameters: {
      'page': page.toString(),
    });

    print('AnimePahe URL: $url');

    final response = await http.get(
      url,
      headers: animePaheHeaders,
    );

    if (response.statusCode != 200) {
      print('AnimePahe: Failed to fetch posts, status: ${response.statusCode}');
      return [];
    }

    final data = json.decode(response.body);

    if (data['success'] != true || data['result']?['data'] == null) {
      print('AnimePahe: Invalid response structure');
      return [];
    }

    final List<Movie> movies = [];
    final items = data['result']['data'] as List;

    for (var item in items) {
      try {
        // Create link as JSON string containing anime_session and session
        final linkData = {
          'anime_session': item['anime_session'],
          'session': item['session'],
        };

        movies.add(Movie(
          title: '${item['anime_title']} - EP ${item['episode']}',
          imageUrl: item['snapshot'] ?? '',
          quality: '', // AnimePahe doesn't provide quality in listing
          link: json.encode(linkData),
        ));
      } catch (e) {
        print('AnimePahe: Error parsing item: $e');
      }
    }

    return movies;
  } catch (e) {
    print('AnimePahe error: $e');
    return [];
  }
}

Future<List<Movie>> animepaheGetPostsSearch(String searchQuery, int page) async {
  try {
    final url = Uri.parse('$_apiBase/search').replace(queryParameters: {
      'q': searchQuery,
      'page': page.toString(),
    });

    print('AnimePahe search URL: $url');

    final response = await http.get(
      url,
      headers: animePaheHeaders,
    );

    if (response.statusCode != 200) {
      print('AnimePahe: Failed to search, status: ${response.statusCode}');
      return [];
    }

    final data = json.decode(response.body);

    if (data['success'] != true || data['data']?['data'] == null) {
      print('AnimePahe: Invalid search response structure');
      return [];
    }

    final List<Movie> movies = [];
    final items = data['data']['data'] as List;

    for (var item in items) {
      try {
        // For search results, we only have session
        final linkData = {
          'session': item['session'],
        };

        movies.add(Movie(
          title: '${item['title']} (${item['episodes']} eps)',
          imageUrl: item['poster'] ?? '',
          quality: '', // AnimePahe doesn't provide quality in listing
          link: json.encode(linkData),
        ));
      } catch (e) {
        print('AnimePahe: Error parsing search item: $e');
      }
    }

    return movies;
  } catch (e) {
    print('AnimePahe search error: $e');
    return [];
  }
}
