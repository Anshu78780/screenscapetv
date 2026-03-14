import 'dart:async';

import '../models/movie_info.dart';
import 'extractors/stream_types.dart' as stream_types;
import 'extractors/vcloud_extractor.dart';
import 'drive/index.dart';
import 'provider_service.dart';

/// Helper class for extracting streams from episode links
class EpisodeStreamExtractor {
  /// Extract streams from an episode using all available links
  static Future<List<stream_types.Stream>> extractStreams(
    Episode episode,
    ProviderService providerService,
    String quality,
    {
    Duration timeout = const Duration(seconds: 60),
  }
  ) async {
    final List<stream_types.Stream> allStreams = [];

    // If episode has multiple links, process all of them
    if (episode.links != null && episode.links!.isNotEmpty) {
      print(
        'Processing ${episode.links!.length} links for episode: ${episode.title}',
      );

      final completer = Completer<List<stream_types.Stream>>();
      var pending = episode.links!.length;

      final timeoutTimer = Timer(timeout, () {
        if (!completer.isCompleted) {
          print(
            'Episode extraction timeout reached (${timeout.inSeconds}s), returning partial streams: ${allStreams.length}',
          );
          completer.complete(_dedupeByLink(allStreams));
        }
      });

      for (final episodeLink in episode.links!) {
        () async {
          try {
            print('Processing ${episodeLink.server} link: ${episodeLink.url}');

            // Process each server link independently so slow links don't block others.
            final processedLink = await providerService
                .processDownloadUrl(episodeLink.url)
                .timeout(
                  const Duration(seconds: 45),
                  onTimeout: () {
                    throw TimeoutException(
                      'Timed out while processing ${episodeLink.server} URL',
                    );
                  },
                );

            final streams = await _extractFromServer(
              episodeLink.server,
              processedLink,
            ).timeout(
              const Duration(seconds: 45),
              onTimeout: () => <stream_types.Stream>[],
            );

            if (streams.isNotEmpty) {
              print('${episodeLink.server} extracted ${streams.length} streams');
              allStreams.addAll(streams);
            }
          } catch (e) {
            print('Error extracting from ${episodeLink.server}: $e');
            // Continue to next link even if this one fails.
          } finally {
            pending--;
            if (pending <= 0 && !completer.isCompleted) {
              completer.complete(_dedupeByLink(allStreams));
            }
          }
        }();
      }

      final result = await completer.future;
      timeoutTimer.cancel();
      return result;
    } else {
      // Fallback: Use primary link
      print('Using primary link: ${episode.link}');

      // Use provider service to get streams
      final streams = await providerService
          .getStreams(episode.link, quality)
          .timeout(timeout, onTimeout: () => <stream_types.Stream>[]);
      if (streams.isNotEmpty) {
        allStreams.addAll(streams);
      }
    }

    return _dedupeByLink(allStreams);
  }

  static List<stream_types.Stream> _dedupeByLink(
    List<stream_types.Stream> streams,
  ) {
    final seen = <String>{};
    final deduped = <stream_types.Stream>[];
    for (final stream in streams) {
      if (stream.link.isEmpty || seen.contains(stream.link)) continue;
      seen.add(stream.link);
      deduped.add(stream);
    }
    return deduped;
  }

  /// Extract streams from a specific server type
  static Future<List<stream_types.Stream>> _extractFromServer(
    String server,
    String url,
  ) async {
    switch (server) {
      case 'VCloud':
        print('Extracting streams from VCloud: $url');
        return await VCloudExtractor.extractStreams(url);

      case 'GDFlix':
        print('Extracting streams from GDFlix: $url');
        return await GdFlixExtractor.extractStreams(url);

      case 'HubCloud':
        print('Extracting streams from HubCloud: $url');
        final result = await HubCloudExtractor.extractLinks(url);
        return result.success ? result.streams : [];

      default:
        print('Unknown server type: $server');
        return [];
    }
  }

  /// Extract streams from a processed URL (handles direct links)
  static Future<List<stream_types.Stream>> extractFromDirectLink(
    String processedUrl,
  ) async {
    List<stream_types.Stream> allStreams = [];

    if (processedUrl.contains('vcloud.zip') ||
        processedUrl.contains('vcloud.lol')) {
      print('Processing VCloud link');
      final streams = await VCloudExtractor.extractStreams(processedUrl);
      if (streams.isNotEmpty) {
        allStreams.addAll(streams);
      }
    } else if (processedUrl.contains('gdflix')) {
      print('Processing GDFlix link');
      final streams = await GdFlixExtractor.extractStreams(processedUrl);
      if (streams.isNotEmpty) {
        allStreams.addAll(streams);
      }
    } else if (processedUrl.contains('hubcloud')) {
      print('Processing HubCloud link');
      final result = await HubCloudExtractor.extractLinks(processedUrl);
      if (result.success && result.streams.isNotEmpty) {
        allStreams.addAll(result.streams);
      }
    }

    return allStreams;
  }
}
