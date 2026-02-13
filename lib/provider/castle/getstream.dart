import 'dart:convert';
import 'package:http/http.dart' as http;
import 'catalog.dart';
import 'headers.dart';
import 'info.dart';
import 'geteps.dart';
import '../extractors/stream_types.dart';

class CastleGetStream {
  // Get video URL using v2.0.1 getVideo2 (shared streams)
  static Future<Map<String, dynamic>> getVideo2(
    String securityKey,
    String movieId,
    String episodeId, {
    int resolution = 2,
  }) async {
    print(
      '[Castle] Fetching video (v2) for movieId: $movieId, episodeId: $episodeId, resolution: $resolution',
    );

    final url =
        '${CastleCatalog.baseUrl}/film-api/v2.0.1/movie/getVideo2?clientType=${CastleCatalog.client}&packageName=${CastleCatalog.pkg}&channel=${CastleCatalog.channel}&lang=${CastleCatalog.lang}';

    final body = {
      'mode': '1',
      'appMarket': 'GuanWang',
      'clientType': '1',
      'woolUser': 'false',
      'apkSignKey': 'ED0955EB04E67A1D9F3305B95454FED485261475',
      'androidVersion': '13',
      'movieId': movieId,
      'episodeId': episodeId,
      'isNewUser': 'true',
      'resolution': resolution.toString(),
      'packageName': CastleCatalog.pkg,
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          ...CastleHeaders.workingHeaders,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
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
      print('[Castle] Get video v2 failed: $e');
      rethrow;
    }
  }

  // Get video URL using v1.9.1 getVideo (language-specific)
  static Future<Map<String, dynamic>> getVideoV1(
    String securityKey,
    String movieId,
    String episodeId,
    String languageId, {
    int resolution = 2,
  }) async {
    print(
      '[Castle] Fetching video (v1) for movieId: $movieId, episodeId: $episodeId, languageId: $languageId, resolution: $resolution',
    );

    final params = {
      'apkSignKey': 'ED0955EB04E67A1D9F3305B95454FED485261475',
      'channel': CastleCatalog.channel,
      'clientType': CastleCatalog.client,
      'episodeId': episodeId,
      'lang': CastleCatalog.lang,
      'languageId': languageId,
      'mode': '1',
      'movieId': movieId,
      'packageName': CastleCatalog.pkg,
      'resolution': resolution.toString(),
    };

    final uri = Uri.parse(
      '${CastleCatalog.baseUrl}/film-api/v1.9.1/movie/getVideo',
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

      final cipher = CastleCatalog.extractCipherFromResponse(response.body);
      final decrypted = await CastleCatalog.decryptCastle(cipher, securityKey);
      return jsonDecode(decrypted);
    } catch (e) {
      print('[Castle] Get video v1 failed: $e');
      rethrow;
    }
  }

  // Get quality value for sorting (higher = better quality)
  static int getQualityValue(String? quality) {
    if (quality == null || quality.isEmpty) return 0;

    // Remove common prefixes and clean up
    final cleanQuality = quality
        .toLowerCase()
        .replaceAll(RegExp(r'^(sd|hd|fhd|uhd|4k)\s*', caseSensitive: false), '')
        .replaceAll('p', '')
        .trim();

    // Handle specific quality names
    if (cleanQuality == '4k' || cleanQuality == '2160') return 2160;
    if (cleanQuality == '1440') return 1440;
    if (cleanQuality == '1080') return 1080;
    if (cleanQuality == '720') return 720;
    if (cleanQuality == '480') return 480;
    if (cleanQuality == '360') return 360;
    if (cleanQuality == '240') return 240;

    // Try to parse as number
    final numQuality = int.tryParse(cleanQuality);
    if (numQuality != null && numQuality > 0) {
      return numQuality;
    }

    // Unknown quality goes last
    return 0;
  }

  // Process video response and extract streams
  static List<Stream> processVideoResponse(
    Map<String, dynamic> videoData,
    Map<String, dynamic> mediaInfo,
    int? seasonNum,
    int? episodeNum,
    int resolution,
    String? languageInfo,
  ) {
    final streams = <Stream>[];
    final data = CastleInfo.extractDataBlock(videoData);

    // Extract video URL
    final videoUrl = data['videoUrl'];
    if (videoUrl == null) {
      print('[Castle] No videoUrl found in response');
      return streams;
    }

    // Map resolution number to quality string
    final qualityMap = {1: '480p', 2: '720p', 3: '1080p'};
    final quality = qualityMap[resolution] ?? '${resolution}p';

    // Check if there are multiple quality videos
    if (data['videos'] != null && data['videos'] is List) {
      for (final video in data['videos']) {
        // Clean up quality to remove SD/HD/FHD prefixes
        String videoQuality =
            video['resolutionDescription'] ?? video['resolution'] ?? quality;
        videoQuality = videoQuality.replaceAll(
          RegExp(r'^(SD|HD|FHD)\s+', caseSensitive: false),
          '',
        );

        final streamName = languageInfo != null
            ? 'Castle $languageInfo - $videoQuality'
            : 'Castle - $videoQuality';

        streams.add(
          Stream(
            server: streamName,
            link: video['url'] ?? videoUrl,
            type: 'video',
            headers: CastleHeaders.playbackHeaders,
          ),
        );
      }
    } else {
      final streamName = languageInfo != null
          ? 'Castle $languageInfo - $quality'
          : 'Castle - $quality';

      streams.add(
        Stream(
          server: streamName,
          link: videoUrl,
          type: 'video',
          headers: CastleHeaders.playbackHeaders,
        ),
      );
    }

    return streams;
  }

