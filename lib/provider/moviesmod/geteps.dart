import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'headers.dart';

class MoviesmodGetEpisodes {
  static Future<List<Map<String, String>>> getEpisodeLinks(String url) async {
    try {
      String targetUrl = url;
      
      // Handle obfuscated URL
      // TS: if (url.includes('url=')) { url = atob(url.split('url=')[1]); }
      if (targetUrl.contains('url=')) {
        final parts = targetUrl.split('url=');
        if (parts.length > 1) {
          try {
            final decoded = utf8.decode(base64.decode(parts[1]));
            targetUrl = decoded;
          } catch (e) {
            print('Error decoding url: $e');
            // Fallback or keep as is
          }
        }
      }

      print('Fetching episodes from: $targetUrl');
      final response = await http.get(Uri.parse(targetUrl), headers: MoviesmodHeaders.headers);
      
      String html = response.body;

      // Handle Meta Refresh logic from TS
      // if (url.includes('url=')) ... newUrl = meta...
      // The TS logic re-fetches if there was a url= involved initially?
      // Actually it checks meta refresh specifically.
      
      final document = html_parser.parse(html);
      final metaRefresh = document.querySelector("meta[http-equiv='refresh']");
      if (metaRefresh != null) {
        final content = metaRefresh.attributes['content'];
        if (content != null && content.contains('url=')) {
           final newUrl = content.split('url=')[1];
           print('Meta verify redirect to: $newUrl');
           final response2 = await http.get(Uri.parse(newUrl), headers: MoviesmodHeaders.headers);
           html = response2.body;
        }
      }
      
      final doc2 = html_parser.parse(html);
      final episodeLinks = <Map<String, String>>[];

      /*
        $('h3,h4').map...
        $('a.maxbutton').map...
      */
      
      // Method 1: h3/h4 followed by link (or containing link? structure in TS is unclear on nesting)
      // TS: $(element).find('a').attr('href') inside h3/h4 map?
      // Wait TS: $('h3,h4').map((i, element) => { const seriesTitle = ... const episodesLink = $(element).find('a').attr('href'); ... })
      // This implies the link is INSIDE the h3/h4 ?
      
      doc2.querySelectorAll('h3, h4').forEach((element) {
        final seriesTitle = element.text;
        final link = element.querySelector('a')?.attributes['href'];
        
        if (link != null && link != '#' && link != 'javascript:void(0);' && link.isNotEmpty) {
           episodeLinks.add({
             'title': seriesTitle.trim().isNotEmpty ? seriesTitle.trim() : 'No title found',
             'link': link,
           });
        }
      });
      
      // Method 2: a.maxbutton (including nested in divs/paragraphs)
      doc2.querySelectorAll('a.maxbutton').forEach((element) {
        // Get text from span.mb-text or direct text
        String? seriesTitle;
        final spanText = element.querySelector('span.mb-text')?.text.trim();
        if (spanText != null && spanText.isNotEmpty) {
          seriesTitle = spanText;
        } else {
          seriesTitle = element.text.trim();
        }
        
        final link = element.attributes['href'];
        
        // Filter out invalid links (# or javascript:void)
        if (link != null && link != '#' && link != 'javascript:void(0);' && link.isNotEmpty && link.startsWith('http')) {
          // Remove emojis and clean title
          final cleanTitle = seriesTitle.replaceAll(RegExp(r'[^\w\s\-\(\)\.]'), '').trim();
          
          episodeLinks.add({
            'title': (cleanTitle.isNotEmpty) ? cleanTitle : 'download',
            'link': link,
          });
        }
      });

      return episodeLinks;
    } catch (e) {
      print('Error getting episodes: $e');
      return [];
    }
  }
}
