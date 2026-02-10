import '../provider_service.dart';
import '../../models/movie_info.dart';
import '../xdmovies/index.dart';
import '../extractors/stream_types.dart' as stream_types;

class XdmoviesProviderService extends ProviderService {
  @override
  Future<MovieInfo> fetchMovieInfo(String movieUrl) {
    return XdmoviesInfo.fetchMovieInfo(movieUrl);
  }

  @override
  Future<List<stream_types.Stream>> getStreams(String url, String quality) {
    return xdmoviesGetStream(url, quality);
  }
}
