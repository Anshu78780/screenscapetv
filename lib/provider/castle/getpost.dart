import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/movie.dart';
import 'catalog.dart';

class CastleGetPost {
  static const String imageBaseUrl = 'https://image.tmdb.org/t/p/w500';

  // Headers for TMDB API requests
  static Map<String, String> get _tmdbHeaders => {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'application/json',
    'Accept-Language': 'en-US,en;q=0.9',
    'Connection': 'keep-alive',
  };

  /// Fetch movies from TMDB based on category path
  static Future<List<Movie>> fetchMovies(String categoryPath) async {
    try {
      print('[CastleGetPost] Fetching movies for: $categoryPath');

      // Parse category path (format: "type:mediaType" e.g., "trending:movie")
      final parts = categoryPath.split(':');
      if (parts.length != 2) {
        print('[CastleGetPost] Invalid category path: $categoryPath');
        return [];
      }

      final type =
          parts[0]; // trending, popular, top_rated, upcoming, on_the_air
      final mediaType = parts[1]; // movie or tv

      String endpoint;
      switch (type) {
        case 'trending':
          endpoint = '${CastleCatalog.tmdbBaseUrl}/trending/$mediaType/week';
          break;
        case 'popular':
          endpoint = '${CastleCatalog.tmdbBaseUrl}/$mediaType/popular';
          break;
        case 'top_rated':
          endpoint = '${CastleCatalog.tmdbBaseUrl}/$mediaType/top_rated';
          break;
        case 'upcoming':
          endpoint = '${CastleCatalog.tmdbBaseUrl}/movie/upcoming';
          break;
        case 'on_the_air':
          endpoint = '${CastleCatalog.tmdbBaseUrl}/tv/on_the_air';
          break;
        default:
          print('[CastleGetPost] Unknown type: $type');
          return [];
      }

      final url = '$endpoint?api_key=${CastleCatalog.tmdbApiKey}&page=1';
      print('[CastleGetPost] Fetching from: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: _tmdbHeaders,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      if (response.statusCode != 200) {
        print(
          '[CastleGetPost] HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
        return [];
      }

      final data = jsonDecode(response.body);
      final results = (data['results'] ?? []) as List;

      print('[CastleGetPost] Found ${results.length} results');

      final movies = <Movie>[];
      for (final item in results) {
        final tmdbId = item['id']?.toString() ?? '';
        final title = mediaType == 'tv'
            ? (item['name'] ?? '')
            : (item['title'] ?? '');
        final posterPath = item['poster_path'];
        final releaseDate = mediaType == 'tv'
            ? item['first_air_date']
            : item['release_date'];
        final voteAverage = item['vote_average'];

        if (tmdbId.isEmpty || title.isEmpty) continue;

        // Build castle URL
        final castleUrl = 'castle://tmdb/$tmdbId/$mediaType';

        // Build image URL
        final imageUrl = posterPath != null ? '$imageBaseUrl$posterPath' : '';

        // Extract year from release date
        String quality = '';
        if (releaseDate != null && releaseDate.toString().isNotEmpty) {
          final year = releaseDate.toString().split('-')[0];
          quality = year;
        }

        // Add rating to quality if available
        if (voteAverage != null) {
          final rating = (voteAverage as num).toStringAsFixed(1);
          quality = quality.isEmpty ? '⭐ $rating' : '$quality • ⭐ $rating';
        }

        movies.add(
          Movie(
            title: title,
            imageUrl: imageUrl,
            quality: quality,
            link: castleUrl,
          ),
        );
      }

      print('[CastleGetPost] Returning ${movies.length} movies');
      return movies;
    } catch (e) {
      print('[CastleGetPost] Error fetching movies: $e');
      return [];
    }
  }

  /// Search movies on TMDB
  static Future<List<Movie>> searchMovies(String query) async {
    try {
      print('[CastleGetPost] Searching for: $query');

      // Search both movies and TV shows
      final movieUrl =
          '${CastleCatalog.tmdbBaseUrl}/search/movie?api_key=${CastleCatalog.tmdbApiKey}&query=${Uri.encodeComponent(query)}&page=1';
      final tvUrl =
          '${CastleCatalog.tmdbBaseUrl}/search/tv?api_key=${CastleCatalog.tmdbApiKey}&query=${Uri.encodeComponent(query)}&page=1';

      final movieResponse = await http.get(
        Uri.parse(movieUrl),
        headers: _tmdbHeaders,
      ).timeout(const Duration(seconds: 15));
      
      final tvResponse = await http.get(
        Uri.parse(tvUrl),
        headers: _tmdbHeaders,
      ).timeout(const Duration(seconds: 15));

      final movies = <Movie>[];

      // Process movie results
      if (movieResponse.statusCode == 200) {
        final data = jsonDecode(movieResponse.body);
        final results = (data['results'] ?? []) as List;

        for (final item in results) {
          final tmdbId = item['id']?.toString() ?? '';
          final title = item['title'] ?? '';
          final posterPath = item['poster_path'];
          final releaseDate = item['release_date'];
          final voteAverage = item['vote_average'];

          if (tmdbId.isEmpty || title.isEmpty) continue;

          final castleUrl = 'castle://tmdb/$tmdbId/movie';
          final imageUrl = posterPath != null ? '$imageBaseUrl$posterPath' : '';

          String quality = '';
          if (releaseDate != null && releaseDate.toString().isNotEmpty) {
            final year = releaseDate.toString().split('-')[0];
            quality = year;
          }

          if (voteAverage != null) {
            final rating = (voteAverage as num).toStringAsFixed(1);
            quality = quality.isEmpty ? '⭐ $rating' : '$quality • ⭐ $rating';
          }

          movies.add(
            Movie(
              title: title,
              imageUrl: imageUrl,
              quality: quality,
              link: castleUrl,
            ),
          );
        }
      }

      // Process TV show results
      if (tvResponse.statusCode == 200) {
        final data = jsonDecode(tvResponse.body);
        final results = (data['results'] ?? []) as List;

        for (final item in results) {
          final tmdbId = item['id']?.toString() ?? '';
          final title = item['name'] ?? '';
          final posterPath = item['poster_path'];
          final firstAirDate = item['first_air_date'];
          final voteAverage = item['vote_average'];

          if (tmdbId.isEmpty || title.isEmpty) continue;

          final castleUrl = 'castle://tmdb/$tmdbId/tv';
          final imageUrl = posterPath != null ? '$imageBaseUrl$posterPath' : '';

          String quality = 'TV';
          if (firstAirDate != null && firstAirDate.toString().isNotEmpty) {
            final year = firstAirDate.toString().split('-')[0];
            quality = 'TV • $year';
          }

          if (voteAverage != null) {
            final rating = (voteAverage as num).toStringAsFixed(1);
            quality = '$quality • ⭐ $rating';
          }

          movies.add(
            Movie(
              title: title,
              imageUrl: imageUrl,
              quality: quality,
              link: castleUrl,
            ),
          );
        }
      }

      print('[CastleGetPost] Search returning ${movies.length} results');
      return movies;
    } catch (e) {
      print('[CastleGetPost] Search error: $e');
      return [];
    }
  }
}
