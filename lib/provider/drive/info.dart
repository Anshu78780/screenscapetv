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
    
    // Extract image - try multiple selectors
    String imageUrl = '';
    final imageElement = document.querySelector('.page-body img.aligncenter') ?? 
                        document.querySelector('.page-body img') ??
                        document.querySelector('img[src*="tmsimg.com"]') ??
                        document.querySelector('img[src*="media-amazon.com"]');
    if (imageElement != null) {
      imageUrl = imageElement.attributes['src'] ?? '';
    }
    
    // Extract movie details - try emoji format first
    String imdbRating = _extractDetail(document, '🌟iMDB Rating:');
    String movieName = _extractDetail(document, '🎬Movie Name:');
    String genre = _extractDetail(document, '🤖Genre:');
    String director = _extractDetail(document, '👮Director:');
    String writer = _extractDetail(document, '✍Writer:');
    String stars = _extractDetail(document, '⭐Stars:');
    String language = _extractDetail(document, '🗣Language:');
    String quality = _extractDetail(document, '🎵Quality:');
    String format = _extractDetail(document, '🎙Format:');
    
    // If emoji format not found, try alternative format
    if (imdbRating.isEmpty) {
      imdbRating = _extractAlternativeDetail(document, 'IMDb Rating') ?? '';
    }
    if (movieName.isEmpty) {
      movieName = _extractAlternativeDetail(document, 'Series Name') ?? 
                  _extractAlternativeDetail(document, 'Movie Name') ?? '';
    }
    if (genre.isEmpty) {
      genre = _extractGenreFromColoredText(document);
    }
    if (language.isEmpty) {
      language = _extractAlternativeDetail(document, 'Language') ?? '';
    }
    if (quality.isEmpty) {
      quality = _extractAlternativeDetail(document, 'Quality') ?? '';
    }
    
    // Extract title from colored text if still empty
    if (title.isEmpty) {
      final coloredTitle = document.querySelector('span[style*="color: #ff0000"]');
      if (coloredTitle != null) {
        final titleText = coloredTitle.text.trim();
        if (titleText.isNotEmpty && !titleText.toLowerCase().contains('download')) {
          title = titleText;
        }
      }
    }
    
    // Use movie name if title is empty
    if (title.isEmpty && movieName.isNotEmpty) {
      title = movieName;
    }
    
    // Extract storyline
    String storyline = '';
    
    // Try finding storyline in various ways
    final storylineElements = document.querySelectorAll('.page-body div, .page-body p');
    for (var element in storylineElements) {
      final text = element.text.trim();
      // Look for storyline indicators or long descriptive text
      if (text.contains('In the early') || 
          text.contains('Storyline') ||
          text.contains('based on') ||
          (text.length > 100 && !text.contains('download') && !text.toLowerCase().contains('movie') && !text.contains('Series Info'))) {
        // Skip if it's just listing qualities or technical details
        if (!text.contains('480p') && !text.contains('720p') && !text.contains('Download')) {
          storyline = text;
          // Clean up excessive information
          if (storyline.length > 500) {
            storyline = storyline.substring(0, 500) + '...';
          }
          break;
        }
      }
    }
    
    // If still no storyline, try extracting from description meta or first long paragraph
    if (storyline.isEmpty) {
      final firstPara = document.querySelector('.page-body p');
      if (firstPara != null) {
        final text = firstPara.text.trim();
        if (text.length > 100 && !text.toLowerCase().contains('download')) {
          storyline = text.length > 500 ? text.substring(0, 500) + '...' : text;
        }
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
  
  static String? _extractAlternativeDetail(Document document, String label) {
    // Look for patterns like "Series Name: Loki" or "Language: Dual Audio"
    final elements = document.querySelectorAll('.page-body p, .page-body strong');
    for (var element in elements) {
      final text = element.text;
      final pattern = RegExp('$label:\\s*([^\\n<]+)', caseSensitive: false);
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(1)?.trim();
      }
    }
    
    // Also try searching in the entire body text
    final bodyText = document.querySelector('.page-body')?.text ?? '';
    final pattern = RegExp('$label:\\s*([^\\n]+)', caseSensitive: false);
    final match = pattern.firstMatch(bodyText);
    if (match != null) {
      var value = match.group(1)?.trim() ?? '';
      // Clean up the value - remove anything after newline or excessive text
      if (value.contains('\n')) {
        value = value.split('\n').first.trim();
      }
      return value;
    }
    
    return null;
  }
  
  static String _extractGenreFromColoredText(Document document) {
    // Look for genre in colored spans (e.g., Action, Adventure, Fantasy, Sci-Fi)
    final genreElements = document.querySelectorAll('span[style*="color: #0000ff"]');
    final genres = <String>[];
    
    for (var element in genreElements) {
      final text = element.text.trim();
      // Check if it looks like a genre (single word or two words, not a quality like "480p")
      if (text.isNotEmpty && 
          !text.contains('p') && 
          !text.contains('download') &&
          !RegExp(r'\d').hasMatch(text) &&
          text.length < 20) {
        genres.add(text);
      }
    }
    
    return genres.join(', ');
  }
}
