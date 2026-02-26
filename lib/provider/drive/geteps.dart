import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import '../../models/movie_info.dart';

class EpisodeParser {
  static Future<List<Episode>> fetchEpisodes(String url) async {
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      return parseEpisodes(response.body);
    } else {
      throw Exception('Failed to load episodes: ${response.statusCode}');
    }
  }

  static List<Episode> parseEpisodes(String htmlContent) {
    final document = html_parser.parse(htmlContent);
    final List<Episode> episodes = [];

    // Find headers containing Episode info (e.g. "Ep1", "Ep2")
    final headers = document.querySelectorAll('h5');

    for (var i = 0; i < headers.length; i++) {
      final header = headers[i];
      final text = header.text.trim();

      // Check if header indicates an episode (e.g., "Ep1", "Ep 1", "Episode 1")
      // Using regex to match "Ep" followed optionally by space and then digits
      if (RegExp(r'Ep\s?\d+', caseSensitive: false).hasMatch(text)) {
        // Extract episode title and size
        String title = text.replaceAll(RegExp(r'\s+'), ' ').trim();

        // Extract episode number for clean title
        final titleMatch = RegExp(
          r'(Ep\s?\d+)',
          caseSensitive: false,
        ).firstMatch(text);
        String episodeTitle = titleMatch?.group(0) ?? title;

        // Extract size info from the episode header
        String? episodeSize;
        final sizeMatch = RegExp(r'\[(.*?)\]').firstMatch(text);
        if (sizeMatch != null) {
          episodeSize = sizeMatch.group(1);
        }

        // Look for both HubCloud and GDFlix links in next siblings
        List<EpisodeLink> episodeLinks = [];
        String? primaryLink;

        // Search next several siblings for all links
        var sibling = header.nextElementSibling;
        int attempts = 0;

        while (sibling != null && attempts < 10) {
          final anchor = sibling.localName == 'a'
              ? sibling
              : sibling.querySelector('a');

          if (anchor != null) {
            final href = anchor.attributes['href'];

            if (href != null) {
              // Check for HubCloud links
              if (_isHubCloudLink(href)) {
                episodeLinks.add(
                  EpisodeLink(server: 'HubCloud', url: href, size: episodeSize),
                );
                primaryLink ??= href; // Set as primary link if not already set
              }
              // Check for GDFlix links
              else if (_isGdFlixLink(href)) {
                episodeLinks.add(
                  EpisodeLink(server: 'GDFlix', url: href, size: episodeSize),
                );
                primaryLink ??= href;
              }
            }
          }

          // Stop if we hit another episode header or HR
          if (sibling.localName == 'hr' ||
              (sibling.localName == 'h5' &&
                  RegExp(
                    r'Ep\s?\d+',
                    caseSensitive: false,
                  ).hasMatch(sibling.text))) {
            break;
          }

          sibling = sibling.nextElementSibling;
          attempts++;
        }

        // Add episode if we found at least one link
        if (primaryLink != null && episodeLinks.isNotEmpty) {
          episodes.add(
            Episode(
              title: episodeTitle,
              link: primaryLink,
              links: episodeLinks,
            ),
          );
        }
      }
    }

    // Fallback: If no series episodes found, look for movie links
    if (episodes.isEmpty) {
      // Find all links in the page that point to HubCloud or GDFlix
      final allLinks = document.querySelectorAll('a');
      List<EpisodeLink> movieLinks = [];
      Set<String> seenUrls = {}; // Avoid duplicates

      for (var linkElement in allLinks) {
        final href = linkElement.attributes['href'];
        
        if (href != null && !seenUrls.contains(href)) {
          String? server;
          
          if (_isHubCloudLink(href)) {
            server = 'HubCloud';
          } else if (_isGdFlixLink(href)) {
            server = 'GDFlix';
          }

          if (server != null) {
            // Check if this is a download link (not a site/telegram link)
            // Valid download links should have /drive/ or /file/ in the path
            if (href.contains('/drive/') || href.contains('/file/')) {
              seenUrls.add(href);
              movieLinks.add(EpisodeLink(server: server, url: href));
            }
          }
        }
      }

      // If we found movie links, create a single episode with all links
      if (movieLinks.isNotEmpty) {
        episodes.add(
          Episode(
            title: "Movie",
            link: movieLinks.first.url,
            links: movieLinks,
          ),
        );
      }
    }

    // Debug logging for drive episode parser
    print('=== DRIVE EPISODE PARSER ===');
    print('Total episodes found: ${episodes.length}');
    for (var i = 0; i < episodes.length; i++) {
      final ep = episodes[i];
      print('Episode $i:');
      print('  Title: ${ep.title}');
      print('  Primary Link: ${ep.link}');
      print('  Available Links: ${ep.links?.length ?? 0}');
      if (ep.links != null) {
        for (var j = 0; j < ep.links!.length; j++) {
          final link = ep.links![j];
          print('    Link $j - Server: ${link.server}, URL: ${link.url}');
        }
      }
    }
    print('=== END EPISODE PARSER ===');

    return episodes;
  }

  // Helper method to check if a URL is a HubCloud link
  static bool _isHubCloudLink(String url) {
    return url.contains('hubcloud.foo') ||
        url.contains('hubcloud.one') ||
        url.contains('hubcloud.') ||
        url.toLowerCase().contains('hubcloud');
  }

  // Helper method to check if a URL is a GDFlix link
  static bool _isGdFlixLink(String url) {
    return url.contains('gdflix.dev') ||
        url.contains('gdflix.') ||
        url.toLowerCase().contains('gdflix');
  }

  // Keep legacy method if needed, or remove
  static Future<List<String>> fetchHubCloudLinks(String url) async {
    final episodes = await fetchEpisodes(url);
    return episodes.map((e) => e.link).toList();
  }
}
