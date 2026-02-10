import '../provider_service.dart';
import '../../models/movie_info.dart';
import '../animesalt/info.dart' as animesalt_info;
import '../animesalt/getstream.dart' as animesalt_stream;
import '../extractors/stream_types.dart' as stream_types;

class AnimesaltProviderService extends ProviderService {
  @override
  Future<MovieInfo> fetchMovieInfo(String movieUrl) {
    return animesalt_info.animesaltGetInfo(movieUrl);
  }

  @override
  Future<List<stream_types.Stream>> getStreams(String url, String quality) {
    return animesalt_stream.animesaltGetStream(url, quality);
  }
}