  // Main function to extract streaming links
  static Future<List<Stream>> getStreams(
    String tmdbId,
    String mediaType, {
    int? seasonNum,
    int? episodeNum,
  }) async {
    print(
      '[Castle] Starting extraction for TMDB ID: $tmdbId, Type: $mediaType${mediaType == 'tv' && seasonNum != null && episodeNum != null ? ', S:${seasonNum}E:$episodeNum' : ''}',
    );

    try {
      // Step 1: Get episode details using CastleGetEps instead of calling API
      Map<String, dynamic>? episodeData;
      
      if (mediaType == 'tv' && seasonNum != null && episodeNum != null) {
        // Get specific episode
        episodeData = await CastleGetEps.getEpisode(
          tmdbId: tmdbId,
          mediaType: mediaType,
          seasonNum: seasonNum,
          episodeNum: episodeNum,
        );
      } else {
        // Get all episodes (for movies, will return single episode)
        final allEpisodes = await CastleGetEps.getEpisodes(
          tmdbId: tmdbId,
          mediaType: mediaType,
        );
        
        final episodes = List.from(allEpisodes['episodes'] ?? []);
        if (episodes.isNotEmpty) {
          episodeData = episodes[0] as Map<String, dynamic>;
        }
      }

      if (episodeData == null) {
        throw Exception('Could not find episode data');
      }

      // Extract required data  
      final currentMovieId = episodeData['movieId'] as String;
      final episodeId = episodeData['episodeId'] as String;
      
      // Safely extract and convert tracks
      List<Map<String, dynamic>> tracks = [];
      try {
        final tracksList = List.from(episodeData['tracks'] ?? []);
        
        for (final track in tracksList) {
          if (track is Map) {
            tracks.add(Map<String, dynamic>.from(track));
          }
        }
      } catch (e) {
        print('[Castle] ERROR converting tracks: $e');
        rethrow;
      }

      print(
        '[Castle] Using movieId: $currentMovieId, episodeId: $episodeId',
      );

      // Get TMDB info for title display
      final tmdbInfo = await CastleCatalog.getTMDBDetails(tmdbId, mediaType);

      // Get security key
      final securityKey = await CastleCatalog.getSecurityKey();

      // Step 2: Check for language-specific tracks
      final hasIndividualVideo = tracks.any((t) => t['existIndividualVideo'] == true);

      print('[Castle] Found ${tracks.length} tracks, hasIndividualVideo: $hasIndividualVideo');

      // Step 3: Get video URLs for ALL available languages
      const resolution = 2; // Default to 720p
      final allStreams = <Stream>[];

      // Process all language tracks
      if (hasIndividualVideo) {
        for (final track in tracks) {
          if (track['existIndividualVideo'] == true &&
              track['languageId'] != null) {
            final langName = track['languageName'] ?? track['abbreviate'] ?? 'Unknown';

            try {
              print(
                '[Castle] Fetching $langName (v1, languageId: ${track['languageId']})',
              );

              final videoData = await getVideoV1(
                securityKey,
                currentMovieId,
                episodeId,
                track['languageId'].toString(),
                resolution: resolution,
              );

              final langStreams = processVideoResponse(
                videoData,
                tmdbInfo,
                seasonNum,
                episodeNum,
                resolution,
                '[$langName]',
              );

              if (langStreams.isNotEmpty) {
                print('[Castle] ✅ $langName: Found ${langStreams.length} streams');
                allStreams.addAll(langStreams);
              } else {
                print('[Castle] ⚠️  $langName: v1 returned no streams');
              }
            } catch (e) {
              print('[Castle] ⚠️  $langName: v1 failed - $e');
            }
          }
        }
      }

      // Fallback: Use shared stream (v2) if no individual videos worked
      if (allStreams.isEmpty) {
        print(
          '[Castle] No individual videos available, using shared stream (v2)',
        );
        try {
          final videoData = await getVideo2(
            securityKey,
            currentMovieId,
            episodeId,
            resolution: resolution,
          );

          final sharedStreams = processVideoResponse(
            videoData,
            tmdbInfo,
            seasonNum,
            episodeNum,
            resolution,
            '[Shared]',
          );

          allStreams.addAll(sharedStreams);
        } catch (e) {
          print('[Castle] Shared stream (v2) failed: $e');
        }
      }

      print('[Castle] Total streams found: ${allStreams.length}');

      // Sort streams by quality (highest first)
      allStreams.sort((a, b) {
        final qualityA = getQualityValue(a.server.split('-').last.trim());
        final qualityB = getQualityValue(b.server.split('-').last.trim());
        return qualityB.compareTo(qualityA);
      });

      return allStreams;
    } catch (e) {
      print('[Castle] Error: $e');
      return []; // Return empty array on error
    }
  }
}
