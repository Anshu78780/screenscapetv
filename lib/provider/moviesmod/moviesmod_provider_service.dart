import '../provider_service.dart';
import '../../models/movie_info.dart';
import '../moviesmod/index.dart';
import '../extractors/stream_types.dart' as stream_types;

class MoviesmodProviderService extends ProviderService {
  @override
  Future<MovieInfo> fetchMovieInfo(String movieUrl) {
    return MoviesmodInfo.fetchMovieInfo(movieUrl);
  }

  @override
  Future<List<Episode>> loadEpisodes(String downloadUrl) async {
    final episodeData = await MoviesmodGetEpisodes.getEpisodeLinks(downloadUrl);
    return episodeData
        .map((ep) => Episode(title: ep['title']!, link: ep['link']!))
        .toList();
  }

  @override
  Future<List<stream_types.Stream>> getStreams(String url, String quality) {
    return moviesmodGetStream(url);
  }
}
