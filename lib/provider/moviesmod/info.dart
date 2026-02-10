import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../../models/movie_info.dart';
import 'headers.dart';

class MoviesmodInfo {
  static Future<MovieInfo> fetchMovieInfo(String url) async {
    final titleFromUrl = url.split('/').last.replaceAll('-', ' ');
    
    try {
      print('Getting info for: $url');
      final response = await http.get(Uri.parse(url), headers: MoviesmodHeaders.headers);
      
      if (response.statusCode != 200) {
        throw Exception('Failed to load movie info');
      }

      final document = html_parser.parse(response.body);

      // Extract metadata
      // TS: $('.imdbwp__title').text()
      final title = document.querySelector('.imdbwp__title')?.text.trim() ?? titleFromUrl;
      
      // Try to get synopsis from multiple possible locations
      var synopsis = document.querySelector('.imdbwp__teaser')?.text.trim();
      if (synopsis == null || synopsis.isEmpty) {
        // Try GenresAndPlot or description paragraphs
        synopsis = document.querySelector('.GenresAndPlot__TextContainerBreakpointXL-cum89p-4 p')?.text.trim();
      }
      if (synopsis == null || synopsis.isEmpty) {
        synopsis = document.querySelector('[data-attrid="wa:/description"] p')?.text.trim();
      }
      synopsis ??= title;
      
      final image = document.querySelector('.imdbwp__thumb img')?.attributes['src'] ?? '';
      
      final imdbLink = document.querySelector('.imdbwp__link')?.attributes['href'];
      final imdbId = (imdbLink != null && imdbLink.split('/').length > 4) 
          ? imdbLink.split('/')[4] 
          : 'N/A';
          
      // TS: $('.thecontent').text().toLocaleLowerCase().includes('season') ? 'series' : 'movie'
      final contentText = document.querySelector('.thecontent')?.text.toLowerCase() ?? '';
      final type = contentText.contains('season') ? 'series' : 'movie';
      
      // Extract screenshots
      final screenshots = <String>[];
      document.querySelectorAll('.thecontent img, img[alt*="Download"]').forEach((img) {
        final src = img.attributes['src'];
        if (src != null && src.isNotEmpty && !src.contains('logo')) {
          screenshots.add(src);
        }
      });
      
      final downloadLinks = <DownloadLink>[];
      
      /*
        Parse headers like:
        "Season 1 {Hindi-English} 480p x264 Esubs [160MB]"
        "Season 2 {Hindi-English-Tamil-Telugu} 1080p 10Bit Esubs [830MB]"
        Extract: season number, language, quality, codec, size
      */
      
      final headers = document.querySelectorAll('h3, h4');
      
      for (var element in headers) {
        final headerTitle = element.text.trim();
        
        // Skip headers that don't look like download sections
        if (!headerTitle.toLowerCase().contains('season') && 
            !headerTitle.toLowerCase().contains('download') &&
            !headerTitle.toLowerCase().contains('p ')) {
          continue;
        }
        
        // find next sibling 'p'
        final parent = element.parent;
        if (parent == null) continue;
        
        // Find index of current header
        final index = parent.children.indexOf(element);
        if (index == -1 || index + 1 >= parent.children.length) continue;
        
        final nextElement = parent.children[index + 1];
        if (nextElement.localName != 'p') continue;
        
        // Parse header information
        final seasonMatch = RegExp(r'Season\s+(\d+)', caseSensitive: false).firstMatch(headerTitle);
        final seasonNum = seasonMatch?.group(1) ?? '';
        
        final qualityMatch = RegExp(r'(\d+p)\b').firstMatch(headerTitle);
        final quality = qualityMatch?.group(1) ?? 'HD';
        
        final codecMatch = RegExp(r'(x264|x265|10Bit|H264|HEVC)', caseSensitive: false).firstMatch(headerTitle);
        final codec = codecMatch?.group(1) ?? '';
        
        final sizeMatch = RegExp(r'\[([^\]]+)\]').firstMatch(headerTitle);
        final size = (sizeMatch?.group(1) ?? '').trim();
        
        // Build clean title
        final cleanTitle = 'Season $seasonNum $quality${codec.isNotEmpty ? " $codec" : ""}${size.isNotEmpty ? " [$size]" : ""}';
        
        // Check for links in this p
        final movieLinkElem = nextElement.querySelector('.maxbutton-download-links');
        final episodeLinkElem = nextElement.querySelector('.maxbutton-episode-links, .maxbutton-g-drive, .maxbutton-af-download');
        
        final movieLink = movieLinkElem?.attributes['href'];
        final episodesLink = episodeLinkElem?.attributes['href'];

        // Handle movie download link
        if (movieLink != null) {
          downloadLinks.add(DownloadLink(
            quality: quality,
            size: size.isNotEmpty ? size : 'Movie',
            url: movieLink,
            season: seasonNum.isNotEmpty ? 'Season $seasonNum' : null,
            episodeInfo: cleanTitle.isEmpty ? 'Movie' : cleanTitle,
          ));
        }
        
        // Handle episode links (store the episode page URL, don't fetch episodes yet)
        if (episodesLink != null && episodesLink != 'javascript:void(0);') {
          // Store the episode page link - episodes will be fetched on-demand by the UI
          downloadLinks.add(DownloadLink(
            quality: quality,
            size: size.isNotEmpty ? size : 'Episodes',
            url: episodesLink,
            season: seasonNum.isNotEmpty ? 'Season $seasonNum' : null,
            episodeInfo: cleanTitle,
          ));
        }
      }
      
      // Fallback: Check for any maxbuttons if headers loop failed or structure diff
      if (downloadLinks.isEmpty) {
         print('Using fallback maxbutton extraction');
         document.querySelectorAll('a.maxbutton').forEach((el) {
           final link = el.attributes['href'];
           final text = el.text.trim();
           if (link != null && link.startsWith('http') && link != 'javascript:void(0);') {
             // Try to infer type from button class
             final classes = el.attributes['class'] ?? '';
             var linkType = 'Download';
             if (classes.contains('episode-links')) {
               linkType = 'Episodes';
             } else if (classes.contains('batch-zip')) {
               linkType = 'Batch';
             } else if (classes.contains('download-links')) {
               linkType = 'Movie';
             }
             
             downloadLinks.add(DownloadLink(
               quality: 'HD',
               size: 'Unknown',
               url: link,
               episodeInfo: text.isNotEmpty ? '$text ($linkType)' : linkType,
             ));
           }
         });
      }
      
      // Extract additional metadata from the page
      final genres = type == 'series' ? 'Series' : 'Movie';
      
      // Try to extract language from the first download link or content
      var detectedLanguage = 'N/A';
      final langMatch = RegExp(r'\{([^}]+)\}').firstMatch(contentText);
      if (langMatch != null) {
        detectedLanguage = (langMatch.group(1) ?? 'N/A').trim();
      } else if (downloadLinks.isNotEmpty) {
        // Try to extract from episode info
        final epInfo = downloadLinks.first.episodeInfo;
        final epLangMatch = RegExp(r'(Hindi|English|Tamil|Telugu|Multi)', caseSensitive: false).firstMatch(epInfo ?? '');
        if (epLangMatch != null) {
          detectedLanguage = epLangMatch.group(1) ?? 'N/A';
        }
      }

      return MovieInfo(
        title: title,
        imageUrl: image,
        imdbRating: imdbId, // Using ID as rating placeholder or N/A
        genre: genres,
        director: 'N/A',
        writer: 'N/A',
        stars: 'N/A',
        language: detectedLanguage,
        quality: downloadLinks.isNotEmpty ? downloadLinks.first.quality : 'HD',
        format: 'MKV',
        storyline: synopsis,
        downloadLinks: downloadLinks,
      );

    } catch (e) {
      print('Error parsing Moviesmod info: $e');
      return MovieInfo(
        title: titleFromUrl, 
        imageUrl: '',
        imdbRating: '',
        genre: '',
        director: '',
        writer: '',
        stars: '',
        language: '',
        quality: '',
        format: '',
        storyline: titleFromUrl,
        downloadLinks: [],
      );
    }
  }
}
