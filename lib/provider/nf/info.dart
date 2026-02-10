import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../models/movie_info.dart';
import 'catalog.dart';
import 'headers.dart';

class NfInfo {
  static Future<MovieInfo> fetchMovieInfo(String link) async {
    try {
      final baseUrl = await NfCatalog.baseUrl;
      // Replace any base URL in the link with our hardcoded one
      final url = link.replaceAll(RegExp(r'https://[^/]+'), baseUrl);
      print('NF info url: $url');

      final headers = await NfHeaders.getInfoHeaders();
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to load movie info');
      }

      final data = json.decode(response.body);
      final id = link.split('id=').length > 1
          ? link.split('id=')[1].split('&')[0]
          : '';

      // Parse metadata
      final title = data['title']?.toString() ?? '';
      final synopsis = data['desc']?.toString() ?? '';
      final image = 'https://img.nfmirrorcdn.top/poster/h/$id.jpg';
      final cast = data['short_cast']?.toString().split(',') ?? <String>[];
      final year = data['year']?.toString() ?? '';
      final hdsd = data['hdsd']?.toString() ?? '';
      final thismovieis = data['thismovieis']?.toString().split(',') ?? <String>[];
      final tags = <String>[year, hdsd, ...thismovieis]
          .where((tag) => tag.isNotEmpty)
          .toList();
      final type = data['type']?.toString() == 't' ? 'series' : 'movie';

      print('NF info metadata:');
      print('  Title: $title');
      print('  Type: $type');
      print('  Year: $year');
      print('  Tags: $tags');

      final downloadLinks = <DownloadLink>[];

      if (data['season'] != null && data['season'] is List) {
        final seasons = data['season'] as List;
        if (seasons.isNotEmpty) {
          // For TV series - create season entries with quality from hdsd
          // This ensures the quality selector in info page works correctly
          // Use 1080p as default for HD content to match quality regex pattern
          final qualityLabel = hdsd.toLowerCase().contains('hd') ? '1080p' : (hdsd.isNotEmpty ? hdsd : '1080p');
          
          for (var season in seasons) {
            final seasonNumber = season['s']?.toString() ?? '';
            final seasonId = season['id']?.toString() ?? '';

            downloadLinks.add(
              DownloadLink(
                quality: qualityLabel, // Use actual quality (1080p for HD, etc.)
                size: '',
                // Store both season ID and series ID for episode fetching
                url: '$seasonId|$id',
                season: seasonNumber, // Season number for filtering
              ),
            );
          }
        }
      } else {
        // For movies - use the ID directly with quality
        final qualityLabel = hdsd.toLowerCase().contains('hd') ? '1080p' : (hdsd.isNotEmpty ? hdsd : '1080p');
        downloadLinks.add(
          DownloadLink(
            quality: qualityLabel,
            size: '',
            url: id,
          ),
        );
      }

      return MovieInfo(
        title: title,
        imageUrl: image,
        imdbRating: '',
        genre: tags.join(', '),
        director: '',
        writer: '',
        stars: cast.join(', '),
        language: '',
        quality: hdsd,
        format: type,
        storyline: synopsis,
        downloadLinks: downloadLinks,
      );
    } catch (err) {
      print('NF GetInfo error: $err');
      return MovieInfo(
        title: '',
        imageUrl: '',
        imdbRating: '',
        genre: '',
        director: '',
        writer: '',
        stars: '',
        language: '',
        quality: '',
        format: '',
        storyline: '',
        downloadLinks: [],
      );
    }
  }
}
