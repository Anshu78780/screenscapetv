import '../provider_service.dart';
import '../../models/movie_info.dart';
import '../filmycab/info.dart' as filmycab_info;
import '../filmycab/getstream.dart' as filmycab_stream;
import '../extractors/stream_types.dart' as stream_types;

class FilmycabProviderService extends ProviderService {
  @override
  Future<MovieInfo> fetchMovieInfo(String movieUrl) {
    return filmycab_info.FilmyCabInfo.fetchMovieInfo(movieUrl);
  }

  @override
  Future<List<stream_types.Stream>> getStreams(String url, String quality) {
    return filmycab_stream.filmyCabGetStream(url, quality);
  }
}
