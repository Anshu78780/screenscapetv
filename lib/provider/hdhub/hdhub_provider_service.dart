import '../provider_service.dart';
import '../../models/movie_info.dart';
import '../hdhub/index.dart';
import '../drive/index.dart';
import '../extractors/stream_types.dart' as stream_types;

class HdhubProviderService extends ProviderService {
  @override
  Future<MovieInfo> fetchMovieInfo(String movieUrl) {
    return HdhubInfoParser.fetchMovieInfo(movieUrl);
  }

  @override
  Future<String> processDownloadUrl(String url) async {
    // Only call external API for gadgetsweb.xyz links
    if (url.contains('gadgetsweb.xyz') && url.contains('?id=')) {
      try {
        print('Processing gadgetsweb.xyz URL with external API: $url');
        final processedUrl = await getRedirectLinks(url);
        print('Got processed URL from API: $processedUrl');
        return processedUrl;
      } catch (e) {
        print('Error processing gadgetsweb URL: $e');
        return url;
      }
    }
    return url;
  }

  @override
  Future<List<Episode>> loadEpisodes(String downloadUrl) {
    return EpisodeParser.fetchEpisodes(downloadUrl);
  }

  @override
  Future<List<stream_types.Stream>> getStreams(
    String url,
    String quality,
  ) async {
    final result = await HubCloudExtractor.extractLinks(url);
    return result.success ? result.streams : [];
  }
}
