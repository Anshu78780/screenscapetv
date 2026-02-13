import '../provider_service.dart';
import '../../models/movie_info.dart';
import '../extractors/stream_types.dart';
import 'info.dart';
import 'getstream.dart';

/// Castle Provider Service - delegates to specialized modules
class CastleProviderService extends ProviderService {
  @override
  Future<MovieInfo> fetchMovieInfo(String movieUrl) {
    return CastleInfo.fetchMovieInfo(movieUrl);
  }

  @override
  Future<List<Episode>> loadEpisodes(String downloadUrl) async {
    // Episodes are already loaded in fetchMovieInfo
    return [];
  }

  @override
  Future<List<Stream>> getStreams(String url, String quality) async {
    try {
      final parsed = CastleInfo.parseCastleUrl(url);
      final tmdbId = parsed['tmdbId'] as String;
      final mediaType = parsed['mediaType'] as String;
      final seasonNum = parsed['season'] as int?;
      final episodeNum = parsed['episode'] as int?;

      final streams = await CastleGetStream.getStreams(
        tmdbId,
        mediaType,
        seasonNum: seasonNum,
        episodeNum: episodeNum,
      );

      // Sort by quality (highest first)
      streams.sort((a, b) {
        final qualityA = CastleGetStream.getQualityValue(
          a.server.split('-').last.trim(),
        );
        final qualityB = CastleGetStream.getQualityValue(
          b.server.split('-').last.trim(),
        );
        return qualityB.compareTo(qualityA);
      });

      return streams;
    } catch (e) {
      print('[CastleProvider] Failed to get streams: $e');
      return [];
    }
  }

  @override
  bool shouldSkipEpisodeFetch(String url) {
    return true;
  }
}
