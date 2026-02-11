import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/movie_info.dart';
import 'headers.dart';

const String _apiDetailsBase = 'https://screenscapeapi.dev/api/animepahe/details';
const String _animePahePlayBase = 'https://animepahe.si/play';

Future<MovieInfo> animepaheGetInfo(String link) async {
  try {
    // Parse the link to get anime_session and session
    final linkData = json.decode(link);
    final animeSession = linkData['anime_session'];
    final session = linkData['session'];

    Uri url;

    // Check if we have anime_session (from home) or just session (from search)
    if (animeSession != null) {
      // Coming from home - use URL parameter
      final animepaheUrl = '$_animePahePlayBase/$animeSession/$session';
      url = Uri.parse(_apiDetailsBase).replace(queryParameters: {
        'url': animepaheUrl,
      });
    } else {
      // Coming from search - use session parameter
      url = Uri.parse(_apiDetailsBase).replace(queryParameters: {
        'session': session,
      });
    }

    print('AnimePahe info URL: $url');

    final response = await http.get(
      url,
      headers: animePaheHeaders,
    );

    if (response.statusCode != 200) {
      print('AnimePahe: Failed to fetch info, status: ${response.statusCode}');
      throw Exception('Failed to fetch anime details');
    }

    final data = json.decode(response.body);

    if (data['success'] != true || data['data'] == null) {
      print('AnimePahe: Invalid info response structure');
      throw Exception('Invalid response from animepahe details API');
    }

    final animeData = data['data'];
    final episodes = animeData['episodes'] as List? ?? [];

    // Create download links for each episode
    final List<DownloadLink> downloadLinks = [];

    for (var ep in episodes) {
      try {
        // Create link as JSON string containing anime_session and session
        final episodeLinkData = {
          'anime_session': animeData['anime_session'],
          'session': ep['session'],
        };

        downloadLinks.add(DownloadLink(
          quality: 'Episode ${ep['episode']}',
          size: '',
          url: json.encode(episodeLinkData),
        ));
      } catch (e) {
        print('AnimePahe: Error parsing episode: $e');
      }
    }

    return MovieInfo(
      title: animeData['anime_title'] ?? 'Anime',
      imageUrl: '',
      imdbRating: '',
      genre: '',
      director: '',
      writer: '',
      stars: '',
      language: '',
      quality: '',
      format: '',
      storyline: 'Total Episodes: ${animeData['total_episodes'] ?? episodes.length}',
      downloadLinks: downloadLinks,
    );
  } catch (e) {
    print('AnimePahe info error: $e');
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
      storyline: 'Failed to fetch anime info',
      downloadLinks: [],
    );
  }
}
