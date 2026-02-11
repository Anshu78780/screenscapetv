import '../provider_service.dart';
import '../../models/movie_info.dart';
import '../yomovies/info.dart' as yomovies_info;
import '../yomovies/getstream.dart' as yomovies_stream;
import '../extractors/stream_types.dart' as stream_types;

class YoMoviesProviderService extends ProviderService {
  @override
  Future<MovieInfo> fetchMovieInfo(String movieUrl) {
    return yomovies_info.yoMoviesGetInfo(movieUrl);
  }

  @override
  Future<List<stream_types.Stream>> getStreams(String url, String quality) {
    return yomovies_stream.yoMoviesGetStream(url, quality);
  }
}
