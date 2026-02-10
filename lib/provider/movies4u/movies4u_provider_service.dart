import '../provider_service.dart';
import '../../models/movie_info.dart';
import '../movies4u/index.dart';
import '../extractors/stream_types.dart' as stream_types;
import '../drive/index.dart';

class Movies4uProviderService extends ProviderService {
  @override
  Future<MovieInfo> fetchMovieInfo(String movieUrl) {
    return Movies4uInfo.fetchMovieInfo(movieUrl);
  }

  @override
  Future<List<Episode>> loadEpisodes(String downloadUrl) {
    return Movies4uGetEps.fetchEpisodes(downloadUrl);
  }

  @override
  Future<List<stream_types.Stream>> getStreams(
    String url,
    String quality,
  ) async {
    final result = await HubCloudExtractor.extractLinks(url);
    return result.success ? result.streams : [];
  }
}
