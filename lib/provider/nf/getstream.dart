import 'package:http/http.dart' as http;
import 'dart:convert';
import '../extractors/stream_types.dart';
import 'headers.dart';
import 'nf_get_cookie.dart';

class NfGetStream {
  static Future<List<Stream>> getStreams(String link, String quality) async {
    try {
      // Extract ID from the link (assuming the link contains the ID)
      final id = link.contains('id=')
          ? link.split('id=')[1].split('&')[0]
          : link;

      const playUrl = 'https://net22.cc/play.php';
      const streamBaseUrl = 'https://net51.cc';

      print('NF GetStream for ID: $id');

      // Step 1: POST to play.php to get the 'h' parameter
      final playHeaders = await NfHeaders.getStreamHeaders(streamBaseUrl);
      final playRequest = http.MultipartRequest('POST', Uri.parse(playUrl));
      playRequest.headers.addAll(playHeaders);
      playRequest.fields['id'] = id;

      final playStreamedResponse = await playRequest.send();
      final playResponse = await http.Response.fromStream(playStreamedResponse);

      if (playResponse.statusCode != 200) {
        throw Exception('Failed to get h parameter from play.php');
      }

      final playResult = json.decode(playResponse.body);
      print('Play response: $playResult');

      final hParam = playResult['h']?.toString();
      if (hParam == null || hParam.isEmpty) {
        throw Exception('Failed to get h parameter from play.php');
      }

      // Step 2: Make request to playlist.php with the h parameter
      final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).round();
      // Extract title from link if available, otherwise use default
      final title = link.contains('&t=')
          ? link.split('&t=')[1].split('&')[0]
          : 'Movie';
      final playlistUrl =
          '$streamBaseUrl/playlist.php?id=$id&t=$title&tm=$timestamp&h=$hParam';

      print('Playlist URL: $playlistUrl');

      final playlistHeaders = {
        ...(await NfHeaders.getStreamHeaders(streamBaseUrl)),
        'Referer': '$streamBaseUrl/',
        'Origin': streamBaseUrl,
      };

      final playlistResponse = await http.get(
        Uri.parse(playlistUrl),
        headers: playlistHeaders,
      );

      if (playlistResponse.statusCode != 200) {
        throw Exception('Failed to get playlist');
      }

      final resJson = json.decode(playlistResponse.body);
      if (resJson is! List || resJson.isEmpty) {
        throw Exception('Invalid playlist response');
      }

      final data = resJson[0];
      final streamLinks = <Stream>[];

      // Get dynamic cookie for stream headers
      final streamCookie = await NfCookieManager.getCookie();

      if (data['sources'] != null && data['sources'] is List) {
        final sources = data['sources'] as List;

        for (var source in sources) {
          var streamUrl = source['file']?.toString() ?? '';
          if (streamUrl.isEmpty) continue;

          // If it's a relative path, prepend the stream base URL
          if (!streamUrl.startsWith('http')) {
            streamUrl = streamBaseUrl + streamUrl;
          }

          final label = source['label']?.toString() ?? 'Unknown';

          streamLinks.add(
            Stream(
              server: label,
              link: streamUrl,
              type: 'm3u8',
              headers: {
                'Referer': streamBaseUrl,
                'Origin': streamBaseUrl,
                'cookie':
                    '${streamCookie}ott=nf; hd=on;',
              },
            ),
          );
        }
      }

      print('Found ${streamLinks.length} stream links');
      return streamLinks;
    } catch (err) {
      print('NF GetStream error: $err');
      return [];
    }
  }
}
