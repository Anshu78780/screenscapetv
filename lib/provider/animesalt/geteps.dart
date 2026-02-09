import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'headers.dart';

class AnimeSaltEpisodeLink {
  final String episodeNumber;
  final String title;
  final String link;

  AnimeSaltEpisodeLink({
    required this.episodeNumber,
    required this.title,
    required this.link,
  });
}

Future<List<AnimeSaltEpisodeLink>> animesaltGetEpisodeLinks(String url) async {
  try {
    // If url is empty or null, episodes are provided via directLinks
    if (url.isEmpty) {
      print('AnimeSalt: Episodes provided via directLinks, no need to fetch');
      return [];
    }

    // If url starts with 'season-', it means we're using the new API structure
    // In this case, episodes are already provided in directLinks from getInfo
    if (url.startsWith('season-')) {
      print('AnimeSalt: Episodes already provided via directLinks');
      return [];
    }

    print('AnimeSalt getting episodes for: $url');
    
    final response = await http.get(
      Uri.parse(url),
      headers: animeSaltHeaders,
    );

    if (response.statusCode != 200) {
      print('AnimeSalt: Failed to fetch episodes, status: ${response.statusCode}');
      return [];
    }

    final document = html_parser.parse(response.body);
    final episodes = <AnimeSaltEpisodeLink>[];

    // Look for episodes list
    var episodeElements = document.querySelectorAll('.episodes-list li, .episode-list li, .episode li');
    
    for (var i = 0; i < episodeElements.length; i++) {
      final element = episodeElements[i];
      final episodeLink = element.querySelector('a')?.attributes['href'];
      var episodeNumber = element.querySelector('.episode-number')?.text.trim();

      // If no specific episode number element, try to extract from text
      if (episodeNumber == null || episodeNumber.isEmpty) {
        final text = element.text.trim();
        final match = RegExp(r'Episode\s+(\d+)', caseSensitive: false).firstMatch(text);
        if (match != null) {
          episodeNumber = match.group(1)!;
        } else {
          episodeNumber = '${i + 1}';
        }
      }

      final title = element.querySelector('.episode-title')?.text.trim() ?? 'Episode $episodeNumber';

      if (episodeLink != null && episodeLink.isNotEmpty) {
        episodes.add(AnimeSaltEpisodeLink(
          episodeNumber: episodeNumber,
          title: title,
          link: episodeLink,
        ));
      }
    }

    // If no specific episode list structure found, try a more generic approach
    if (episodes.isEmpty) {
      final genericLinks = document.querySelectorAll('a[href*="episode"], a[href*="ep-"]');
      
      for (var i = 0; i < genericLinks.length; i++) {
        final element = genericLinks[i];
        final episodeLink = element.attributes['href'];
        final text = element.text.trim();

        // Try to extract episode number from text or link
        String episodeNumber = '';
        var match = RegExp(r'Episode\s+(\d+)', caseSensitive: false).firstMatch(text);
        
        if (match == null && episodeLink != null) {
          match = RegExp(r'episode[^0-9]*(\d+)', caseSensitive: false).firstMatch(episodeLink) ??
                 RegExp(r'ep[^0-9]*(\d+)', caseSensitive: false).firstMatch(episodeLink);
        }

        if (match != null) {
          episodeNumber = match.group(1)!;
        } else {
          episodeNumber = '${i + 1}';
        }

        final title = text.isNotEmpty ? text : 'Episode $episodeNumber';

        if (episodeLink != null && episodeLink.isNotEmpty) {
          episodes.add(AnimeSaltEpisodeLink(
            episodeNumber: episodeNumber,
            title: title,
            link: episodeLink,
          ));
        }
      }
    }

    // Sort episodes numerically
    episodes.sort((a, b) {
      final numA = int.tryParse(a.episodeNumber) ?? 0;
      final numB = int.tryParse(b.episodeNumber) ?? 0;
      return numA.compareTo(numB);
    });

    print('Found ${episodes.length} episodes for AnimeSalt');
    return episodes;
  } catch (error) {
    print('AnimeSalt episodes error: $error');
    return [];
  }
}
