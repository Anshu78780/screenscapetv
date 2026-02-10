import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import '../../models/movie_info.dart';
import 'headers.dart';

class Movies4uInfo {
  /// Fetch movie information and download links
  static Future<MovieInfo> fetchMovieInfo(String movieUrl) async {
    try {
      final response = await http.get(
        Uri.parse(movieUrl),
        headers: Movies4uHeaders.getHeaders(),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to load movie info: ${response.statusCode}');
      }

      return _parseMovieInfo(response.body);
    } catch (e) {
      throw Exception('Error fetching movie info: $e');
    }
  }

  /// Parse movie information from HTML
  static MovieInfo _parseMovieInfo(String htmlContent) {
    final document = html_parser.parse(htmlContent);
    
    // Extract title
    final titleElement = document.querySelector('h1.entry-title');
    final title = titleElement?.text.trim() ?? 'Unknown Title';

    // Extract image from entry-meta or post-thumbnail
    final imgElement = document.querySelector('.entry-meta img') ?? 
                      document.querySelector('.post-thumbnail img');
    final imageUrl = imgElement?.attributes['src'] ?? '';

    // Extract quality label
    final qualityElement = document.querySelector('.video-label');
    final quality = qualityElement?.text.trim() ?? '';

    // Extract download links
    final downloadLinks = _parseDownloadLinks(document);

    // Extract additional info from the page
    final contentElement = document.querySelector('.entry-content');
    String imdbRating = '';
    String language = '';
    String storyline = '';

    if (contentElement != null) {
      // Try to extract IMDb rating
      final imdbLink = contentElement.querySelector('a[href*="imdb.com"]');
      if (imdbLink != null) {
        final ratingText = imdbLink.text;
        final ratingMatch = RegExp(r'(\d+\.\d+)/10').firstMatch(ratingText);
        if (ratingMatch != null) {
          imdbRating = ratingMatch.group(1) ?? '';
        }
      }

      // Try to extract language
      final languageMatch = RegExp(r'Language:\s*([^\n<]+)').firstMatch(contentElement.text);
      if (languageMatch != null) {
        language = languageMatch.group(1)?.trim() ?? '';
      }

      // Extract storyline
      final storylinePara = contentElement.querySelector('h3:contains("Storyline") ~ p');
      if (storylinePara != null) {
        storyline = storylinePara.text.trim();
      }
    }

    return MovieInfo(
      title: title,
      imageUrl: imageUrl.isNotEmpty ? imageUrl : 'https://via.placeholder.com/500x750?text=No+Image',
      imdbRating: imdbRating,
      genre: '',
      director: '',
      writer: '',
      stars: '',
      language: language,
      quality: quality,
      format: 'MKV',
      storyline: storyline,
      downloadLinks: downloadLinks,
    );
  }

  /// Parse download links from the page
  static List<DownloadLink> _parseDownloadLinks(Document document) {
    final List<DownloadLink> downloadLinks = [];
    
    // Find all download-links-div elements (there might be multiple)
    final downloadDivs = document.querySelectorAll('.download-links-div');
    if (downloadDivs.isEmpty) return downloadLinks;

    // Use the last download-links-div (typically the actual download section)
    final downloadDiv = downloadDivs.last;

    // Find all h4 elements (quality titles)
    final h4Elements = downloadDiv.querySelectorAll('h4');
    
    for (var h4 in h4Elements) {
      final qualityText = h4.text.trim();
      
      // Extract season information if present
      String? season;
      final seasonMatch = RegExp(r'Season\s+(\d+)', caseSensitive: false).firstMatch(qualityText);
      if (seasonMatch != null) {
        season = 'Season ${seasonMatch.group(1)}';
      }
      
      // Find the next sibling div with class downloads-btns-div
      var nextElement = h4.nextElementSibling;
      while (nextElement != null) {
        if (nextElement.classes.contains('downloads-btns-div')) {
          // Get all links in this container
          final linkElements = nextElement.querySelectorAll('a');
          
          // Only take the first link (Download Links button)
          // Skip Batch/Zip links
          for (var linkElement in linkElements) {
            final link = linkElement.attributes['href'] ?? '';
            final linkText = linkElement.text.toLowerCase();
            
            // Skip batch/zip links
            if (linkText.contains('batch') || linkText.contains('zip')) {
              continue;
            }
            
            // Filter out invalid links (relative paths, how-to pages, etc.)
            if (link.isNotEmpty && 
                link.startsWith('http') && 
                !link.contains('/how-to-download')) {
              downloadLinks.add(DownloadLink(
                quality: qualityText,
                size: '', // Size is included in quality text
                url: link,
                season: season,
              ));
              break; // Only take the first valid download link
            }
          }
          break;
        }
        nextElement = nextElement.nextElementSibling;
      }
    }

    return downloadLinks;
  }
}
