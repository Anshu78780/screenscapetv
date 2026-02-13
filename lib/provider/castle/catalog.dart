import 'dart:convert';
import 'package:http/http.dart' as http;
import 'headers.dart';

class CastleCatalog {
  static const String baseUrl = 'https://api.fstcy.com';
  static const String pkg = 'com.external.castle';
  static const String channel = 'IndiaA';
  static const String client = '1';
  static const String lang = 'en-US';
  static const String tmdbApiKey = '5a209f099efaba1cd26a904e09b90829';
  static const String tmdbBaseUrl = 'https://api.themoviedb.org/3';

  // Categories for Castle provider
  static const List<Map<String, String>> categories = [
    {'name': 'Trending Movies', 'path': 'trending:movie'},
    {'name': 'Trending TV Shows', 'path': 'trending:tv'},
    {'name': 'Popular Movies', 'path': 'popular:movie'},
    {'name': 'Popular TV Shows', 'path': 'popular:tv'},
    {'name': 'Top Rated Movies', 'path': 'top_rated:movie'},
    {'name': 'Top Rated TV Shows', 'path': 'top_rated:tv'},
    {'name': 'Upcoming Movies', 'path': 'upcoming:movie'},
    {'name': 'On The Air TV', 'path': 'on_the_air:tv'},
  ];

  static Future<String> getCategoryUrl(String path) async {
    return path;
  }

  // AES-CBC Decryption using remote server (Castle-specific)
  static Future<String> decryptCastle(
    String encryptedB64,
    String securityKeyB64,
  ) async {
    print('[Castle] Starting Castle-specific AES-CBC decryption...');

    try {
      final response = await http.post(
        Uri.parse('https://aesdec.nuvioapp.space/decrypt-castle'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'encryptedData': encryptedB64,
          'securityKey': securityKeyB64,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }

      final data = jsonDecode(response.body);
      if (data['error'] != null) {
        throw Exception(data['error']);
      }

      print('[Castle] Server decryption successful');
      return data['decrypted'];
    } catch (e) {
      print('[Castle] Server decryption failed: $e');
      rethrow;
    }
  }

  // Get security key from Castle API
  static Future<String> getSecurityKey() async {
    print('[Castle] Fetching security key...');
    final url =
        '$baseUrl/v0.1/system/getSecurityKey/1?channel=$channel&clientType=$client&lang=$lang';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: CastleHeaders.workingHeaders,
      );

      if (response.statusCode != 200) {
        throw Exception(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }

      final data = jsonDecode(response.body);
      if (data['code'] != 200 || data['data'] == null) {
        throw Exception('Security key API error: ${response.body}');
      }

      print('[Castle] Security key obtained');
      return data['data'];
    } catch (e) {
      print('[Castle] Failed to get security key: $e');
      rethrow;
    }
  }

  // Extract cipher from response
  static String extractCipherFromResponse(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw Exception('Empty response');
    }

    // Try to parse as JSON first
    try {
      final json = jsonDecode(trimmed);
      if (json != null && json['data'] != null && json['data'] is String) {
        return json['data'].trim();
      }
    } catch (e) {
      // Not JSON, assume it's raw base64
    }

