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
      
      // Parse download link - look for quality and size pattern
      if (linkText.contains('[') && linkText.contains(']')) {
        final qualityMatch = RegExp(r'(480p|720p|1080p|2160p|4k)', caseSensitive: false).firstMatch(linkText);
        final sizeMatches = RegExp(r'\[([^\]]+)\]').allMatches(linkText);
        final sizeMatch = sizeMatches.isNotEmpty ? sizeMatches.last : null;
        
        if (qualityMatch != null && sizeMatch != null) {
          String qualityText = qualityMatch.group(0) ?? '';
          String sizeText = sizeMatch.group(1) ?? '';
          
          // Extract season info
          String? seasonInfo;
          final seasonMatch = RegExp(r'Season\s+(\d+)', caseSensitive: false).firstMatch(linkText);
          if (seasonMatch != null) {
            seasonInfo = 'Season ${seasonMatch.group(1)}';
          }
          
          // Extract episode info
          String? episodeInfo;
          final episodeMatch = RegExp(r'\[([^\]]*Episode[^\]]*)]', caseSensitive: false).firstMatch(linkText);
          if (episodeMatch != null) {
            episodeInfo = episodeMatch.group(1);
          }
          
          // Add additional quality info (HEVC, x264, etc.)
          if (linkText.contains('HEVC')) qualityText += ' HEVC';
          if (linkText.contains('x264')) qualityText += ' x264';
          if (linkText.contains('x265')) qualityText += ' x265';
          if (linkText.contains('60FPS')) qualityText += ' 60FPS';
          if (linkText.contains('10Bit') || linkText.contains('10bit')) qualityText += ' 10Bit';
          if (linkText.contains('WEB-DL')) qualityText += ' WEB-DL';
          if (linkText.contains('SDR')) qualityText += ' SDR';
          
          // Find the "Single Episode" link in the next element(s)
          // Skip ZIP links
          String downloadUrl = '';
          for (var j = 1; j <= 3 && (i + j) < linkElements.length; j++) {
            final nextElement = linkElements[i + j];
            final nextText = nextElement.text.toLowerCase();
            final linkElement = nextElement.querySelector('a');
            
            if (linkElement != null) {
              final href = linkElement.attributes['href'] ?? '';
              
              // Only accept "Single Episode" links or quality links, skip ZIP/Zip links
              if ((nextText.contains('single episode') || 
                   nextText.contains('480p') || 
                   nextText.contains('720p') || 
                   nextText.contains('1080p') || 
                   nextText.contains('2160p') || 
                   nextText.contains('4k')) && 
                  !nextText.contains('zip')) {
                downloadUrl = href;
                break;
              }
            }
          }
          
          if (downloadUrl.isNotEmpty) {
            downloadLinks.add(DownloadLink(
              quality: qualityText,
              size: sizeText,
              url: downloadUrl,
              hubCloudUrl: null,
              season: seasonInfo,
              episodeInfo: episodeInfo,
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
