import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../../models/movie_info.dart';
import 'headers.dart';

class Movies4uGetEps {
  /// Fetch episodes from a Movies4u episode page URL
  static Future<List<Episode>> fetchEpisodes(String episodePageUrl) async {
    try {
      print('Movies4u: Fetching episodes from $episodePageUrl');
      final response = await http.get(
        Uri.parse(episodePageUrl),
        headers: Movies4uHeaders.getHeaders(),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to load episodes: ${response.statusCode}');
      }

      return _parseEpisodes(response.body);
    } catch (e) {
      print('Movies4u Error fetching episodes: $e');
      throw Exception('Error fetching episodes: $e');
    }
  }

  /// Parse episodes from HTML content
  static List<Episode> _parseEpisodes(String htmlContent) {
    final document = html_parser.parse(htmlContent);
    final List<Episode> episodes = [];

    // Find the download-links-div container
    final downloadDiv = document.querySelector('.download-links-div');
    if (downloadDiv == null) {
      print('Movies4u: No download-links-div found');
      return episodes;
    }

    // Check if this page has h5 elements (episode-based) or h4 elements (quality-based)
    final h5Elements = downloadDiv.querySelectorAll('h5');
    final h4Elements = downloadDiv.querySelectorAll('h4');

    if (h5Elements.isNotEmpty) {
      // Episode-based structure (for series)
      return _parseEpisodeBasedLinks(h5Elements);
    } else if (h4Elements.isNotEmpty) {
      // Quality-based structure (for movies)
      return _parseQualityBasedLinks(h4Elements);
    }

    print('Movies4u: No h4 or h5 elements found');
    return episodes;
  }

  /// Parse episode-based links (for series)
  static List<Episode> _parseEpisodeBasedLinks(List<dynamic> h5Elements) {
    final List<Episode> episodes = [];
    
    for (var h5 in h5Elements) {
      final episodeTitle = h5.text.trim();
      
      // Extract episode number from title like "-:Episodes: 1:-"
      final episodeMatch = RegExp(r'Episodes?:\s*(\d+)', caseSensitive: false).firstMatch(episodeTitle);
      if (episodeMatch == null) continue;
      
      final episodeNumber = episodeMatch.group(1);
      final formattedTitle = 'Episode $episodeNumber';
      
      // Find the next sibling div with class downloads-btns-div
      var nextElement = h5.nextElementSibling;
      List<EpisodeLink> episodeLinks = [];
      
      while (nextElement != null) {
        if (nextElement.classes.contains('downloads-btns-div')) {
          // Get all links in this container
          final linkElements = nextElement.querySelectorAll('a');
          
          for (var linkElement in linkElements) {
            final url = linkElement.attributes['href'] ?? '';
            final linkText = linkElement.text.trim();
            
            if (url.isEmpty || !url.startsWith('http')) continue;
            
            // Determine server type from URL or link text
            String server = _determineServer(url, linkText);
            
            episodeLinks.add(EpisodeLink(
              server: server,
              url: url,
            ));
          }
          break;
        }
        nextElement = nextElement.nextElementSibling;
      }
      
      // Only add episode if it has at least one valid link
      if (episodeLinks.isNotEmpty) {
        episodes.add(Episode(
          title: formattedTitle,
          link: episodeLinks.first.url, // Backward compatibility - use first link
          links: episodeLinks,
        ));
      }
    }

    print('Movies4u: Found ${episodes.length} episodes');
    return episodes;
  }

  /// Parse quality-based links (for movies)
  static List<Episode> _parseQualityBasedLinks(List<dynamic> h4Elements) {
    final List<Episode> episodes = [];
    
    for (var h4 in h4Elements) {
      final qualityTitle = h4.text.trim();
      
      // Skip if this is a season header (contains "Season" keyword)
      if (qualityTitle.toLowerCase().contains('season')) continue;
      
      // Find the next sibling div with class downloads-btns-div
      var nextElement = h4.nextElementSibling;
      List<EpisodeLink> episodeLinks = [];
      
      while (nextElement != null) {
        if (nextElement.classes.contains('downloads-btns-div')) {
          // Get all links in this container
          final linkElements = nextElement.querySelectorAll('a');
          
          for (var linkElement in linkElements) {
            final url = linkElement.attributes['href'] ?? '';
            final linkText = linkElement.text.trim();
            
            if (url.isEmpty || !url.startsWith('http')) continue;
            
            // Determine server type from URL or link text
            String server = _determineServer(url, linkText);
            
            episodeLinks.add(EpisodeLink(
              server: server,
              url: url,
            ));
          }
          break;
        }
        nextElement = nextElement.nextElementSibling;
      }
      
      // Only add quality option if it has at least one valid link
      if (episodeLinks.isNotEmpty) {
        episodes.add(Episode(
          title: qualityTitle,
          link: episodeLinks.first.url, // Backward compatibility - use first link
          links: episodeLinks,
        ));
      }
    }

    print('Movies4u: Found ${episodes.length} quality options');
    return episodes;
  }

  /// Determine server type from URL or link text
  static String _determineServer(String url, String linkText) {
    if (url.contains('hubcloud') || linkText.contains('Hub-Cloud')) {
      return 'HubCloud';
    } else if (url.contains('gdflix') || linkText.contains('GDFlix')) {
      return 'GDFlix';
    } else if (url.contains('gofile') || linkText.contains('GoFile')) {
      return 'GoFile';
    }
    return 'Unknown';
  }
}
