import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../../models/movie_info.dart';
import 'headers.dart';

class ZeeflizGetEps {
  static Future<List<Episode>> fetchEpisodes(String episodeUrl) async {
    try {
      print('ZeeflizGetEps called with URL: $episodeUrl');

      // Check if URL contains multiple links separated by |
      final urlParts = episodeUrl
          .split('|')
          .where((u) => u.trim().isNotEmpty)
          .toList();

      if (urlParts.length > 1) {
        print('Found ${urlParts.length} sources to process');

        // Process all sources and combine episodes
        final allEpisodesMap = <String, Episode>{};

        for (var url in urlParts) {
          print('Processing source: $url');
          final episodes = await _fetchEpisodesFromUrl(url);

          // Merge episodes by episode number
          for (var episode in episodes) {
            final episodeKey = episode.title;
            if (allEpisodesMap.containsKey(episodeKey)) {
              // Combine links from both sources
              final existing = allEpisodesMap[episodeKey]!;
              allEpisodesMap[episodeKey] = Episode(
                title: existing.title,
                link: '${existing.link}|${episode.link}',
              );
            } else {
              allEpisodesMap[episodeKey] = episode;
            }
          }
        }

        final combinedEpisodes = allEpisodesMap.values.toList();
        print('Total combined episodes: ${combinedEpisodes.length}');
        return combinedEpisodes;
      }

      // Single URL - process normally
      return await _fetchEpisodesFromUrl(episodeUrl);
    } catch (e) {
      print('Error in ZeeflizGetEps.fetchEpisodes: $e');
      return [];
    }
  }

  /// Helper function to fetch episodes from a single URL
  static Future<List<Episode>> _fetchEpisodesFromUrl(String episodeUrl) async {
    try {
      print('Fetching episodes from: $episodeUrl');

      // Replace .store with .pro before making request
      final processedUrl = episodeUrl.replaceAll('.store', '.pro');
      print('Using URL: $processedUrl');

      // Headers with cookie for nexdrive requests
      final headers = {
        ...ZeeflizHeaders.headers,
        'Cookie':
            'cf_clearance=zsirOToaYYHyKzG0lLu53DQWxAy9VKfY8Didq3.lFgM-1760163290-1.2.1.1-4JoxRLs9VLMeT98JVrbEQI_mtQHC5G5_K8yzmak.ViPhW80xbjaF3ZCgmwxwdibrTUQOY0X5OkP514zlmEOC7H.eNNed7xjn0.HRu.EawKP5mAWXEUwQOZXg.lSCS.0zzRs0nMwxQzeaHA2Ca5EPQqsDsZfOTvNKl.SzIZLduAHSKEMVEFQEhUwWYzTHvEiIuHM2iyjDBbJK0C3SuvqrIL9eL46THMJt1HTyTAebgVw; _ga=GA1.1.1073834037.1760163421; _ga_X3GWT6NQ1N=GS2.1.s1760163421\$o1\$g1\$t1760167039\$j60\$l0\$h0; prefetchAd_9457774=true',
      };

      final response = await http.get(
        Uri.parse(processedUrl),
        headers: headers,
      );

      if (response.statusCode != 200) {
        print('Failed to fetch episodes: ${response.statusCode}');
        return [];
      }

      final document = html_parser.parse(response.body);
      final episodes = <Episode>[];

      // Remove unwanted elements that might interfere
      document
          .querySelectorAll('.unili-content, .code-block-1, .bkmkzeefliz')
          .forEach((el) => el.remove());

      // Look for episode sections (h4 with "Episodes:" text)
      final h4Elements = document.querySelectorAll('h4');

      for (var h4 in h4Elements) {
        final episodeText = h4.text;

        // Match various episode patterns: "-:Episodes: 1:-", "Episodes 01", "Episode 1", etc.
        final episodeMatch = RegExp(
          r'Episodes?[:\s]*(\d+)',
          caseSensitive: false,
        ).firstMatch(episodeText);

        if (episodeMatch != null) {
          final episodeNumber = episodeMatch.group(1);
          final nextP = h4.nextElementSibling;

          if (nextP != null && nextP.localName == 'p') {
            // Priority 1: Look for zcloud.lol links (V-Cloud/Zee-Cloud Resumable)
            String? downloadLink;
            final links = nextP.querySelectorAll('a');

            for (var linkEl in links) {
              final href = linkEl.attributes['href'];
              final button = linkEl.querySelector('button');
              final buttonText = button?.text.toLowerCase() ?? '';
              final buttonStyle = button?.attributes['style'] ?? '';

              // Check for V-Cloud/Zee-Cloud with red-orange gradient or zcloud.lol URL
              if (href != null &&
                  (href.contains('zcloud.lol') ||
                      buttonText.contains('v-cloud') ||
                      buttonText.contains('zee-cloud') ||
                      buttonText.contains('resumable') ||
                      buttonStyle.contains('#ed0b0b') ||
                      buttonStyle.contains('#f2d152'))) {
                downloadLink = href;
                break;
              }
            }

            // Priority 2: Look for zee-cloud links
            downloadLink ??= nextP
                  .querySelector('a[href*="zee-cloud"]')
                  ?.attributes['href'];

            // Priority 3: Look for zee-dl links
            downloadLink ??= nextP
                  .querySelector('a[href*="zee-dl"]')
                  ?.attributes['href'];

            // Fallback: First link found
            downloadLink ??= nextP.querySelector('a')?.attributes['href'];

            if (downloadLink != null) {
              print('Episode $episodeNumber: $downloadLink');
              episodes.add(
                Episode(title: 'Episode $episodeNumber', link: downloadLink),
              );
            }
          }
        }
      }

      print('Found ${episodes.length} episodes');
      return episodes;
    } catch (e) {
      print('Error in _fetchEpisodesFromUrl: $e');
      return [];
    }
  }
}
