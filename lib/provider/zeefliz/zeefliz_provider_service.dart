import '../provider_service.dart';
import '../../models/movie_info.dart';
import '../zeefliz/info.dart' as zeefliz_info;
import '../zeefliz/getstream.dart' as zeefliz_stream;
import '../zeefliz/geteps.dart' as zeefliz_eps;
import '../extractors/stream_types.dart' as stream_types;

class ZeeflizProviderService extends ProviderService {
  @override
  Future<MovieInfo> fetchMovieInfo(String movieUrl) {
    return zeefliz_info.ZeeflizInfo.fetchMovieInfo(movieUrl);
  }

  @override
  Future<List<Episode>> loadEpisodes(String downloadUrl) {
    return zeefliz_eps.ZeeflizGetEps.fetchEpisodes(downloadUrl);
  }

  @override
  Future<List<stream_types.Stream>> getStreams(String url, String quality) {
    return zeefliz_stream.zeeflizGetStream(url, quality);
  }
}
