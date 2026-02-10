import '../provider_service.dart';
import '../../models/movie_info.dart';
import '../desiremovies/index.dart';
import '../extractors/stream_types.dart' as stream_types;

class DesireMoviesProviderService extends ProviderService {
  @override
  Future<MovieInfo> fetchMovieInfo(String movieUrl) {
    return DesireMoviesInfo.fetchMovieInfo(movieUrl);
  }

  @override
  Future<List<stream_types.Stream>> getStreams(String url, String quality) {
    return desireMoviesGetStream(url, quality);
  }
}
