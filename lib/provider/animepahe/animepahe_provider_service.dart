import '../provider_service.dart';
import '../../models/movie_info.dart';
import '../animepahe/info.dart' as animepahe_info;
import '../animepahe/getstream.dart' as animepahe_stream;
import '../extractors/stream_types.dart' as stream_types;

class AnimePaheProviderService extends ProviderService {
  @override
  Future<MovieInfo> fetchMovieInfo(String movieUrl) {
    return animepahe_info.animepaheGetInfo(movieUrl);
  }

  @override
  Future<List<stream_types.Stream>> getStreams(String url, String quality) {
    return animepahe_stream.animepaheGetStream(url, quality);
  }
}
