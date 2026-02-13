import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'catalog.dart';
import 'headers.dart';

/// Castle Episode Manager
/// Handles fetching and managing episodes for TV shows and movies with caching
class CastleGetEps {
  // Cache duration: 1 day
  static const Duration _cacheDuration = Duration(days: 1);
  static const String _cachePrefix = 'castle_eps_cache_';
  static const String _cacheTimePrefix = 'castle_eps_time_';
  static const String _seasonCachePrefix = 'castle_season_cache_';
  static const String _seasonCacheTimePrefix = 'castle_season_time_';

  /// Clear all cached episode data
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith(_cachePrefix) || 
          key.startsWith(_cacheTimePrefix) ||
          key.startsWith(_seasonCachePrefix) || 
          key.startsWith(_seasonCacheTimePrefix)) {
        await prefs.remove(key);
      }
    }
    print('[CastleEps] Cache cleared');
  }

  /// Get cached season data
  static Future<Map<String, dynamic>?> _getCachedSeason(
    String tmdbId,
    int seasonNum,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_seasonCachePrefix${tmdbId}_s$seasonNum';
      final timeKey = '$_seasonCacheTimePrefix${tmdbId}_s$seasonNum';

      final cachedJson = prefs.getString(cacheKey);
      final cachedTime = prefs.getInt(timeKey);

      if (cachedJson != null && cachedTime != null) {
        final cacheDate = DateTime.fromMillisecondsSinceEpoch(cachedTime);
        final now = DateTime.now();

        if (now.difference(cacheDate) < _cacheDuration) {
          print('[CastleEps] Using cached season data for TMDB: $tmdbId, Season: $seasonNum');
          return jsonDecode(cachedJson);
        } else {
          print('[CastleEps] Season cache expired for TMDB: $tmdbId, Season: $seasonNum');
          await prefs.remove(cacheKey);
          await prefs.remove(timeKey);
        }
      }
    } catch (e) {
      print('[CastleEps] Error reading season cache: $e');
    }

    return null;
  }

  /// Save season data to cache
  static Future<void> _setCachedSeason(
    String tmdbId,
    int seasonNum,
    Map<String, dynamic> data,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_seasonCachePrefix${tmdbId}_s$seasonNum';
      final timeKey = '$_seasonCacheTimePrefix${tmdbId}_s$seasonNum';

      await prefs.setString(cacheKey, jsonEncode(data));
      await prefs.setInt(timeKey, DateTime.now().millisecondsSinceEpoch);

      print('[CastleEps] Cached season data for TMDB: $tmdbId, Season: $seasonNum');
    } catch (e) {
      print('[CastleEps] Error writing season cache: $e');
    }
  }

  /// Get cached data if available and not expired
  static Future<Map<String, dynamic>?> _getCachedData(String tmdbId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$tmdbId';
      final timeKey = '$_cacheTimePrefix$tmdbId';

      final cachedJson = prefs.getString(cacheKey);
      final cachedTime = prefs.getInt(timeKey);

      if (cachedJson != null && cachedTime != null) {
        final cacheDate = DateTime.fromMillisecondsSinceEpoch(cachedTime);
        final now = DateTime.now();

        if (now.difference(cacheDate) < _cacheDuration) {
          print('[CastleEps] Using cached data for TMDB: $tmdbId');
          return jsonDecode(cachedJson);
        } else {
          print('[CastleEps] Cache expired for TMDB: $tmdbId');
          await prefs.remove(cacheKey);
          await prefs.remove(timeKey);
        }
      }
    } catch (e) {
      print('[CastleEps] Error reading cache: $e');
    }

    return null;
  }

  /// Save data to cache
  static Future<void> _setCachedData(
    String tmdbId,
    Map<String, dynamic> data,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$tmdbId';
      final timeKey = '$_cacheTimePrefix$tmdbId';

      await prefs.setString(cacheKey, jsonEncode(data));
      await prefs.setInt(timeKey, DateTime.now().millisecondsSinceEpoch);

      print('[CastleEps] Cached data for TMDB: $tmdbId');
    } catch (e) {
      print('[CastleEps] Error writing cache: $e');
    }
  }
  /// Extract data block from API response
  static Map<String, dynamic> extractDataBlock(Map<String, dynamic> obj) {
    if (obj['data'] != null && obj['data'] is Map) {
      return obj['data'];
    }
    return obj;
  }

  /// Get movie/TV show details from Castle API
  static Future<Map<String, dynamic>> getDetails(
    String securityKey,
    String movieId,
  ) async {
    print('[CastleEps] Fetching details for movieId: $movieId');

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
      print('[CastleEps] Get details failed: $e');
      rethrow;
    }
  }

  /// Get all episodes for a movie or TV show
  /// Returns a structured map with seasons and episodes
  /// If seasonNum is provided, only fetches that specific season
  /// Initial load: Only fetches Season 1 from Castle, other seasons from TMDB metadata
  static Future<Map<String, dynamic>> getEpisodes({
    required String tmdbId,
    required String mediaType,
    int? seasonNum,
    int? episodeNum,
  }) async {
    print(
      '[CastleEps] Getting episodes for TMDB: $tmdbId, Type: $mediaType${seasonNum != null ? ', Season: $seasonNum' : ''}${episodeNum != null ? ', Episode: $episodeNum' : ''}',
    );

    try {
      // If specific season requested, check season cache first
      if (seasonNum != null) {
        final cachedSeason = await _getCachedSeason(tmdbId, seasonNum);
        if (cachedSeason != null) {
          return cachedSeason;
        }

        // Not in cache, fetch it
        return await _fetchSpecificSeason(tmdbId, mediaType, seasonNum);
      }

      // Check full cache for initial load
      final cachedData = await _getCachedData(tmdbId);
      if (cachedData != null) {
        print('[CastleEps] Using full cached data');
        return cachedData;
      }

      // Step 1: Get TMDB details
      final tmdbInfo = await CastleCatalog.getTMDBDetails(tmdbId, mediaType);
      print(
        '[CastleEps] TMDB Info: "${tmdbInfo['title']}" (${tmdbInfo['year'] ?? 'N/A'})',
      );

      // Step 2: Get security key
      final securityKey = await CastleCatalog.getSecurityKey();

      // Step 3: Find Castle movie ID
      final movieId = await CastleCatalog.findCastleMovieId(
        securityKey,
        tmdbInfo,
      );

      // Step 4: Get initial details (to get season list)
      var details = await getDetails(securityKey, movieId);
      final data = extractDataBlock(details);
      final castleSeasons = (data['seasons'] ?? []) as List;

      // Step 5: Build result structure
      final result = {
        'tmdbId': tmdbId,
        'mediaType': mediaType,
        'castleMovieId': movieId,
        'title': tmdbInfo['title'],
        'year': tmdbInfo['year'],
        'imageUrl': tmdbInfo['imageUrl'],
        'overview': tmdbInfo['overview'],
        'seasons': <Map<String, dynamic>>[],
        'episodes': <Map<String, dynamic>>[],
      };

      // Step 6: Process episodes based on media type
      if (mediaType == 'tv' && castleSeasons.isNotEmpty) {
        // Initial load: Only fetch Season 1 from Castle, use TMDB for others
        print('[CastleEps] Initial load: Fetching Season 1 from Castle, using TMDB for metadata');
        await _processInitialLoad(
          result,
          castleSeasons,
          securityKey,
          movieId,
          tmdbId,
        );
      } else if (mediaType != 'tv') {
        // Handle movies
        await _processMovieEpisodes(result, data, movieId);
      }

      print(
        '[CastleEps] Found ${(result['seasons'] as List).length} seasons, ${(result['episodes'] as List).length} episodes',
      );

      // Cache the full result
      await _setCachedData(tmdbId, result);

      return result;
    } catch (e) {
      print('[CastleEps] Failed to get episodes: $e');
      rethrow;
    }
  }

  /// Fetch a specific season on demand
  static Future<Map<String, dynamic>> _fetchSpecificSeason(
    String tmdbId,
    String mediaType,
    int seasonNum,
  ) async {
    print('[CastleEps] Fetching season $seasonNum on demand...');

    // Get TMDB details
    final tmdbInfo = await CastleCatalog.getTMDBDetails(tmdbId, mediaType);

    // Get security key
    final securityKey = await CastleCatalog.getSecurityKey();

    // Find Castle movie ID
    final movieId = await CastleCatalog.findCastleMovieId(
      securityKey,
      tmdbInfo,
    );

    // Get initial details to find season ID
    final details = await getDetails(securityKey, movieId);
    final data = extractDataBlock(details);
    final castleSeasons = (data['seasons'] ?? []) as List;

    final result = {
      'tmdbId': tmdbId,
      'mediaType': mediaType,
      'castleMovieId': movieId,
      'title': tmdbInfo['title'],
      'year': tmdbInfo['year'],
      'imageUrl': tmdbInfo['imageUrl'],
      'overview': tmdbInfo['overview'],
      'seasons': <Map<String, dynamic>>[],
      'episodes': <Map<String, dynamic>>[],
    };

    // Fetch only this season from Castle
    await _processSingleSeasonFull(
      result,
      castleSeasons,
      seasonNum,
      securityKey,
      movieId,
    );

    return result;
  }

  /// Initial load: Fetch Season 1 from Castle, use TMDB metadata for others
  static Future<void> _processInitialLoad(
    Map<String, dynamic> result,
    List castleSeasons,
    String securityKey,
    String mainMovieId,
    String tmdbId,
  ) async {
    // Get TMDB season data for metadata
    final tmdbSeasonData = <int, Map<String, dynamic>>{};
    
    try {
      // Fetch TMDB data for all seasons in parallel (lightweight)
      final tmdbFutures = <Future>[];
      for (final season in castleSeasons) {
        final sNum = season['number'] as int?;
        if (sNum != null) {
          tmdbFutures.add(
            CastleCatalog.getTMDBSeasonDetails(tmdbId, sNum).then((data) {
              tmdbSeasonData[sNum] = data;
            }).catchError((e) {
              print('[CastleEps] Failed to get TMDB season $sNum: $e');
            }),
          );
        }
      }
      await Future.wait(tmdbFutures);
    } catch (e) {
      print('[CastleEps] Error fetching TMDB season data: $e');
    }

    // Process Season 1 from Castle (with full episode details)
    bool season1Processed = false;
    for (final season in castleSeasons) {
      final sNum = season['number'] as int?;
      if (sNum == null) continue;

      if (sNum == 1) {
        // Fetch Season 1 from Castle
        print('[CastleEps] Fetching Season 1 from Castle...');
        await _processSingleSeasonFull(
          result,
          castleSeasons,
          sNum,
          securityKey,
          mainMovieId,
        );
        season1Processed = true;
      } else {
        // For other seasons, use TMDB metadata only
        final seasonTmdbData = tmdbSeasonData[sNum];
        if (seasonTmdbData != null) {
          final episodeCount = (seasonTmdbData['episodes'] as List?)?.length ?? 0;
          print('[CastleEps] Using TMDB metadata for Season $sNum ($episodeCount episodes)');
          
          final seasonMovieId = season['movieId']?.toString() ?? mainMovieId;
          final tmdbEpisodes = (seasonTmdbData['episodes'] as List?) ?? [];
          final seasonEpisodes = <Map<String, dynamic>>[];

          // Create placeholder episodes from TMDB data
          for (final tmdbEp in tmdbEpisodes) {
            final epNum = tmdbEp['episode_number'] as int?;
            if (epNum != null) {
              seasonEpisodes.add({
                'episodeNumber': epNum,
                'seasonNumber': sNum,
                'episodeId': 'placeholder', // Will be fetched when season is selected
                'movieId': seasonMovieId,
                'title': tmdbEp['name'] ?? 'Episode $epNum',
                'description': tmdbEp['overview'] ?? '',
                'imageUrl': tmdbEp['still_path'] != null 
                    ? 'https://image.tmdb.org/t/p/w300${tmdbEp['still_path']}'
                    : '',
                'tracks': [], // Will be filled when season is fetched
                'isPlaceholder': true, // Flag to know this needs fetching
              });
            }
          }

          (result['seasons'] as List).add({
            'seasonNumber': sNum,
            'movieId': seasonMovieId,
            'episodeCount': episodeCount,
            'episodes': seasonEpisodes,
            'isPlaceholder': true,
          });

          (result['episodes'] as List).addAll(seasonEpisodes);
        }
      }
    }

    if (!season1Processed && castleSeasons.isNotEmpty) {
      // If no Season 1, fetch the first available season
      final firstSeason = castleSeasons.first;
      final firstSeasonNum = firstSeason['number'] as int?;
      if (firstSeasonNum != null) {
        print('[CastleEps] No Season 1 found, fetching Season $firstSeasonNum...');
        await _processSingleSeasonFull(
          result,
          castleSeasons,
          firstSeasonNum,
          securityKey,
          mainMovieId,
        );
      }
    }
  }

  /// Process single season with full Castle data
  static Future<void> _processSingleSeasonFull(
    Map<String, dynamic> result,
    List seasons,
    int seasonNum,
    String securityKey,
    String mainMovieId,
  ) async {
    final season = seasons.firstWhere(
      (s) => s['number'] == seasonNum,
      orElse: () => null,
    );

    if (season == null) {
      print('[CastleEps] Season $seasonNum not found');
      return;
    }

    final sNum = season['number'] as int;
    final seasonMovieId = season['movieId']?.toString() ?? mainMovieId;

    print('[CastleEps] Fetching season $sNum details from Castle...');
    final seasonDetails = await getDetails(securityKey, seasonMovieId);
    final seasonData = extractDataBlock(seasonDetails);

    final seasonEpisodes = (seasonData['episodes'] ?? []) as List;
    final processedEpisodes = <Map<String, dynamic>>[];

    for (final ep in seasonEpisodes) {
      final epNum = ep['number'] as int?;
      final epId = ep['id'];
      final tracks = (ep['tracks'] ?? []) as List;

      if (epNum != null && epId != null) {
        final episodeData = {
          'episodeNumber': epNum,
          'seasonNumber': sNum,
          'episodeId': epId.toString(),
          'movieId': seasonMovieId,
          'title': ep['title'] ?? 'Episode $epNum',
          'description': ep['desc'] ?? ep['description'] ?? '',
          'imageUrl': ep['coverUrl'] ?? ep['imageUrl'] ?? '',
          'tracks': tracks.map((track) {
            return {
              'languageId': track['languageId'],
              'languageName': track['languageName'] ?? track['abbreviate'] ?? 'Unknown',
              'abbreviate': track['abbreviate'] ?? '',
              'existIndividualVideo': track['existIndividualVideo'] ?? false,
            };
          }).toList(),
          'isPlaceholder': false,
        };

        processedEpisodes.add(episodeData);
        (result['episodes'] as List).add(episodeData);
      }
    }

    (result['seasons'] as List).add({
      'seasonNumber': sNum,
      'movieId': seasonMovieId,
      'episodeCount': processedEpisodes.length,
      'episodes': processedEpisodes,
      'isPlaceholder': false,
    });

    // Cache this season individually
    final seasonResult = {
      'tmdbId': result['tmdbId'],
      'mediaType': result['mediaType'],
      'castleMovieId': result['castleMovieId'],
      'title': result['title'],
      'year': result['year'],
      'imageUrl': result['imageUrl'],
      'overview': result['overview'],
      'seasons': [
        {
          'seasonNumber': sNum,
          'movieId': seasonMovieId,
          'episodeCount': processedEpisodes.length,
          'episodes': processedEpisodes,
        }
      ],
      'episodes': processedEpisodes,
    };
    await _setCachedSeason(result['tmdbId'] as String, sNum, seasonResult);
  }

  /// Process movie episodes
  static Future<void> _processMovieEpisodes(
    Map<String, dynamic> result,
    Map<String, dynamic> data,
    String movieId,
  ) async {
    final episodes = (data['episodes'] ?? []) as List;

    for (final ep in episodes) {
      final epId = ep['id'];
      final tracks = (ep['tracks'] ?? []) as List;

      if (epId != null) {
        final episodeData = {
          'episodeNumber': 1,
          'seasonNumber': 1,
          'episodeId': epId.toString(),
          'movieId': movieId,
          'title': ep['title'] ?? data['title'] ?? 'Movie',
          'description': ep['desc'] ?? ep['description'] ?? data['desc'] ?? '',
          'imageUrl': ep['coverUrl'] ?? ep['imageUrl'] ?? result['imageUrl'] ?? '',
          'tracks': tracks.map((track) {
            return {
              'languageId': track['languageId'],
              'languageName': track['languageName'] ?? track['abbreviate'] ?? 'Unknown',
              'abbreviate': track['abbreviate'] ?? '',
              'existIndividualVideo': track['existIndividualVideo'] ?? false,
            };
          }).toList(),
        };

        (result['episodes'] as List).add(episodeData);
      }
    }
  }

  /// Get a specific episode by season and episode number
  static Future<Map<String, dynamic>?> getEpisode({
    required String tmdbId,
    required String mediaType,
    required int seasonNum,
    required int episodeNum,
  }) async {
    final allEpisodes = await getEpisodes(
      tmdbId: tmdbId,
      mediaType: mediaType,
      seasonNum: seasonNum,
    );

    final episodes = List.from(allEpisodes['episodes'] ?? []);
    
    for (final ep in episodes) {
      final epMap = ep as Map<String, dynamic>;
      if (epMap['seasonNumber'] == seasonNum && epMap['episodeNumber'] == episodeNum) {
        return epMap;
      }
    }

    return null;
  }
}
