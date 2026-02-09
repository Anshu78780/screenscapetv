import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'headers.dart';

class ZinkMoviesEpisode {
  final String title;
  final String link;

  ZinkMoviesEpisode({
    required this.title,
    required this.link,
  });
}

Future<List<ZinkMoviesEpisode>> zinkmoviesGetEpisodeLinks(
  String seasonUrl,
) async {
  try {
    print('ZinkMovies fetching episodes for season: $seasonUrl');

    final response = await http.get(
      Uri.parse(seasonUrl),
      headers: zinkmoviesHeaders,
    );

    if (response.statusCode != 200) {
      print('ZinkMovies getEpisodes failed with status: ${response.statusCode}');
      return [];
    }

    final document = parser.parse(response.body);
    final episodeLinks = <ZinkMoviesEpisode>[];

    // Extract episodes from maxbutton structure
    final maxButtons = document.querySelectorAll('a.maxbutton-download-now');
    for (var button in maxButtons) {
      final episodeLink = button.attributes['href'] ?? '';
      final episodeText = button.querySelector('.mb-text')?.text.trim() ?? '';

      if (episodeLink.isNotEmpty &&
          episodeText.isNotEmpty &&
          episodeText.toUpperCase().contains('EPISODE')) {
        episodeLinks.add(ZinkMoviesEpisode(
          title: episodeText,
          link: episodeLink,
        ));
      }
    }

    // Also check for movie-button-container links
    if (episodeLinks.isEmpty) {
      final containerButtons =
          document.querySelectorAll('.movie-button-container a');
      for (var button in containerButtons) {
        final episodeLink = button.attributes['href'] ?? '';
        final episodeText = button.querySelector('span')?.text.trim() ?? '';

        if (episodeLink.isNotEmpty && episodeText.isNotEmpty) {
          episodeLinks.add(ZinkMoviesEpisode(
            title: episodeText,
            link: episodeLink,
          ));
        }
      }
    }

    print('Found ${episodeLinks.length} episodes from season URL');
    return episodeLinks;
  } catch (error) {
    print('ZinkMovies getEpisodeLinks error: $error');
    return [];
  }
}
