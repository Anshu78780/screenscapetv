import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../provider_service.dart';
import '../../models/movie_info.dart';
import '../drive/index.dart';
import '../extractors/stream_types.dart' as stream_types;

class DriveProviderService extends ProviderService {
  static const Map<String, String> headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.5',
  };

  @override
  Future<MovieInfo> fetchMovieInfo(String movieUrl) {
    return MovieInfoParser.fetchMovieInfo(movieUrl);
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
    // Check if this is an mdrive/moviesdrive page with provider links
    if (url.contains('mdrive.') || url.contains('moviesdrive')) {
      return await _extractFromProviderPage(url);
    }
    
    // Default behavior: extract using HubCloud extractor
    final result = await HubCloudExtractor.extractLinks(url);
    return result.success ? result.streams : [];
  }

  Future<List<stream_types.Stream>> _extractFromProviderPage(String url) async {
    try {
      print('Extracting provider links from page: $url');
      final response = await http.get(Uri.parse(url), headers: headers);
      
      if (response.statusCode != 200) {
        print('Failed to load provider page: ${response.statusCode}');
        return [];
      }

      final document = html_parser.parse(response.body);
      final allStreams = <stream_types.Stream>[];
      final futures = <Future>[];

      // Find all provider links (hubcloud, gdflix, etc.)
      final providerLinks = document.querySelectorAll('a[href*="hubcloud"], a[href*="gdflix"]');
      
      print('Found ${providerLinks.length} provider links on page');

      for (var linkElement in providerLinks) {
        final href = linkElement.attributes['href'];
        if (href == null || href.isEmpty) continue;

        print('Processing provider link: $href');

        if (href.contains('hubcloud')) {
          // Extract from hubcloud
          futures.add(_extractHubCloudStreams(href, allStreams));
        } else if (href.contains('gdflix')) {
          // Extract from gdflix
          futures.add(_extractGdFlixStreams(href, allStreams));
        }
      }

      // Wait for all extractions to complete
      await Future.wait(futures);

      print('Total streams extracted from all providers: ${allStreams.length}');
      return allStreams;
    } catch (e) {
      print('Error extracting from provider page: $e');
      // Fallback to default extraction
      final result = await HubCloudExtractor.extractLinks(url);
      return result.success ? result.streams : [];
    }
  }

  Future<void> _extractHubCloudStreams(
    String url,
    List<stream_types.Stream> allStreams,
  ) async {
    try {
      print('Extracting HubCloud streams from: $url');
      final result = await HubCloudExtractor.extractLinks(url);
      if (result.success && result.streams.isNotEmpty) {
        print('Extracted ${result.streams.length} streams from HubCloud');
        allStreams.addAll(result.streams);
      } else {
        print('No streams found from HubCloud');
      }
    } catch (e) {
      print('Error extracting HubCloud streams: $e');
    }
  }

  Future<void> _extractGdFlixStreams(
    String url,
    List<stream_types.Stream> allStreams,
  ) async {
    try {
      print('Extracting GDFlix streams from: $url');
      final streams = await GdFlixExtractor.extractStreams(url);
      if (streams.isNotEmpty) {
        print('Extracted ${streams.length} streams from GDFlix');
        allStreams.addAll(streams);
      } else {
        print('No streams found from GDFlix');
      }
    } catch (e) {
      print('Error extracting GDFlix streams: $e');
    }
  }
}
