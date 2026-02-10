import '../provider_service.dart';
import '../../models/movie_info.dart';
import '../extractors/stream_types.dart';
import 'info.dart';
import 'geteps.dart';
import 'getstream.dart';

class NfProviderService extends ProviderService {
  @override
  Future<MovieInfo> fetchMovieInfo(String movieUrl) {
    return NfInfo.fetchMovieInfo(movieUrl);
  }

  @override
  Future<List<Episode>> loadEpisodes(String downloadUrl) {
    return NfGetEps.fetchEpisodes(downloadUrl);
  }

  @override
  Future<List<Stream>> getStreams(String url, String quality) {
    return NfGetStream.getStreams(url, quality);
  }

  @override
  bool shouldSkipEpisodeFetch(String url) {
    // For NF, we never skip episode fetching since we handle series properly
    return false;
  }
}
