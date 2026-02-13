import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../../models/movie_info.dart';
import 'headers.dart';

class DesireMoviesInfo {
  static Future<MovieInfo> fetchMovieInfo(String url) async {
    final titleFromUrl = url.split('/').last.replaceAll('-', ' ');
    
    try {
      print('Getting info for: $url');
      final response = await http.get(Uri.parse(url), headers: DesireMoviesHeaders.headers);
      
      if (response.statusCode != 200) {
        throw Exception('Failed to load movie info');
      }

      final document = html_parser.parse(response.body);

      // Extract metadata
      final title = document.querySelector('.entry-title')?.text.trim() ?? titleFromUrl;
      
      // Find valid image (skip empty placeholders)
      String image = '';
      for (var img in document.querySelectorAll('.entry-content img')) {
        final src = img.attributes['src'];
        if (src != null && src.isNotEmpty && src.startsWith('http')) {
           image = src;
           break;
        }
      }

      String imdbRating = 'N/A';
      String genre = 'N/A';
      String language = 'N/A';
      String synopsis = title;

      // Extract details from text-centered paragraphs (Release Info style)
      final infoParagraphs = document.querySelectorAll('.entry-content p');
      for (var p in infoParagraphs) {
         // Check inner text for keywords to identify the info block
         final text = p.text;
         if (text.contains('IMDb') || text.contains('Genres') || text.contains('Plot') || text.contains('Story')) {
             final lines = p.innerHtml.split(RegExp(r'<br\s*/?>', caseSensitive: false));
             for (var line in lines) {
                // Remove HTML tags to get clean text for the line
                final cleanLine = html_parser.parseFragment(line).text?.trim() ?? '';
                
                if (cleanLine.contains('IMDb')) {
                   final m = RegExp(r'IMDb\s*:?\s*([0-9./]+)').firstMatch(cleanLine);
                   if (m != null) imdbRating = m.group(1)!;
                }
                if (cleanLine.contains('Genre')) {
                   final m = RegExp(r'Genres?\s*:?\s*(.+)').firstMatch(cleanLine);
                   if (m != null) genre = m.group(1)!;
                }
                if (cleanLine.contains('Language')) {
                   final m = RegExp(r'Language\s*:?\s*(.+)').firstMatch(cleanLine);
                   if (m != null) language = m.group(1)!;
                }
                if (cleanLine.contains('Plot') || cleanLine.contains('Story')) {
                   final m = RegExp(r'(?:Plot|Story)\s*:?\s*(.+)').firstMatch(cleanLine);
                   if (m != null) synopsis = m.group(1)!;
                }
             }
         }
      }
      
      final downloadLinks = <DownloadLink>[];
      final qualityGroups = <String, List<Map<String, String>>>{};
      
      // First, try to find episode-based structure with blue colored titles
      final episodeGroups = <String, List<Map<String, String>>>{};
      String currentEpisode = '';
      String currentQuality = '';
      
      final paragraphs = document.querySelectorAll('.entry-content p');
      
      for (var el in paragraphs) {
        final text = el.text.trim();
        
        // Check if this is an episode title (blue color)
        // Note: HTML parser might not preserve style attributes well depending on structure
        // We'll check for style attribute containing the color
        final hasBlueColor = el.getElementsByTagName('span').any((s) => s.attributes['style']?.contains('#3366ff') ?? false) ||
                             el.getElementsByTagName('strong').any((s) => s.attributes['style']?.contains('#3366ff') ?? false);
                             
        if (hasBlueColor && (RegExp(r'EP\s*\d+', caseSensitive: false).hasMatch(text) || RegExp(r'EP\s*\d+\s*TO\s*\d+', caseSensitive: false).hasMatch(text))) {
          currentEpisode = text;
          if (episodeGroups[currentEpisode] == null) {
              episodeGroups[currentEpisode] = [];
          }
        }
        
        // Check if this is a quality label (green color)
        final hasGreenColor = el.getElementsByTagName('span').any((s) => s.attributes['style']?.contains('#008000') ?? false);
        if (hasGreenColor && RegExp(r'\d{3,4}p|4K|UHD|HEVC', caseSensitive: false).hasMatch(text)) {
          currentQuality = text;
        }
        
        // Check if this contains a download link
        final link = el.querySelector('a[href*="gyanigurus"], a[href*="hubcloud"], a[href*="gdflix"]')?.attributes['href'];
        
        // Check if we have valid context
        if (link != null) {
           if (currentEpisode.isNotEmpty) {
               // We might need to initialize the list if it doesn't exist (Dart map behavior)
               if (episodeGroups[currentEpisode] == null) {
                  episodeGroups[currentEpisode] = [];
               }
               // Only add if quality is available
               if (currentQuality.isNotEmpty) {
                   episodeGroups[currentEpisode]!.add({
                     'quality': currentQuality,
                     'link': link,
                   });
               }
           } else if (currentQuality.isNotEmpty) {
              // This is a movie link for the current quality
               if (qualityGroups[currentQuality] == null) {
                 qualityGroups[currentQuality] = [];
               }
               
               // Check if link already exists to avoid duplicates
               final exists = qualityGroups[currentQuality]!.any((item) => item['link'] == link);
               if (!exists) {
                 qualityGroups[currentQuality]!.add({
                    'title': currentQuality.replaceAll(RegExp(r'[\n\r]+'), ' ').trim(),
                    'link': link
                 });
               }
           }
        }
      }
      
      // If we found episode-based structure
      if (episodeGroups.isNotEmpty) {
        episodeGroups.forEach((episodeTitle, qualities) {
           for (var item in qualities) {
             downloadLinks.add(DownloadLink(
               quality: item['quality']!,
               size: 'Episode', 
               url: item['link']!,
               episodeInfo: episodeTitle,
             ));
           }
        });
      } else {
        // Fallback to card-body method
        final containers = document.querySelectorAll('.card-body, .entry-content');
        
        for (var cardEl in containers) {
           final cardHtml = cardEl.innerHtml;
           
           // Look for quality
           final qualityMatch = RegExp(r'(\d{3,4}p|UHD|4K|HD)', caseSensitive: false).firstMatch(cardHtml);
           final quality = qualityMatch?.group(1) ?? 'Mixed Quality';
           
           // Initialize group
           if (qualityGroups[quality] == null) {
             qualityGroups[quality] = [];
           }
           
           // Extract episode title if present
           final titleMatch = RegExp(r'Episode[:\s]*(\d+)|S(\d+)E(\d+)', caseSensitive: false).firstMatch(cardHtml);
           String? episodeNum;
           if (titleMatch != null) {
             episodeNum = titleMatch.group(1) ?? '${titleMatch.group(2)}x${titleMatch.group(3)}';
           }
           
           final hubcloudLinks = <String>[];
           final gdflixLinks = <String>[];
           
           cardEl.querySelectorAll('a').forEach((a) {
             final href = a.attributes['href'];
             if (href != null) {
               if (href.contains('hubcloud') && !hubcloudLinks.contains(href)) {
                 hubcloudLinks.add(href);
               }
               if (href.contains('gdflix') && !gdflixLinks.contains(href)) {
                 gdflixLinks.add(href);
               }
             }
           });
           
           if (hubcloudLinks.isNotEmpty || gdflixLinks.isNotEmpty) {
              final maxLinks = hubcloudLinks.length > gdflixLinks.length ? hubcloudLinks.length : gdflixLinks.length;
              
              for (var i = 0; i < maxLinks; i++) {
                final links = <String>[];
                if (i < hubcloudLinks.length) links.add(hubcloudLinks[i]);
                if (i < gdflixLinks.length) links.add(gdflixLinks[i]);
                
                final combinedLink = links.join('|');
                final title = episodeNum != null ? 'Episode $episodeNum' : quality;
                
                qualityGroups[quality]!.add({
                  'title': title,
                  'link': combinedLink
                });
              }
           }
        }
      }
      
      // Fallback if no quality groups found yet
      if (qualityGroups.isEmpty && episodeGroups.isEmpty) {
        document.querySelectorAll('.entry-content a').forEach((el) {
          final downloadLink = el.attributes['href'];
          final downloadText = el.text.trim();
          
          if (downloadLink != null && (
            downloadText.contains('DOWNLOAD') ||
            downloadLink.contains('gyanigurus') ||
            downloadLink.contains('hubcloud') ||
            downloadLink.contains('gdflix')
          )) {
            final qualityMatch = RegExp(r'(\d{3,4}p|UHD|4K|HD)', caseSensitive: false).firstMatch(downloadText);
            final quality = qualityMatch?.group(1) ?? 'Mixed Quality';
            
            if (qualityGroups[quality] == null) {
              qualityGroups[quality] = [];
            }
            
            qualityGroups[quality]!.add({
              'title': downloadText.isNotEmpty ? downloadText : 'Download',
              'link': downloadLink
            });
          }
        });
      }
      
      // Convert quality groups to DownloadList
      if (downloadLinks.isEmpty) {
         final qualityOrder = ['2160p', '4K', 'UHD', '1080p', '720p', '480p', 'HD', 'Mixed Quality'];
         
         final sortedQualities = qualityGroups.keys.toList()..sort((a, b) {
           var aIndex = -1;
           var bIndex = -1;
           
           // Simple fuzzy match for sort order
           for (var i = 0; i < qualityOrder.length; i++) {
             if (a.toLowerCase().contains(qualityOrder[i].toLowerCase())) {
               aIndex = i;
               break;
             }
           }
            for (var i = 0; i < qualityOrder.length; i++) {
             if (b.toLowerCase().contains(qualityOrder[i].toLowerCase())) {
               bIndex = i;
               break;
             }
           }
           
           return (aIndex == -1 ? 999 : aIndex) - (bIndex == -1 ? 999 : bIndex);
         });
         
         for (var quality in sortedQualities) {
           for (var item in qualityGroups[quality]!) {
             downloadLinks.add(DownloadLink(
               quality: quality,
               size: 'Unknown',
               url: item['link']!,
               episodeInfo: item['title']
             ));
           }
         }
      }
      
      // Ultimate fallback
      if (downloadLinks.isEmpty) {
         final directLinks = <Map<String, String>>[];
         document.querySelectorAll('.entry-content a').forEach((el) {
           final downloadLink = el.attributes['href'];
           final downloadText = el.text.trim();
           
           if (downloadLink != null && (
            downloadText.contains('DOWNLOAD') ||
            downloadLink.contains('gyanigurus') ||
            downloadLink.contains('hubcloud') ||
            downloadLink.contains('gdflix')
          )) {
             directLinks.add({
               'title': downloadText.isNotEmpty ? downloadText : 'Download',
               'link': downloadLink
             });
           }
         });
         
         for (var item in directLinks) {
            downloadLinks.add(DownloadLink(
              quality: 'Default',
              size: 'Unknown',
              url: item['link']!,
              episodeInfo: item['title']
            ));
         }
      }
      
      print('Found ${downloadLinks.length} download links');

      return MovieInfo(
        title: title,
        imageUrl: image,
        imdbRating: imdbRating,
        genre: genre,
        director: 'N/A',
        writer: 'N/A',
        stars: 'N/A',
        language: language,
        quality: downloadLinks.isNotEmpty ? downloadLinks.first.quality : 'HD',
        format: 'MKV',
        storyline: synopsis,
        downloadLinks: downloadLinks,
      );

    } catch (e) {
      print('Error parsing DesiReMovies info: $e');
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
