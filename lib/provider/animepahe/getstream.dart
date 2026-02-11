import 'dart:convert';
import 'package:http/http.dart' as http;
import '../extractors/stream_types.dart';
import 'headers.dart';

const String _apiDetailsBase = 'https://screenscapeapi.dev/api/animepahe/details';
const String _apiStreamBase = 'https://screenscapeapi.dev/api/animepahe/stream';
const String _animePahePlayBase = 'https://animepahe.si/play';

Future<List<Stream>> animepaheGetStream(dynamic link, String type) async {
  try {
    print('[AnimePahe] Starting stream fetch');
    
    // Parse the link to get anime_session and session
    final String linkStr = link is String ? link : '';
    final linkData = json.decode(linkStr);
    final animeSession = linkData['anime_session'];
    final session = linkData['session'];

    if (animeSession == null || session == null) {
      print('[AnimePahe] Missing required session data');
      return [];
    }

    // Construct the animepahe URL
    final animepaheUrl = '$_animePahePlayBase/$animeSession/$session';
    print('[AnimePahe] Play URL: $animepaheUrl');

    // Step 1: Get details to fetch the stream_url
    final detailsUrl = Uri.parse(_apiDetailsBase).replace(queryParameters: {
      'url': animepaheUrl,
    });

    print('[AnimePahe] Fetching details from: $detailsUrl');

    final detailsResponse = await http.get(
      detailsUrl,
      headers: animePaheHeaders,
    );

    if (detailsResponse.statusCode != 200) {
      print('[AnimePahe] Details fetch failed: ${detailsResponse.statusCode}');
      return [];
    }

    final detailsData = json.decode(detailsResponse.body);

    if (detailsData['success'] != true) {
      print('[AnimePahe] Invalid response from details API');
      return [];
    }

    // Check for recommended URL first, fallback to current episode stream_url
    final recommended = detailsData['data']?['recommended']?['english_max_quality']?['url'];
    final currentEpisode = detailsData['data']?['current_episode']?['stream_url'];

    final streamUrl = recommended ?? currentEpisode;

    if (streamUrl == null) {
      print('[AnimePahe] No stream URL found in details API');
      return [];
    }

    print('[AnimePahe] Stream URL: $streamUrl');

    // Step 2: Get the m3u8 URL from the stream endpoint
    final streamUrlParsed = Uri.parse(_apiStreamBase).replace(queryParameters: {
      'url': streamUrl,
    });

    print('[AnimePahe] Fetching m3u8 from: $streamUrlParsed');

    final streamResponse = await http.get(
      streamUrlParsed,
      headers: animePaheHeaders,
    );

    if (streamResponse.statusCode != 200) {
      print('[AnimePahe] Stream fetch failed: ${streamResponse.statusCode}');
      return [];
    }

    final streamData = json.decode(streamResponse.body);

    if (streamData['success'] != true || streamData['data']?['m3u8_url'] == null) {
      print('[AnimePahe] Invalid response from stream API');
      return [];
    }

    // Remove trailing backslashes from m3u8_url
    String m3u8Url = streamData['data']['m3u8_url'];
    m3u8Url = m3u8Url.replaceAll(RegExp(r'\\+$'), '');

    print('[AnimePahe] Final m3u8 URL: $m3u8Url');

    return [
      Stream(
        server: 'Kwik',
        link: m3u8Url,
        type: 'm3u8',
        headers: {
          'Referer': 'https://kwik.cx/',
          'Origin': 'https://kwik.cx/',
        },
      ),
    ];
  } catch (e) {
    print('[AnimePahe] Error fetching stream: $e');
    return [];
  }
}
