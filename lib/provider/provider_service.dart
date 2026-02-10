import '../models/movie_info.dart';
import 'extractors/stream_types.dart' as stream_types;

/// Abstract class defining the interface for all provider services
abstract class ProviderService {
  /// Fetch movie information from the provider
  Future<MovieInfo> fetchMovieInfo(String movieUrl);

  /// Process download URL (e.g., for gadgetsweb.xyz links)
  /// By default, returns the URL as-is
  Future<String> processDownloadUrl(String url) async {
    return url;
  }

  /// Load episodes for a given download URL
  /// Returns empty list if provider doesn't support episodes
  Future<List<Episode>> loadEpisodes(String downloadUrl) async {
    return [];
  }

  /// Get streaming links from a download link or episode
  Future<List<stream_types.Stream>> getStreams(String url, String quality);

  /// Check if this provider should skip episode fetching for certain URLs
  bool shouldSkipEpisodeFetch(String url) {
    return url.contains('hubcloud');
  }
}
