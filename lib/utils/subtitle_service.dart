import 'dart:convert';
import 'package:http/http.dart' as http;

class SubtitleService {
  static const String _baseUrl = 'https://rest.opensubtitles.org/search';
  static const String _userAgent = 'VLSub 0.10.2';

  static Future<List<OpenSubtitleResult>> search({
    String? query,
    String? season,
    String? episode,
    String? languageId,
  }) async {
    // Construct URL path based on parameters
    String url = _baseUrl;
    
    if (episode != null && episode.isNotEmpty) {
      url += '/episode-$episode';
    }
    
    if (query != null && query.isNotEmpty) {
      // Logic from RN: (searchQuery?.startsWith('tt') ? '/imdbid-' : '/query-')
      if (query.startsWith('tt')) {
        url += '/imdbid-$query';
      } else {
        url += '/query-${Uri.encodeComponent(query.toLowerCase())}';
      }
    }
    
    if (season != null && season.isNotEmpty) {
      url += '/season-$season';
    }
    
    if (languageId != null && languageId.isNotEmpty) {
      url += '/sublanguageid-$languageId';
    }

    print('[SubtitleService] Fetching: $url');

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'x-user-agent': _userAgent},
      );

      print('[SubtitleService] Response code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => OpenSubtitleResult.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load subtitles: ${response.statusCode}');
      }
    } catch (e) {
      print('[SubtitleService] Error: $e');
      throw Exception('Error searching subtitles: $e');
    }
  }
}

class OpenSubtitleResult {
  final String idSubtitleFile;
  final String subLanguageId;
  final String iso639; // 'en', 'es' etc
  final String movieName;
  final String seriesSeason;
  final String seriesEpisode;
  final String infoReleaseGroup;
  final String userNickName;
  final String subDownloadLink;

  OpenSubtitleResult({
    required this.idSubtitleFile,
    required this.subLanguageId,
    required this.iso639,
    required this.movieName,
    required this.seriesSeason,
    required this.seriesEpisode,
    required this.infoReleaseGroup,
    required this.userNickName,
    required this.subDownloadLink,
  });
  
  // Factory from JSON
  factory OpenSubtitleResult.fromJson(Map<String, dynamic> json) {
    return OpenSubtitleResult(
      idSubtitleFile: json['IDSubtitleFile'] ?? '',
      subLanguageId: json['SubLanguageID'] ?? '',
      iso639: json['ISO639'] ?? '',
      movieName: json['MovieName'] ?? '',
      seriesSeason: json['SeriesSeason'] ?? '0',
      seriesEpisode: json['SeriesEpisode'] ?? '0',
      infoReleaseGroup: json['InfoReleaseGroup'] ?? '',
      userNickName: json['UserNickName'] ?? '',
      subDownloadLink: json['SubDownloadLink'] ?? '',
    );
  }
}
