import '../provider_service.dart';
import '../../models/movie_info.dart';
import '../khdhub/info.dart' as khdhub_info;
import '../khdhub/getstream.dart' as khdhub_stream;
import '../extractors/stream_types.dart' as stream_types;

class KhdHubProviderService extends ProviderService {
  @override
  Future<MovieInfo> fetchMovieInfo(String movieUrl) {
    return khdhub_info.khdHubGetInfo(movieUrl);
  }

  @override
  Future<List<stream_types.Stream>> getStreams(String url, String quality) {
    return khdhub_stream.khdHubGetStream(url, quality);
  }
}
