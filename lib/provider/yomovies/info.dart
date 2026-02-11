import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import '../../models/movie_info.dart';
import '../../libs/baseurl.dart';
import 'headers.dart';

Future<MovieInfo> yoMoviesGetInfo(String link) async {
  try {
    print('YoMovies getting info for: $link');

    final baseUrl = await BaseUrl.getProviderUrl('yomovies');
    if (baseUrl == null || baseUrl.isEmpty) {
      print('YoMovies: Failed to get base URL');
      throw Exception('Base URL unavailable');
    }

    final response = await http.get(
      Uri.parse(link),
      headers: {
        ...yoMoviesHeaders,
        'Referer': baseUrl,
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch info: ${response.statusCode}');
    }

    final document = html_parser.parse(response.body);

    // Extract title
    String title = document.querySelector('h3[itemprop="name"]')?.text.trim() ??
                   document.querySelector('.mvic-desc h3')?.text.trim() ?? '';

    // Extract image
    String imageUrl = document.querySelector('img.hidden')?.attributes['src'] ??
                      document.querySelector('.mvic-thumb img')?.attributes['src'] ?? '';
    
    // Try to extract from style attribute if not found
    if (imageUrl.isEmpty) {
      final styleContent = document.querySelector('#content-cover')?.attributes['style'] ?? '';
      final urlMatch = RegExp(r'url\(([^)]+)\)').firstMatch(styleContent);
      if (urlMatch != null) {
        imageUrl = urlMatch.group(1) ?? '';
      }
    }

    // Extract synopsis
    final synopsis = document.querySelector('.f-desc')?.text.trim() ?? '';

    // Determine if it's a series
    final isSeries = link.contains('/series/') ||
                     link.contains('/web-series/') ||
                     link.contains('/tv-shows/') ||
                     document.querySelector('#seasons') != null;

    final List<DownloadLink> downloadLinks = [];

    if (isSeries) {
      // Extract episodes for series
      final seasons = document.querySelectorAll('#seasons .tvseason');

      if (seasons.isNotEmpty) {
        // Multiple seasons
        for (var season in seasons) {
          final seasonTitle = season.querySelector('.les-title strong')?.text.trim() ?? '';
          final episodeElements = season.querySelectorAll('.les-content a');

          for (var episode in episodeElements) {
            final episodeUrl = episode.attributes['href'] ?? '';
            final episodeTitle = episode.text.trim();

            if (episodeUrl.isNotEmpty && episodeTitle.isNotEmpty) {
              downloadLinks.add(DownloadLink(
                quality: episodeTitle,
                size: '',
                url: episodeUrl,
                season: seasonTitle,
                episodeInfo: episodeTitle,
              ));
            }
          }
        }
      } else {
        // Single list of episodes
        final episodeElements = document.querySelectorAll('.les-content a');

        for (var episode in episodeElements) {
          final episodeUrl = episode.attributes['href'] ?? '';
          final episodeTitle = episode.text.trim();

          if (episodeUrl.isNotEmpty && episodeTitle.isNotEmpty) {
            downloadLinks.add(DownloadLink(
              quality: episodeTitle,
              size: '',
              url: episodeUrl,
              episodeInfo: episodeTitle,
            ));
          }
        }
      }
    }

    // If no episodes found or it's a movie, add the main link
    if (downloadLinks.isEmpty) {
      downloadLinks.add(DownloadLink(
        quality: isSeries ? 'Watch' : 'Movie',
        size: '',
        url: link,
      ));
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
    print('YoMovies info error: $e');
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
