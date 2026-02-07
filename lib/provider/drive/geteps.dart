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
    
    for (var header in headers) {
        final text = header.text.trim();
        
        // Check if header indicates an episode (e.g., "Ep1", "Ep 1", "Episode 1")
        // Using regex to match "Ep" followed optionally by space and then digits
        if (RegExp(r'Ep\s?\d+', caseSensitive: false).hasMatch(text)) {
           // Extract episode title
           // Normalize spaces
           String title = text.replaceAll(RegExp(r'\s+'), ' ').trim();
           
           // Clean up title (e.g. "Ep1–480p [250MB]" -> "Ep 1")
           // We extract exactly "Ep 1" or "Ep1" part.
           final titleMatch = RegExp(r'(Ep\s?\d+)', caseSensitive: false).firstMatch(text);
           if (titleMatch != null) {
               title = titleMatch.group(0) ?? title;
           }

           // Look for HubCloud link in next few sibling elements (not just h5s)
           // This is more robust than looking at the flattened headers list
           String? link;
           var sibling = header.nextElementSibling;
           int attempts = 0;
           
           // Search next 3 siblings for the link
           while (sibling != null && attempts < 3) {
               // Check if the sibling itself is an anchor or contains an anchor
               final anchor = sibling.localName == 'a' ? sibling : sibling.querySelector('a');
               
               if (anchor != null) {
                   final href = anchor.attributes['href'];
                   // Check for HubCloud links
                   if (href != null && href.contains('hubcloud.foo')) {
                       link = href;
                       break;
                   }
               }
               
               sibling = sibling.nextElementSibling;
               attempts++;
           }
           
           if (link != null) {
               episodes.add(Episode(title: title, link: link));
           }
        }
    }
    
    // Fallback: If no series episodes found, maybe it's a movie with just a direct link?
    if (episodes.isEmpty) {
         final linkElements = document.querySelectorAll('a[href*="hubcloud.foo"]');
         for (var element in linkElements) {
            final href = element.attributes['href'];
            final text = element.text.toLowerCase();
            
            bool isMatch = false;

            // Check 1: Text contains 'instant'
            if (text.contains('instant')) {
                isMatch = true;
            }
            // Check 2: Contains an image (handling button images inside links)
            // Fixes: <h4 ...><a ...><img ... src="...hubcloud..."></a></h4>
            else if (element.querySelector('img') != null) {
                isMatch = true; 
            }
            // Check 3: Parent is a header tag (strong signal for main movie link)
            else if (element.parent != null && ['h3', 'h4', 'h5'].contains(element.parent!.localName)) {
                isMatch = true;
            }

            if (href != null && isMatch) {
                 episodes.add(Episode(title: "Movie", link: href));
                 break; // Just take the first valid one
            }
         }
    }
    
    return episodes;
  }
  
  // Keep legacy method if needed, or remove
  static Future<List<String>> fetchHubCloudLinks(String url) async {
      final episodes = await fetchEpisodes(url);
      return episodes.map((e) => e.link).toList();
  }
}