    return trimmed;
  }

  // Search for content by keyword
  static Future<Map<String, dynamic>> searchCastle(
    String securityKey,
    String keyword, {
    int page = 1,
    int size = 30,
  }) async {
    print('[Castle] Searching for: $keyword');

    final params = {
      'channel': channel,
      'clientType': client,
      'keyword': keyword,
      'lang': lang,
      'mode': '1',
      'packageName': pkg,
      'page': page.toString(),
      'size': size.toString(),
    };

    final uri = Uri.parse(
      '$baseUrl/film-api/v1.1.0/movie/searchByKeyword',
    ).replace(queryParameters: params);

    try {
      final response = await http.get(
        uri,
        headers: CastleHeaders.workingHeaders,
      );

      if (response.statusCode != 200) {
        throw Exception(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }

      final cipher = extractCipherFromResponse(response.body);
      final decrypted = await decryptCastle(cipher, securityKey);
      return jsonDecode(decrypted);
    } catch (e) {
      print('[Castle] Search failed: $e');
      rethrow;
    }
  }

  // Get TMDB details with comprehensive data
  static Future<Map<String, dynamic>> getTMDBDetails(
    String tmdbId,
    String mediaType,
  ) async {
    final endpoint = mediaType == 'tv' ? 'tv' : 'movie';
    final url =
        '$tmdbBaseUrl/$endpoint/$tmdbId?api_key=$tmdbApiKey&append_to_response=external_ids,images';

    try {
      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              'Accept': 'application/json',
              'Accept-Language': 'en-US,en;q=0.9',
              'Connection': 'keep-alive',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }

      final data = jsonDecode(response.body);
      final title = mediaType == 'tv' ? data['name'] : data['title'];
      final releaseDate = mediaType == 'tv'
          ? data['first_air_date']
          : data['release_date'];
      final year = releaseDate != null && releaseDate.isNotEmpty
          ? int.tryParse(releaseDate.split('-')[0])
          : null;

      // Get poster image URL
      final posterPath = data['poster_path'];
      final imageUrl = posterPath != null
          ? 'https://image.tmdb.org/t/p/w500$posterPath'
          : '';

      return {
        'title': title,
        'year': year,
        'tmdbId': tmdbId,
        'imageUrl': imageUrl,
        'overview': data['overview'] ?? '',
        'rawData': data,
      };
    } catch (e) {
      print('[Castle] TMDB fetch failed: $e');
      rethrow;
    }
  }

  // Get TMDB season details with episodes
  static Future<Map<String, dynamic>> getTMDBSeasonDetails(
    String tmdbId,
    int seasonNumber,
  ) async {
    final url =
        '$tmdbBaseUrl/tv/$tmdbId/season/$seasonNumber?api_key=$tmdbApiKey';

    try {
      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              'Accept': 'application/json',
              'Accept-Language': 'en-US,en;q=0.9',
              'Connection': 'keep-alive',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }

      return jsonDecode(response.body);
    } catch (e) {
      print('[Castle] TMDB season fetch failed: $e');
      rethrow;
    }
  }

  // Find Castle movie ID by searching
  static Future<String> findCastleMovieId(
    String securityKey,
    Map<String, dynamic> tmdbInfo,
  ) async {
    final searchTerm = tmdbInfo['year'] != null
        ? '${tmdbInfo['title']} ${tmdbInfo['year']}'
        : tmdbInfo['title'];

    final searchResult = await searchCastle(securityKey, searchTerm);
    final data = searchResult['data'] ?? searchResult;
    final rows = (data['rows'] ?? []) as List;

    if (rows.isEmpty) {
      throw Exception('No search results found');
    }

    // Try to find exact match first
    for (final item in rows) {
      final itemTitle = (item['title'] ?? item['name'] ?? '').toLowerCase();
      final searchTitle = (tmdbInfo['title'] as String).toLowerCase();

      if (itemTitle.contains(searchTitle) || searchTitle.contains(itemTitle)) {
        final movieId =
            item['id'] ?? item['redirectId'] ?? item['redirectIdStr'];
        if (movieId != null) {
          print(
            '[Castle] Found match: ${item['title'] ?? item['name']} (id: $movieId)',
          );
          return movieId.toString();
        }
      }
    }

    // Fallback to first result
    final firstItem = rows[0];
    final movieId =
        firstItem['id'] ??
        firstItem['redirectId'] ??
        firstItem['redirectIdStr'];
    if (movieId != null) {
      print(
        '[Castle] Using first result: ${firstItem['title'] ?? firstItem['name']} (id: $movieId)',
      );
      return movieId.toString();
    }

    throw Exception('Could not extract movie ID from search results');
  }
}
