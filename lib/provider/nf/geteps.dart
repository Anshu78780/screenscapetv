import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../models/movie_info.dart';
import 'catalog.dart';
import 'headers.dart';

class NfGetEps {
  static Future<List<Episode>> fetchEpisodes(String link) async {
    try {
      final baseUrl = await NfCatalog.baseUrl;
      final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).round();

      // Parse the link - it may contain both season ID and series ID separated by |
      final linkParts = link.contains('|') ? link.split('|') : [link, link];
      final seasonId = linkParts[0];
      final seriesId = linkParts.length > 1 ? linkParts[1] : linkParts[0];

      final url = '$baseUrl/episodes.php?s=$seasonId&t=$timestamp';

      print('NF Episodes URL: $url');
      final headers = await NfHeaders.getSearchHeaders();

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to load episodes');
      }

      final data = json.decode(response.body);
      final episodeList = <Episode>[];

      // Add episodes from the first page
      if (data['episodes'] != null && data['episodes'] is List) {
        final episodes = data['episodes'] as List;
        for (var episode in episodes) {
          final epNumber = episode['ep']?.toString().replaceAll('E', '') ?? '';
          final epId = episode['id']?.toString() ?? '';

          if (epId.isNotEmpty) {
            episodeList.add(
              Episode(
                title: 'Episode $epNumber',
                link: epId,
              ),
            );
          }
        }
      }

      // Check if there are more pages to fetch
      int currentPage = 2;
      bool hasNextPage = (data['nextPageShow'] ?? 0) == 1;
      final nextSeasonId = data['nextPageSeason']?.toString() ?? seasonId;

      // Fetch all remaining pages
      while (hasNextPage && currentPage <= 50) {
        // Safety limit
        try {
          final nextTimestamp =
              (DateTime.now().millisecondsSinceEpoch / 1000).round();
          final nextUrl =
              '$baseUrl/episodes.php?s=$nextSeasonId&series=$seriesId&t=$nextTimestamp&page=$currentPage';
          print('Fetching page $currentPage: $nextUrl');

          final nextResponse = await http.get(
            Uri.parse(nextUrl),
            headers: headers,
          );

          if (nextResponse.statusCode != 200) {
            print('Failed to fetch page $currentPage');
            break;
          }

          final nextData = json.decode(nextResponse.body);

          // Add episodes from this page
          if (nextData['episodes'] != null && nextData['episodes'] is List) {
            final episodes = nextData['episodes'] as List;
            for (var episode in episodes) {
              final epNumber =
                  episode['ep']?.toString().replaceAll('E', '') ?? '';
              final epId = episode['id']?.toString() ?? '';

              if (epId.isNotEmpty) {
                episodeList.add(
                  Episode(
                    title: 'Episode $epNumber',
                    link: epId,
                  ),
                );
              }
            }
          }

          // Check if there's another page
          hasNextPage = (nextData['nextPageShow'] ?? 0) == 1;
          currentPage++;
        } catch (pageErr) {
          print('Error fetching page $currentPage: $pageErr');
          break;
        }
      }

      print('Total episodes fetched: ${episodeList.length}');
      return episodeList;
    } catch (err) {
      print('NF GetEpisodes error: $err');
      return [];
    }
  }
}
