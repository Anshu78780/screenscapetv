import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import 'package:http/http.dart' as http;
import '../../models/movie_info.dart';
import 'headers.dart';

class HdhubInfoParser {
  static Future<MovieInfo> fetchMovieInfo(String url) async {
    try {
      print('hdhub4uGetInfo: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: HdhubHeaders.headers,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to load movie info: HTTP ${response.statusCode}');
      }

      return parseMovieInfo(response.body);
    } catch (e) {
      print('Error fetching hdhub movie info: $e');
      rethrow;
    }
  }

  static MovieInfo parseMovieInfo(String htmlContent) {
    final document = html_parser.parse(htmlContent);
    final container = document.querySelector('.page-body');

    if (container == null) {
      throw Exception('Could not find .page-body container');
    }

    // Extract IMDb ID
    String imdbId = '';
    final imdbLink = container.querySelector('a[href*="imdb.com/title/tt"]');
    if (imdbLink != null) {
      final href = imdbLink.attributes['href'] ?? '';
      final parts = href.split('/');
      if (parts.length > 4) {
        imdbId = parts[4].replaceAll('tt', '');
      }
    }

    // Extract title from h2 with specific data-ved attribute
    String title = '';
    final titleElements = container.querySelectorAll('h2[data-ved]');
    for (var element in titleElements) {
      final ved = element.attributes['data-ved'] ?? '';
      if (ved.contains('ahUKEw')) {
        title = element.text.trim();
        break;
      }
    }

    // Determine type (series or movie)
    final type = title.toLowerCase().contains('season') ? 'series' : 'movie';

    // Extract synopsis
    String storyline = '';
    final descElements = container.querySelectorAll('strong');
    for (var element in descElements) {
      if (element.text.contains('DESCRIPTION')) {
        final parent = element.parent;
        if (parent != null) {
          storyline = parent.text.replaceAll('DESCRIPTION:', '').trim();
          break;
        }
      }
    }

    // Extract image
    String imageUrl = '';
    final imageElement = container.querySelector('img[decoding="async"]');
    if (imageElement != null) {
      imageUrl = imageElement.attributes['src'] ?? '';
    }

    print('hdhub4uGetInfo - title: $title, imdbId: $imdbId, type: $type');

    // Parse download links
    final downloadLinks = <DownloadLink>[];

    // Check for episode links (for series)
    final episodeLinks = _parseEpisodeLinks(container, title);
    downloadLinks.addAll(episodeLinks);

    // If no episode links found, look for direct movie download links
    if (episodeLinks.isEmpty) {
      final movieLinks = _parseMovieLinks(container);
      downloadLinks.addAll(movieLinks);
    }

    return MovieInfo(
      title: title,
      imageUrl: imageUrl,
      imdbRating: '',
      genre: '',
      director: '',
      writer: '',
      stars: '',
      language: '',
      quality: '',
      format: '',
      storyline: storyline,
      downloadLinks: downloadLinks,
    );
  }

  /// Parse episode links for series
  static List<DownloadLink> _parseEpisodeLinks(Element container, String title) {
    final links = <DownloadLink>[];
    
    // Method 1: New format - Look for h4 tags with "EPISODE X" in anchor tags
    final h4Elements = container.querySelectorAll('h4');
    for (var h4 in h4Elements) {
      final episodeAnchors = h4.querySelectorAll('a');
      for (var anchor in episodeAnchors) {
        final anchorText = anchor.text.trim();
        
        // Check if this is an episode link (not a WATCH link)
        if (anchorText.toUpperCase().startsWith('EPISODE') && 
            !anchorText.toUpperCase().contains('WATCH')) {
          
          final episodeLink = anchor.attributes['href'];
          if (episodeLink != null && episodeLink.isNotEmpty) {
            links.add(DownloadLink(
              quality: '',
              size: '',
              url: episodeLink,
              season: title,
              episodeInfo: anchorText.toUpperCase(),
            ));
          }
        }
      }
    }

    // Method 2: Original format - Look for strong tags containing "EPiSODE"
    if (links.isEmpty) {
      final episodeStrongs = container.querySelectorAll('strong');
      for (var strong in episodeStrongs) {
        if (strong.text.contains('EPiSODE')) {
          final parent = strong.parent;
          if (parent == null) continue;
          
          final epTitle = parent.text.trim().toUpperCase();
          
          // Try to find link in next siblings
          var nextSibling = parent.nextElementSibling;
          String? episodeLink;
          
          // Look through next siblings for anchor tag
          int attempts = 0;
          while (nextSibling != null && attempts < 3) {
            final anchor = nextSibling.querySelector('a');
            if (anchor != null) {
              episodeLink = anchor.attributes['href'];
              break;
            }
            nextSibling = nextSibling.nextElementSibling;
            attempts++;
          }

          if (episodeLink != null && episodeLink.isNotEmpty) {
            links.add(DownloadLink(
              quality: '',
              size: '',
              url: episodeLink,
              season: title,
              episodeInfo: epTitle,
            ));
          }
        }
      }
    }

    // Method 3: Fallback - Look for anchor tags containing "EPiSODE" or "EPISODE"
    if (links.isEmpty) {
      final episodeAnchors = container.querySelectorAll('a');
      for (var anchor in episodeAnchors) {
        final anchorText = anchor.text.trim().toUpperCase();
        
        if ((anchorText.contains('EPISODE') || anchorText.contains('EPiSODE')) &&
            !anchorText.contains('WATCH')) {
          
          final episodeLink = anchor.attributes['href'];
          if (episodeLink != null && episodeLink.isNotEmpty) {
            links.add(DownloadLink(
              quality: '',
              size: '',
              url: episodeLink,
              season: title,
              episodeInfo: anchorText,
            ));
          }
        }
      }
    }

    // Sort episodes by episode number if possible
    links.sort((a, b) {
      final aEpisodeInfo = a.episodeInfo ?? '';
      final bEpisodeInfo = b.episodeInfo ?? '';
      
      final aMatch = RegExp(r'EPISODE\s*(\d+)', caseSensitive: false).firstMatch(aEpisodeInfo);
      final bMatch = RegExp(r'EPISODE\s*(\d+)', caseSensitive: false).firstMatch(bEpisodeInfo);
      
      if (aMatch != null && bMatch != null) {
        final aNum = int.tryParse(aMatch.group(1) ?? '0') ?? 0;
        final bNum = int.tryParse(bMatch.group(1) ?? '0') ?? 0;
        return aNum.compareTo(bNum);
      }
      
      return aEpisodeInfo.compareTo(bEpisodeInfo);
    });

    return links;
  }

  /// Parse movie download links
  static List<DownloadLink> _parseMovieLinks(Element container) {
    final links = <DownloadLink>[];
    
    // Find all anchors containing quality indicators
    final qualityAnchors = container.querySelectorAll('a');
    
    for (var anchor in qualityAnchors) {
      final text = anchor.text;
      
      // Check if link contains quality indicators
      if (text.contains('480') || 
          text.contains('720') || 
          text.contains('1080') || 
          text.contains('2160') || 
          text.contains('4K')) {
        
        final movieLink = anchor.attributes['href'];
        if (movieLink == null || movieLink.isEmpty) continue;
        
        // Extract quality using regex
        final qualityMatch = RegExp(r'\b(480p|720p|1080p|2160p)\b', caseSensitive: false)
            .firstMatch(text);
        final quality = qualityMatch?.group(0) ?? '';
        
        links.add(DownloadLink(
          quality: quality,
          size: '',
          url: movieLink,
          episodeInfo: text.trim(),
        ));
      }
    }

    return links;
  }
}
