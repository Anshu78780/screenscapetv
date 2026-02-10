import '../provider_service.dart';
import '../../models/movie_info.dart';
import '../zinkmovies/info.dart' as zinkmovies_info;
import '../zinkmovies/getstream.dart' as zinkmovies_stream;
import '../extractors/stream_types.dart' as stream_types;

class ZinkmoviesProviderService extends ProviderService {
  @override
  Future<MovieInfo> fetchMovieInfo(String movieUrl) {
    return zinkmovies_info.fetchMovieInfo(movieUrl);
  }

  @override
  Future<List<stream_types.Stream>> getStreams(String url, String quality) {
    return zinkmovies_stream.getStream(url, quality);
  }
}
