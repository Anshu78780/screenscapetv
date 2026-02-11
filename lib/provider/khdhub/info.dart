import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import '../../models/movie_info.dart';
import 'headers.dart';

Future<MovieInfo> khdHubGetInfo(String link) async {
  try {
    final response = await http.get(
      Uri.parse(link),
      headers: khdHubHeaders,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch info: ${response.statusCode}');
    }

    final document = html_parser.parse(response.body);

    // Determine type
    final isSeries = document.querySelectorAll('.season-content').isNotEmpty;

    // Extract basic info
    final title = document.querySelector('.page-title')?.text ?? '';
    final imageUrl = document.querySelector('.poster-image img')?.attributes['src'] ?? '';
    
    // Extract synopsis
    final synopsisElement = document.querySelector('.content-section p');
    final synopsis = synopsisElement?.text.trim() ?? '';

    // Extract download links
    final List<DownloadLink> downloadLinks = [];

    if (isSeries) {
      // Extract episodes for series
      final seasonItems = document.querySelectorAll('.season-item');

      for (var seasonItem in seasonItems) {
        final seasonTitle = seasonItem.querySelector('.episode-title')?.text ?? '';
        
        // Extract episode download items
        final episodeDownloadItems = seasonItem.querySelectorAll('.episode-download-item');

        for (var item in episodeDownloadItems) {
          final fileInfo = item.querySelector('.episode-file-info')?.text.trim() ?? '';
          final episodeTitle = fileInfo.replaceAll('\n', ' ').trim();

          // Find HubDrive or HubCloud link
          final links = item.querySelectorAll('.episode-links a');
          String? episodeLink;

          for (var linkElement in links) {
            final linkText = linkElement.text.toLowerCase();
            final href = linkElement.attributes['href'] ?? '';
            if ((linkText.contains('hubdrive') || linkText.contains('hubcloud')) && href.isNotEmpty) {
              episodeLink = href;
              break;
            }
          }

          if (episodeTitle.isNotEmpty && episodeLink != null) {
            downloadLinks.add(DownloadLink(
              quality: episodeTitle,
              size: '',
              url: episodeLink,
              season: seasonTitle,
              episodeInfo: episodeTitle,
            ));
          }
        }
      }
    } else {
      // Extract download links for movies
      final downloadItems = document.querySelectorAll('.download-item');

      for (var item in downloadItems) {
        // Get title from the download header
        final headerElement = item.querySelector('.download-header .flex-1.text-left.font-semibold');
        String headerTitle = '';
        
        if (headerElement != null) {
          // Clone and remove children to get just the text
          headerTitle = headerElement.text.trim();
        }

        // Extract quality from title (e.g., "The Gorge (2160p WEB-DL H265)")
        final qualityMatch = RegExp(r'\(([^)]+)\)').firstMatch(headerTitle);
        final quality = qualityMatch?.group(1) ?? '';

        // Get the actual file title from file-title div
        final fileTitle = item.querySelector('.file-title')?.text.trim() ?? '';

        // Try to find HubCloud or HubDrive link
        final gridLinks = item.querySelectorAll('.grid.grid-cols-2.gap-2 a');
        String? downloadLink;

        for (var linkElement in gridLinks) {
          final linkText = linkElement.text.toLowerCase();
          final href = linkElement.attributes['href'] ?? '';
          if ((linkText.contains('hubcloud') || linkText.contains('hubdrive')) && href.isNotEmpty) {
            downloadLink = href;
            break;
          }
        }

        // Use file title if available, otherwise use header title
        final displayTitle = fileTitle.isNotEmpty ? fileTitle : headerTitle;

        if (displayTitle.isNotEmpty && downloadLink != null) {
          downloadLinks.add(DownloadLink(
            quality: quality.isNotEmpty ? quality : displayTitle,
            size: '',
            url: downloadLink,
          ));
        }
      }
    }

    return MovieInfo(
      title: title,
      imageUrl: imageUrl,
      imdbRating: '',
      genre: '',
      director: '',
      writer: '',
      stars: '',
      language: '',
      quality: '',
      format: '',
      storyline: synopsis,
      downloadLinks: downloadLinks,
    );
  } catch (e) {
    print('khdHub info error: $e');
    return MovieInfo(
      title: 'Error',
      imageUrl: '',
      imdbRating: '',
      genre: '',
      director: '',
      writer: '',
      stars: '',
      language: '',
      quality: '',
      format: '',
      storyline: 'Failed to fetch info',
      downloadLinks: [],
    );
  }
}
