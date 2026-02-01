import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import 'package:http/http.dart' as http;
import '../../models/movie_info.dart';

class MovieInfoParser {
  static Future<MovieInfo> fetchMovieInfo(String url) async {
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      return parseMovieInfo(response.body);
    } else {
      throw Exception('Failed to load movie info');
    }
  }

  static MovieInfo parseMovieInfo(String htmlContent) {
    final document = html_parser.parse(htmlContent);
    
    // Extract title
    String title = '';
    final titleElement = document.querySelector('.page-body p strong');
    if (titleElement != null) {
      title = titleElement.text.trim();
    }
    
    // Extract image
    String imageUrl = '';
    final imageElement = document.querySelector('.page-body img.aligncenter');
    if (imageElement != null) {
      imageUrl = imageElement.attributes['src'] ?? '';
    }
    
    // Extract movie details
    String imdbRating = _extractDetail(document, '🌟iMDB Rating:');
    String movieName = _extractDetail(document, '🎬Movie Name:');
    String genre = _extractDetail(document, '🤖Genre:');
    String director = _extractDetail(document, '👮Director:');
    String writer = _extractDetail(document, '✍Writer:');
    String stars = _extractDetail(document, '⭐Stars:');
    String language = _extractDetail(document, '🗣Language:');
    String quality = _extractDetail(document, '🎵Quality:');
    String format = _extractDetail(document, '🎙Format:');
    
    // Use movie name if title is empty
    if (title.isEmpty && movieName.isNotEmpty) {
      title = movieName;
    }
    
    // Extract storyline
    String storyline = '';
    final storylineElements = document.querySelectorAll('.page-body div');
    for (var element in storylineElements) {
      final text = element.text.trim();
      if (text.contains('In the early') || text.contains('Storyline')) {
        storyline = text;
        break;
      }
    }
    
    // Extract download links (skip screenshots)
    List<DownloadLink> downloadLinks = [];
    final linkElements = document.querySelectorAll('.page-body h5');
    
    for (var i = 0; i < linkElements.length; i++) {
      final linkText = linkElements[i].text.trim();
      
      // Skip screenshot sections
      if (linkText.toLowerCase().contains('screenshot') || 
          linkText.toLowerCase().contains('screen-shot')) {
        continue;
      }
      
      // Parse download link
      if (linkText.contains('[') && linkText.contains(']')) {
        final qualityMatch = RegExp(r'(480p|720p|1080p|2160p|4k)').firstMatch(linkText);
        final sizeMatch = RegExp(r'\[([^\]]+)\]').firstMatch(linkText);
        
        if (qualityMatch != null && sizeMatch != null) {
          String qualityText = qualityMatch.group(0) ?? '';
          String sizeText = sizeMatch.group(1) ?? '';
          
          // Add additional quality info (HEVC, x264, etc.)
          if (linkText.contains('HEVC')) qualityText += ' HEVC';
          if (linkText.contains('x264')) qualityText += ' x264';
          if (linkText.contains('x265')) qualityText += ' x265';
          if (linkText.contains('60FPS')) qualityText += ' 60FPS';
          if (linkText.contains('10Bit')) qualityText += ' 10Bit';
          if (linkText.contains('WEB-DL')) qualityText += ' WEB-DL';
          if (linkText.contains('SDR')) qualityText += ' SDR';
          
          // Find the link in the next element
          String downloadUrl = '';
          if (i + 1 < linkElements.length) {
            final nextElement = linkElements[i + 1];
            final linkElement = nextElement.querySelector('a');
            if (linkElement != null) {
              downloadUrl = linkElement.attributes['href'] ?? '';
            }
          }
          
          if (downloadUrl.isNotEmpty) {
            downloadLinks.add(DownloadLink(
              quality: qualityText,
              size: sizeText,
              url: downloadUrl,
              hubCloudUrl: null, // Will be fetched from the URL page
            ));
          }
        }
      }
    }
    
    return MovieInfo(
      title: title,
      imageUrl: imageUrl,
      imdbRating: imdbRating,
      genre: genre,
      director: director,
      writer: writer,
      stars: stars,
      language: language,
      quality: quality,
      format: format,
      storyline: storyline,
      downloadLinks: downloadLinks,
    );
  }

  static String _extractDetail(Document document, String label) {
    final elements = document.querySelectorAll('.page-body div');
    for (var element in elements) {
      final text = element.text.trim();
      if (text.startsWith(label)) {
        return text.substring(label.length).trim();
      }
    }
    return '';
  }
}
