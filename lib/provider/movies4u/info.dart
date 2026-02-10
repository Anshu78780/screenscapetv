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
    // Order of precedence:
    // 1. h1 with entry-title class
    // 2. h1 inside .single-service-content
    // 3. h1 with movie-title class
    // 4. Any h1 on the page
    final titleElement = document.querySelector('h1.entry-title') ?? 
                         document.querySelector('.single-service-content h1') ??
                         document.querySelector('h1.movie-title') ??
                         document.querySelector('h1');
    final title = titleElement?.text.trim() ?? 'Unknown Title';

    // Extract image 
    // Check multiple possible locations and attributes
    String imageUrl = '';
    final imgSelectors = [
      '.entry-meta img',
      '.post-thumbnail img',
      '.single-service-content img',
    ];

    for (var selector in imgSelectors) {
      final el = document.querySelector(selector);
      if (el != null) {
        imageUrl = el.attributes['src'] ?? 
                   el.attributes['data-src'] ?? 
                   el.attributes['data-original'] ?? '';
        if (imageUrl.isNotEmpty) break;
      }
    }

    // Extract quality label
    final qualityElement = document.querySelector('.video-label');
    final quality = qualityElement?.text.trim() ?? '';

    // Extract download links
    final downloadLinks = _parseDownloadLinks(document);

    // Extract additional info from the page
    // Content might be in .entry-content OR .single-service-content
    final contentElement = document.querySelector('.entry-content') ?? 
                           document.querySelector('.single-service-content');
    
    String imdbRating = '';
    String language = '';
    String storyline = '';
    String genre = '';
    String stars = '';
    String director = '';

    if (contentElement != null) {
      // Try to extract IMDb rating
      final imdbLink = contentElement.querySelector('a[href*="imdb.com"]');
      if (imdbLink != null) {
        final ratingText = imdbLink.text;
        final ratingMatch = RegExp(r'(\d+\.\d+)/10').firstMatch(ratingText);
        if (ratingMatch != null) {
          imdbRating = ratingMatch.group(1) ?? '';
        } else {
             // Fallback for "IMDb Rating:- 8.2/10" format
             final ratingMatch2 = RegExp(r'Rating:[-]*\s*(\d+\.?\d*)/10').firstMatch(ratingText);
             if (ratingMatch2 != null) {
                 imdbRating = ratingMatch2.group(1) ?? '';
             }
        }
      }

      // Helper function to extract text after a label
      String extractInfo(String labelPattern) {
        final regExp = RegExp('$labelPattern\\s*:?\\s*([^\\n<]+)', caseSensitive: false);
        final match = regExp.firstMatch(contentElement.text);
        return match?.group(1)?.trim() ?? '';
      }

      language = extractInfo('Language');
      if (language.isEmpty) language = extractInfo('Audio');

      // Extract storyline - look for h3 with "Storyline" text, then get next p
      final headings = contentElement.querySelectorAll('h3');
      for (var h3 in headings) {
        if (h3.text.contains("Storyline")) {
          // Look for next paragraph
          var next = h3.nextElementSibling;
          while (next != null) {
            if (next.localName == 'p' && next.text.trim().isNotEmpty) {
               storyline = next.text.trim();
               break;
            }
             next = next.nextElementSibling;
          }
           if (storyline.isNotEmpty) break;
        }
      }
      
      // Fallback description from generic paragraph if explicit storyline not found
      if (storyline.isEmpty) {
          final firstP = contentElement.querySelector('p:not(:has(strong))');
          if (firstP != null && firstP.text.length > 50) {
             storyline = firstP.text.trim();
          }
      }
    }

    // Cleaning up image URL if it's protocol relative or incomplete
    if (imageUrl.isNotEmpty && imageUrl.startsWith('//')) {
      imageUrl = 'https:$imageUrl';
    }

    return MovieInfo(
      title: title,
      imageUrl: imageUrl.isNotEmpty ? imageUrl : 'https://via.placeholder.com/500x750?text=No+Image',
      imdbRating: imdbRating,
      genre: genre,
      director: director,
      writer: '',
      stars: stars,
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
