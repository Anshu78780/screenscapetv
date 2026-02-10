import '../provider_service.dart';
import '../../models/movie_info.dart';
import '../drive/index.dart';
import '../extractors/stream_types.dart' as stream_types;

class DriveProviderService extends ProviderService {
  @override
  Future<MovieInfo> fetchMovieInfo(String movieUrl) {
    return MovieInfoParser.fetchMovieInfo(movieUrl);
  }

  @override
  Future<List<Episode>> loadEpisodes(String downloadUrl) {
    return EpisodeParser.fetchEpisodes(downloadUrl);
  }

  @override
  Future<List<stream_types.Stream>> getStreams(
    String url,
    String quality,
  ) async {
    // Default behavior: extract using HubCloud extractor
    final result = await HubCloudExtractor.extractLinks(url);
    return result.success ? result.streams : [];
  }
}
