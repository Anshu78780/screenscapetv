import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'headers.dart';

class EpisodeLink {
  final String title;
  final String link;

  EpisodeLink({required this.title, required this.link});

  @override
  String toString() => 'EpisodeLink(title: $title, link: $link)';
}

Future<List<EpisodeLink>> vegaGetEpisodeLinks(String url) async {
  print('vegaGetEpisodeLinks: $url');
  
  try {
    print('Using original URL: $url');
    
    final response = await http.get(
      Uri.parse(url),
      headers: vegaHeaders,
    );

    if (response.statusCode != 200) {
      print('vegaGetEpisodeLinks: HTTP ${response.statusCode}');
      return [];
    }

    final document = html_parser.parse(response.body);
    
    // Try multiple container selectors
    final container = document.querySelector('#primary .entry-content') ??
        document.querySelector('main .entry-content') ??
        document.querySelector('.entry-content') ??
        document.querySelector('.entry-inner');

    if (container == null) {
      print('vegaGetEpisodeLinks: No container found');
      return [];
    }

    // Remove unwanted elements
    container.querySelectorAll('.unili-content, .code-block-1').forEach((el) => el.remove());

    final episodes = <EpisodeLink>[];

    // Find all h4 elements that contain episode information
    final h4Elements = container.querySelectorAll('h4');
    bool hasEpisodes = false;
    
    for (var h4 in h4Elements) {
      final title = h4.text
          .replaceAll('-', '')
          .replaceAll(':', '')
          .trim();

      final nextP = h4.nextElementSibling;
      if (nextP == null || nextP.localName != 'p') continue;

      final links = <String>[];

      // Extract G-Direct link (fastdl.zip)
      final gDirectLink = nextP.querySelector('a[href*="fastdl.zip"]')?.attributes['href'];
      if (gDirectLink != null && gDirectLink.isNotEmpty) {
        links.add(gDirectLink);
      }

      // Extract V-Cloud link
      final vcloudButton = nextP.querySelector(
        'button[style*="background:linear-gradient(135deg,#ed0b0b,#f2d152)"]',
      );
      if (vcloudButton != null) {
        final vcloudLink = vcloudButton.parent?.attributes['href'];
        if (vcloudLink != null && vcloudLink.isNotEmpty) {
          links.add(vcloudLink);
        }
      }

      // Extract Filepress/Filebee link
      final filepressLink = nextP.querySelector('a[href*="filebee.xyz"], a[href*="filepress.cloud"]')?.attributes['href'];
      if (filepressLink != null && filepressLink.isNotEmpty) {
        links.add(filepressLink);
      }

      // Combine all links with pipe delimiter
      final combinedLink = links.join('|');

      if (title.isNotEmpty && combinedLink.isNotEmpty) {
        episodes.add(EpisodeLink(title: title, link: combinedLink));
        hasEpisodes = true;
      }
    }

    // If no episodes found, check for direct download links (movie without episodes)
    if (!hasEpisodes) {
      print('No episodes found, looking for direct download links');
      
      // Look for paragraphs with download buttons
      final downloadParagraphs = container.querySelectorAll('p');
      
      for (var p in downloadParagraphs) {
        final links = <String>[];

        // Extract G-Direct link (fastdl.zip)
        final gDirectLink = p.querySelector('a[href*="fastdl.zip"]')?.attributes['href'];
        if (gDirectLink != null && gDirectLink.isNotEmpty) {
          links.add(gDirectLink);
        }

        // Extract V-Cloud link (vcloud.zip or vcloud.lol)
        final vcloudLink = p.querySelector('a[href*="vcloud"]')?.attributes['href'];
        if (vcloudLink != null && vcloudLink.isNotEmpty) {
          links.add(vcloudLink);
        }

        // Extract Filepress/Filebee link
        final filepressLink = p.querySelector('a[href*="filebee.xyz"], a[href*="filepress.cloud"]')?.attributes['href'];
        if (filepressLink != null && filepressLink.isNotEmpty) {
          links.add(filepressLink);
        }

        // If we found at least 2 links in this paragraph, it's likely the download buttons
        if (links.length >= 2) {
          // Get the title from h1 post-title
          final h1 = document.querySelector('h1.post-title, h1.entry-title');
          final title = h1?.text.trim() ?? 'Download';
          
          final combinedLink = links.join('|');
          print('Found direct download with ${links.length} links: $combinedLink');
          episodes.add(EpisodeLink(title: title, link: combinedLink));
          break; // Only need one combined link for direct downloads
        }
      }
    }

    print('vegaGetEpisodeLinks: Found ${episodes.length} ${hasEpisodes ? "episodes" : "direct downloads"}');
    return episodes;
  } catch (err) {
    print('vegaGetEpisodeLinks error: $err');
    return [];
  }
}
