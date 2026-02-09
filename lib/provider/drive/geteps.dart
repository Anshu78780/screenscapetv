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
      // Strategy 1: Look for h3/h4/h5 headers that contain HubCloud or GDFlix links
      final headerSelectors = ['h3', 'h4', 'h5'];
      List<EpisodeLink> movieLinks = [];

      for (String selector in headerSelectors) {
        final headerElements = document.querySelectorAll(selector);
        for (var headerElement in headerElements) {
          final anchor = headerElement.querySelector('a');
          if (anchor != null) {
            final href = anchor.attributes['href'];

            if (href != null) {
              if (_isHubCloudLink(href)) {
                movieLinks.add(EpisodeLink(server: 'HubCloud', url: href));
              } else if (_isGdFlixLink(href)) {
                movieLinks.add(EpisodeLink(server: 'GDFlix', url: href));
              }
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

      // Strategy 2: Fallback to original method if still no results
      if (episodes.isEmpty) {
        final linkElements = document.querySelectorAll('a');
        for (var element in linkElements) {
          final href = element.attributes['href'];
          final text = element.text.toLowerCase();

          if (href != null) {
            if (_isHubCloudLink(href) || _isGdFlixLink(href)) {
              bool isMatch = false;

              // Check 1: Text contains 'instant' or 'hubcloud' or 'gdflix'
              if (text.contains('instant') ||
                  text.contains('hubcloud') ||
                  text.contains('gdflix')) {
                isMatch = true;
              }
              // Check 2: Contains an image (handling button images inside links)
              else if (element.querySelector('img') != null) {
                isMatch = true;
              }
              // Check 3: Parent is a header tag (strong signal for main movie link)
              else if (element.parent != null &&
                  ['h3', 'h4', 'h5'].contains(element.parent!.localName)) {
                isMatch = true;
              }

              if (isMatch) {
                String server = _isHubCloudLink(href) ? 'HubCloud' : 'GDFlix';
                episodes.add(
                  Episode(
                    title: text.isNotEmpty ? element.text.trim() : "Movie",
                    link: href,
                    links: [EpisodeLink(server: server, url: href)],
                  ),
                );
              }
            }
          }
        }
      }
    }

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
