import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../../models/movie_info.dart';
import 'headers.dart';

class XdmoviesInfo {
  static Future<MovieInfo> fetchMovieInfo(String url) async {
    try {
      final response = await http.get(Uri.parse(url), headers: XdmoviesHeaders.headers);
      if (response.statusCode != 200) {
        throw Exception('Failed to load movie info');
      }

      final document = html_parser.parse(response.body);

      // Extract basic info
      final title = document.querySelector('.info h2')?.text.trim() ?? '';
      final image = document.querySelector('img.poster')?.attributes['src'] ?? '';
      final synopsis = document.querySelector('.overview')?.text.trim() ?? 'No description available';
      
      // Rating
      var rating = 'N/A';
      document.querySelectorAll('.info p').forEach((element) {
        if (element.text.contains('Rating')) {
          rating = element.text.replaceAll('Rating:', '').trim();
        }
      });

      // Genres
      var genres = 'N/A';
      document.querySelectorAll('.info p').forEach((element) {
        if (element.text.contains('Genres')) {
          genres = element.text.replaceAll('Genres:', '').trim();
        }
      });

      // Cast
      final castElement = document.querySelector('.cast p'); 
      final stars = castElement?.text.trim() ?? 'N/A';

      // Links extraction
      List<DownloadLink> downloadLinks = [];

      String extractQuality(String filename) {
        final regex = RegExp(r'\b(2160p|1080p|720p|480p|360p)\b', caseSensitive: false);
        final match = regex.firstMatch(filename);
        return match?.group(1) ?? 'Unknown';
      }

      final seasonSections = document.querySelectorAll('.season-section');

      if (seasonSections.isNotEmpty) {
        // Series logic
        int sectionIndex = 0;
        for (var seasonEl in seasonSections) {
          sectionIndex++;
          final seasonButtonText = seasonEl.querySelector('.toggle-season-btn')?.text.trim() ?? '';
          final seasonMatch = RegExp(r'Season\s+(\d+)').firstMatch(seasonButtonText);
          final seasonNumber = seasonMatch?.group(1) ?? '$sectionIndex';

          // Episodes
          seasonEl.querySelectorAll('.episode-card').forEach((episodeEl) {
             final title = episodeEl.querySelector('.episode-title')?.text.trim() ?? '';
             final link = episodeEl.querySelector('a.movie-download-btn')?.attributes['href'] ?? '';
             
             if (title.isNotEmpty && link.isNotEmpty) {
                final quality = extractQuality(title);
                downloadLinks.add(DownloadLink(
                  quality: quality,
                  size: 'Episode', 
                  url: link,
                  season: seasonNumber,
                  episodeInfo: title
                ));
             }
          });

           // Packs
          seasonEl.querySelectorAll('.pack-card').forEach((packEl) {
             final title = packEl.querySelector('.pack-title')?.text.trim() ?? '';
             final link = packEl.querySelector('a.download-button')?.attributes['href'] ?? '';
             
             if (title.isNotEmpty && link.isNotEmpty) {
                final quality = extractQuality(title);
                downloadLinks.add(DownloadLink(
                  quality: quality,
                  size: 'Pack', 
                  url: link,
                  season: seasonNumber,
                  episodeInfo: title
                ));
             }
          });
        }
      } else {
        // Movie logic
        document.querySelectorAll('.download-item').forEach((el) {
          final title = el.querySelector('.custom-title')?.text.trim() ?? '';
          final link = el.querySelector('a.movie-download-btn')?.attributes['href'] ?? el.querySelector('a')?.attributes['href'] ?? '';
          
          if (title.isNotEmpty && link.isNotEmpty) {
             final quality = extractQuality(title);
             final btnText = el.querySelector('a.movie-download-btn')?.text.trim() ?? 'Unknown';
             
             downloadLinks.add(DownloadLink(
               quality: quality,
               size: btnText, 
               url: link,
             ));
          }
        });

        // Fallback or alternative structure (same as TS)
        if (downloadLinks.isEmpty) {
           document.querySelectorAll('.episode-card, .download-link').forEach((el) {
              final title = el.querySelector('.episode-title, .quality')?.text.trim() ?? '';
              final link = el.querySelector('a')?.attributes['href'] ?? '';
              
              if (title.isNotEmpty && link.isNotEmpty) {
                  final quality = extractQuality(title);
                  downloadLinks.add(DownloadLink(
                    quality: quality,
                    size: 'Unknown',
                    url: link,
                  ));
              }
           });
        }
      }

      return MovieInfo(
        title: title,
        imageUrl: image,
        imdbRating: rating,
        genre: genres,
        director: 'N/A', 
        writer: 'N/A', 
        stars: stars,
        language: 'N/A',
        quality: downloadLinks.isNotEmpty ? downloadLinks.first.quality : 'HD',
        format: 'MKV',
        storyline: synopsis,
        downloadLinks: downloadLinks,
      );

    } catch (e) {
      print('Error parsing movie info: $e');
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
        storyline: 'Error loading details',
        downloadLinks: [],
      );
    }
  }
}
