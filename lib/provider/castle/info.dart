import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/movie_info.dart';
import 'catalog.dart';
import 'geteps.dart';
import 'headers.dart';

class CastleInfo {
  static Future<Map<String, dynamic>> getDetails(
    String securityKey,
    String movieId,
  ) async {
    print('[Castle] Fetching details for movieId: $movieId');

    final url =
        '${CastleCatalog.baseUrl}/film-api/v1.1/movie?channel=${CastleCatalog.channel}&clientType=${CastleCatalog.client}&lang=${CastleCatalog.lang}&movieId=$movieId&packageName=${CastleCatalog.pkg}';

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

      final cipher = CastleCatalog.extractCipherFromResponse(response.body);
      final decrypted = await CastleCatalog.decryptCastle(cipher, securityKey);
      return jsonDecode(decrypted);
    } catch (e) {
      print('[Castle] Get details failed: $e');
      rethrow;
    }
  }

  static Map<String, dynamic> extractDataBlock(Map<String, dynamic> obj) {
    if (obj['data'] != null && obj['data'] is Map) {
      return obj['data'];
    }
    return obj;
  }

  static Future<Map<String, dynamic>> getComprehensiveDetails(
    String securityKey,
    String movieId,
    Map<String, dynamic> tmdbInfo,
  ) async {
    final details = await getDetails(securityKey, movieId);
    final data = extractDataBlock(details);

    final comprehensive = {
      'castleMovieId': movieId,
      'tmdbInfo': tmdbInfo,
      'title': data['title'] ?? tmdbInfo['title'],
      'description': data['desc'] ?? data['description'] ?? tmdbInfo['overview'] ?? '',
      'imageUrl': tmdbInfo['imageUrl'] ?? data['imageUrl'] ?? data['coverUrl'] ?? '',
      'seasons': <Map<String, dynamic>>[],
      'episodes': <Map<String, dynamic>>[],
    };

    final seasons = (data['seasons'] ?? []) as List;
    for (final season in seasons) {
      final seasonNum = season['number'] as int?;
      if (seasonNum == null) continue;

      final seasonMovieId = season['movieId']?.toString() ?? movieId;
      
      Map<String, dynamic> seasonData = data;
      if (seasonMovieId != movieId) {
        print('[Castle] Fetching season $seasonNum details (movieId: $seasonMovieId)...');
        final seasonDetails = await getDetails(securityKey, seasonMovieId);
        seasonData = extractDataBlock(seasonDetails);
      }

      final episodesList = (seasonData['episodes'] ?? []) as List;
      final seasonEpisodes = <Map<String, dynamic>>[];

      for (final ep in episodesList) {
        final episodeNum = ep['number'] as int?;
        final episodeId = ep['id'];
        final tracks = (ep['tracks'] ?? []) as List;

        if (episodeNum != null && episodeId != null) {
          seasonEpisodes.add({
            'number': episodeNum,
            'id': episodeId.toString(),
            'title': ep['title'] ?? 'Episode $episodeNum',
            'tracks': tracks,
            'seasonNumber': seasonNum,
            'movieId': seasonMovieId,
          });
        }
      }

      comprehensive['seasons'].add({
        'number': seasonNum,
        'movieId': seasonMovieId,
        'episodes': seasonEpisodes,
      });

      (comprehensive['episodes'] as List).addAll(seasonEpisodes);
    }

    if (seasons.isEmpty) {
      final episodes = (data['episodes'] ?? []) as List;
      for (final ep in episodes) {
        final episodeId = ep['id'];
        final tracks = (ep['tracks'] ?? []) as List;

        if (episodeId != null) {
          (comprehensive['episodes'] as List).add({
            'number': 1,
            'id': episodeId.toString(),
            'title': ep['title'] ?? data['title'] ?? 'Movie',
            'tracks': tracks,
            'movieId': movieId,
          });
        }
      }
    }

    return comprehensive;
  }

  /// Parse Castle URL format: castle://tmdb/{tmdbId}/{mediaType}[/s{season}[/e{episode}]]
  static Map<String, dynamic> parseCastleUrl(String url) {
    final cleanUrl = url.replaceFirst(RegExp(r'^castle://'), '');
    final parts = cleanUrl.split('/');

    if (parts.length < 3 || parts[0] != 'tmdb') {
      throw Exception(
        'Invalid Castle URL format. Expected: castle://tmdb/{tmdbId}/{mediaType}[/s{season}[/e{episode}]]',
      );
    }

    final tmdbId = parts[1];
    final mediaType = parts[2];

    int? season;
    int? episode;

    if (parts.length >= 4) {
      final seasonStr = parts[3];
      if (seasonStr.startsWith('s')) {
        season = int.tryParse(seasonStr.substring(1));
      }

      if (parts.length >= 5) {
        final episodeStr = parts[4];
        if (episodeStr.startsWith('e')) {
          episode = int.tryParse(episodeStr.substring(1));
        }
      }
    }

    return {
      'tmdbId': tmdbId,
      'mediaType': mediaType,
      'season': season,
      'episode': episode,
    };
  }

  /// Fetch MovieInfo for Castle content
  static Future<MovieInfo> fetchMovieInfo(String movieUrl) async {
    try {
      final parsed = parseCastleUrl(movieUrl);
      final tmdbId = parsed['tmdbId'] as String;
      final mediaType = parsed['mediaType'] as String;

      // Use CastleGetEps to get all episode data
      final episodesData = await CastleGetEps.getEpisodes(
        tmdbId: tmdbId,
        mediaType: mediaType,
      );

      final title = episodesData['title'] as String;
      final description = episodesData['overview'] as String? ?? '';
      final imageUrl = episodesData['imageUrl'] as String? ?? '';

      final downloadUrl = 'castle://tmdb/$tmdbId/$mediaType';

      List<Episode> episodes = [];
      List<DownloadLink> downloadLinks = [];

      if (mediaType == 'tv') {
        final seasons = List.from(episodesData['seasons'] ?? []);

        print('[CastleInfo] Loading all episodes from ${seasons.length} seasons for $title');

        for (final seasonMap in seasons) {
          final season = seasonMap as Map<String, dynamic>;
          final seasonNum = season['seasonNumber'] as int?;
          final seasonEpisodes = List.from(season['episodes'] ?? []);

          if (seasonNum == null || seasonEpisodes.isEmpty) continue;

          for (final ep in seasonEpisodes) {
            final episode = ep as Map<String, dynamic>;
            final episodeNum = episode['episodeNumber'] as int?;
            final episodeTitle = episode['title'] ?? 'Episode $episodeNum';
            
            if (episodeNum != null) {
              final episodeUrl = 'castle://tmdb/$tmdbId/$mediaType/s$seasonNum/e$episodeNum';
              
              episodes.add(
                Episode(
                  title: 'S${seasonNum.toString().padLeft(2, '0')}E${episodeNum.toString().padLeft(2, '0')} - $episodeTitle',
                  link: episodeUrl,
                ),
              );

              downloadLinks.add(
                DownloadLink(
                  quality: 'S${seasonNum.toString().padLeft(2, '0')}E${episodeNum.toString().padLeft(2, '0')}',
                  size: episodeTitle,
                  url: episodeUrl,
                  season: 'Season $seasonNum',
                  episodeInfo: 'Episode $episodeNum',
                ),
              );
            }
          }
        }

        print('[CastleInfo] Loaded ${episodes.length} episodes as downloadable items');
      } else {
        downloadLinks.add(
          DownloadLink(
            quality: 'Movie',
            size: 'Full Movie',
            url: downloadUrl,
          ),
        );
      }

      return MovieInfo(
        title: title,
        imageUrl: imageUrl,
        imdbRating: '',
        genre: '',
        director: '',
        writer: '',
        stars: '',
        language: '',
        quality: '',
        format: '',
        storyline: description,
        downloadLinks: downloadLinks,
      );
    } catch (e) {
      print('[CastleInfo] Failed to fetch movie info: $e');
      rethrow;
    }
  }
}
