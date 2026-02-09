import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../extractors/hubcloud_extractor.dart';
import '../extractors/stream_types.dart';
import '../extractors/gdflix_extractor.dart';
import 'headers.dart';

Future<List<Stream>> desireMoviesGetStream(
  String link,
  String type,
) async {
  try {
    print('DesiReMovies getting stream for: $link');

    // Check if link contains combined links (pipe-delimited)
    if (link.contains('|')) {
      print('Processing combined links: $link');
      final links = link.split('|').where((l) => l.trim().isNotEmpty).toList();
      
      final futures = links.map((individualLink) async {
        final trimmedLink = individualLink.trim();
        
        if (trimmedLink.contains('gyanigurus')) {
          return await _handleGyanigurusLink(trimmedLink);
        }
        
        if (trimmedLink.contains('hubcloud')) {
          final res = await HubCloudExtractor.extractLinks(trimmedLink);
          return res.streams;
        }
        
        if (trimmedLink.contains('gdflix')) {
           return await GdFlixExtractor.extractStreams(trimmedLink);
        }
        
        return <Stream>[];
      });
      
      final results = await Future.wait(futures);
      return results.expand((x) => x).toList();
    }

    // Handle gyanigurus links
    if (link.contains('gyanigurus')) {
      return await _handleGyanigurusLink(link);
    }

    // Handle direct hubcloud links
    if (link.contains('hubcloud')) {
      final res = await HubCloudExtractor.extractLinks(link);
      return res.streams;
    }

    // Handle direct gdflix links
    if (link.contains('gdflix')) {
      return await GdFlixExtractor.extractStreams(link);
    }

    final streamLinks = <Stream>[];

    // Check if link is already a direct host URL
    if (link.contains('gdrive') || link.contains('drive.google.com')) {
      streamLinks.add(Stream(
        server: 'Google Drive',
        link: link,
        type: 'mp4',
        headers: {'Referer': 'https://drive.google.com/'} // Optional headers if needed
      ));
      return streamLinks;
    }

    // Otherwise, try to extract links from the page
    final response = await http.get(Uri.parse(link), headers: DesireMoviesHeaders.headers);
    final document = html_parser.parse(response.body);
    
    // Check for redirects
    final metaRefresh = document.querySelector('meta[http-equiv="refresh"]');
    if (metaRefresh != null) {
      final content = metaRefresh.attributes['content'] ?? '';
      final match = RegExp(r"URL='(.+?)'", caseSensitive: false).firstMatch(content) ?? 
                    RegExp(r"url=(.+?)$", caseSensitive: false).firstMatch(content);
      
      if (match != null) {
        final redirectUrl = match.group(1);
        print('Found redirect to: $redirectUrl');
        
        if (redirectUrl != null) {
          if (redirectUrl.contains('hubcloud')) {
            final res = await HubCloudExtractor.extractLinks(redirectUrl);
            return res.streams;
          }

          if (redirectUrl.contains('gdflix')) {
            return await GdFlixExtractor.extractStreams(redirectUrl);
          }

          if (redirectUrl.contains('gdrive') || redirectUrl.contains('drive.google.com')) {
             streamLinks.add(Stream(
              server: 'Google Drive',
              link: redirectUrl,
              type: 'mp4',
            ));
          }
        }
      }
    }

    // Check for direct links
    document.querySelectorAll('a').forEach((el) {
      final href = el.attributes['href'];
      if (href != null) {
        if (href.contains('drive.google.com') || href.contains('gdrive')) {
          streamLinks.add(Stream(
            server: 'Google Drive',
            link: href,
            type: 'mp4',
          ));
        }
      }
    });

    print('Found ${streamLinks.length} direct stream links');
    return streamLinks;
  } catch (error) {
    print('Error getting DesiReMovies stream: $error');
    return [];
  }
}

Future<List<Stream>> _handleGyanigurusLink(String link) async {
  try {
    print('Processing gyanigurus link with native scraping: $link');
    
    final response = await http.get(Uri.parse(link), headers: DesireMoviesHeaders.headers);
    final document = html_parser.parse(response.body);
    
    final hubcloudLinks = <String>[];
    final gdflixLinks = <String>[];
    
    // Helper to add links
    void addLinks(List<String> list, String? href) {
      if (href != null && !list.contains(href)) {
        list.add(href);
      }
    }

    // Find all card-body containers
    document.querySelectorAll('.card-body').forEach((cardEl) {
      cardEl.querySelectorAll('a').forEach((a) {
        final href = a.attributes['href'];
        if (href != null) {
          if (href.contains('hubcloud')) addLinks(hubcloudLinks, href);
          if (href.contains('gdflix')) addLinks(gdflixLinks, href);
        }
      });
    });
    
    // If no links found in card-body, try searching entire content
    if (hubcloudLinks.isEmpty && gdflixLinks.isEmpty) {
      document.querySelectorAll('a').forEach((a) {
        final href = a.attributes['href'];
        if (href != null) {
          if (href.contains('hubcloud')) addLinks(hubcloudLinks, href);
          if (href.contains('gdflix')) addLinks(gdflixLinks, href);
        }
      });
    }
    
    print('Found ${hubcloudLinks.length} HubCloud links and ${gdflixLinks.length} GDFlix links');
    
    final allLinks = [...hubcloudLinks, ...gdflixLinks];
    
    if (allLinks.isEmpty) {
      print('No HubCloud or GDFlix links found');
      return [];
    }
    
    final futures = allLinks.map((individualLink) async {
      if (individualLink.contains('hubcloud')) {
        final res = await HubCloudExtractor.extractLinks(individualLink);
        return res.streams;
      } else if (individualLink.contains('gdflix')) {
        return await GdFlixExtractor.extractStreams(individualLink);
      }
      return <Stream>[];
    });
    
    final results = await Future.wait(futures);
    return results.expand((x) => x).toList();
  } catch (error) {
    print('Error processing gyanigurus link: $error');
    return [];
  }
}
