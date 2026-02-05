import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

class EpisodeParser {
  static Future<List<String>> fetchHubCloudLinks(String url) async {
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      return parseHubCloudLinks(response.body);
    } else {
      throw Exception('Failed to load episode links');
    }
  }

  static List<String> parseHubCloudLinks(String htmlContent) {
    final document = html_parser.parse(htmlContent);
    final List<String> hubCloudLinks = [];
    
    // Find all anchor tags with hubcloud.foo links
    final linkElements = document.querySelectorAll('a[href*="hubcloud.foo"]');
    
    for (var element in linkElements) {
      final href = element.attributes['href'];
      if (href != null && href.contains('hubcloud.foo')) {
        hubCloudLinks.add(href);
      }
    }
    
    return hubCloudLinks;
  }
}
