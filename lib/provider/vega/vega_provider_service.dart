import '../provider_service.dart';
import '../../models/movie_info.dart';
import '../vega/info.dart' as vega_info;
import '../vega/geteps.dart' as vega_eps;
import '../vega/getstream.dart' as vega_stream;
import '../extractors/stream_types.dart' as stream_types;

class VegaProviderService extends ProviderService {
  @override
  Future<MovieInfo> fetchMovieInfo(String movieUrl) {
    return vega_info.vegaGetInfo(movieUrl);
  }

  @override
  Future<List<Episode>> loadEpisodes(String downloadUrl) async {
    // Handle pipe-delimited URLs (G-Direct|V-Cloud)
    if (downloadUrl.contains('|')) {
      print('Processing multiple episode URLs (G-Direct + V-Cloud)');
      final urls = downloadUrl.split('|');
      final episodeMap = <String, String>{}; // title -> combined links

      // Fetch episodes from each URL
      for (final url in urls) {
        if (url.trim().isEmpty) continue;

        try {
          print('Fetching from: $url');
          final vegaEps = await vega_eps.vegaGetEpisodeLinks(url.trim());

          for (final ep in vegaEps) {
            if (episodeMap.containsKey(ep.title)) {
              // Merge links with pipe delimiter
              episodeMap[ep.title] = '${episodeMap[ep.title]}|${ep.link}';
            } else {
              episodeMap[ep.title] = ep.link;
            }
          }
        } catch (e) {
          print('Error fetching from $url: $e');
        }
      }

      // Convert map to episodes list
      return episodeMap.entries
          .map((e) => Episode(title: e.key, link: e.value))
          .toList();
    } else {
      // Single URL
      final vegaEps = await vega_eps.vegaGetEpisodeLinks(downloadUrl);
      return vegaEps.map((e) => Episode(title: e.title, link: e.link)).toList();
    }
  }

  @override
  Future<List<stream_types.Stream>> getStreams(String url, String quality) {
    return vega_stream.vegaGetStream(url, quality);
  }
}
