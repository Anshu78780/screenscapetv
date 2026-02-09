import 'dart:convert';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import '../extractors/stream_types.dart';

Future<List<Stream>> animesaltGetStream(dynamic link, String type) async {
  try {
    print('[AnimeSalt] Starting stream fetch');
    print('[AnimeSalt] Input link: $link');

    String episodeUrl = link is String ? link : (link as Map)['link'] ?? '';
    
    // Replace .cc with .top if present
    episodeUrl = episodeUrl.replaceAll('animesalt.cc', 'animesalt.top');

    if (episodeUrl.isEmpty) {
      print('[AnimeSalt] No episode URL found');
      return [];
    }

    print('[AnimeSalt] Episode URL: $episodeUrl');

    // Fetch the AnimeSalt episode page
    print('[AnimeSalt] Fetching episode page...');
    final response = await http.get(
      Uri.parse(episodeUrl),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      },
    );

    if (response.statusCode != 200) {
      print('[AnimeSalt] Fetch failed: ${response.reasonPhrase}');
      throw Exception('Failed to fetch: ${response.reasonPhrase}');
    }

    print('[AnimeSalt] Episode page fetched successfully');
    print('[AnimeSalt] HTML length: ${response.body.length}');
    
    final document = html_parser.parse(response.body);

    // Find the primary video iframe
    print('[AnimeSalt] Searching for video iframe...');
    String iframeUrl = '';
    final iframes = document.querySelectorAll('iframe');
    
    for (var iframe in iframes) {
      final src = iframe.attributes['src'] ?? iframe.attributes['data-src'] ?? '';
      if (src.isNotEmpty && src.contains('as-cdn')) {
        iframeUrl = src.startsWith('//') ? 'https:$src' : src;
        break;
      }
    }

    if (iframeUrl.isEmpty) {
      print('[AnimeSalt] No video iframe found');
      return [];
    }

    print('[AnimeSalt] Found iframe URL: $iframeUrl');

    // Extract video ID from iframe URL
    print('[AnimeSalt] Extracting video ID from iframe URL...');
    final videoIdMatch = RegExp(r'/video/([a-f0-9]+)').firstMatch(iframeUrl);
    if (videoIdMatch == null) {
      print('[AnimeSalt] No video ID found in iframe URL');
      return [];
    }

    final videoId = videoIdMatch.group(1)!;
    print('[AnimeSalt] Video ID: $videoId');

    // Extract origin manually for compatibility
    final urlMatch = RegExp(r'(https?://[^/]+)').firstMatch(iframeUrl);
    final baseDomain = urlMatch?.group(1) ?? '';

    if (baseDomain.isEmpty) {
      print('[AnimeSalt] Could not extract base domain');
      return [];
    }

    print('[AnimeSalt] Base domain: $baseDomain');

    // Visit the iframe page to establish session
    print('[AnimeSalt] Visiting iframe page to establish session...');
    await http.get(
      Uri.parse(iframeUrl),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Referer': episodeUrl,
      },
    );
    print('[AnimeSalt] Session established');

    // Make POST request to get video data
    print('[AnimeSalt] Preparing POST request to get video data...');
    final formData = {
      'hash': videoId,
      'r': episodeUrl,
    };

    final videoUrl = '$baseDomain/player/index.php?data=$videoId&do=getVideo';
    print('[AnimeSalt] Video URL: $videoUrl');
    
    final videoResponse = await http.post(
      Uri.parse(videoUrl),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'application/json, text/javascript, */*; q=0.01',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Referer': iframeUrl,
        'Origin': baseDomain,
        'X-Requested-With': 'XMLHttpRequest',
      },
      body: formData,
    );

    if (videoResponse.statusCode != 200) {
      print('[AnimeSalt] Video data fetch failed: ${videoResponse.reasonPhrase}');
      throw Exception('Failed to fetch video data: ${videoResponse.reasonPhrase}');
    }

    print('[AnimeSalt] Video response status: ${videoResponse.statusCode}');
    final responseText = videoResponse.body;
    print('[AnimeSalt] Video response text: $responseText');

    try {
      print('[AnimeSalt] Parsing video data JSON...');
      final videoData = json.decode(responseText) as Map<String, dynamic>;
      print('[AnimeSalt] Parsed video data: $videoData');

      if (videoData.containsKey('securedLink') && videoData['securedLink'] != null) {
        final securedLink = videoData['securedLink'] as String;
        print('[AnimeSalt] Found securedLink: $securedLink');
        
        return [
          Stream(
            server: 'AnimeSalt',
            link: securedLink,
            type: 'm3u8',
            headers: {
              'origin': 'https://as-cdn21.top',
            },
          ),
        ];
      }

      print('[AnimeSalt] No securedLink found in video data');
      return [];
    } catch (parseError) {
      print('[AnimeSalt] Failed to parse video data: $parseError');
      print('[AnimeSalt] Response text: ${responseText.substring(0, responseText.length < 200 ? responseText.length : 200)}');
      return [];
    }
  } catch (error) {
    print('[AnimeSalt] Stream error: $error');
    return [];
  }
}
