import 'package:http/http.dart' as http;
import '../extractors/stream_types.dart';

Future<List<Stream>> yoMoviesGetStream(dynamic link, String type) async {
  try {
    final String linkStr = link is String ? link : '';
    print('YoMovies getting stream for: $linkStr');

    // Extract base URL for headers
    final baseUrlMatch = RegExp(r'^(https?://[^/]+)').firstMatch(linkStr);
    final baseUrl = baseUrlMatch?.group(1) ?? 'https://yomovies.beer';
    print('Using base URL for headers: $baseUrl');

    // Headers for the initial request
    final headers = {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      'Accept-Language': 'en-US,en;q=0.9',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Cookie': '__ddgid_=88FVtslcjtsA0CNp; __ddg2_=p1eTrO8cHLFLo48r; __ddg1_=13P5sx17aDtqButGko8N',
    };

    // Fetch the page
    final response = await http.get(Uri.parse(linkStr), headers: headers);
    
    if (response.statusCode != 200) {
      print('YoMovies: Failed to fetch page, status: ${response.statusCode}');
      return [];
    }

    print('Successfully fetched page');

    // Extract iframe source from player2 div using multiple patterns
    String? iframeSrc;
    final iframeRegexPatterns = [
      RegExp(r'<div id="player2">[\s\S]*?<IFRAME SRC="(.+?)".*?</IFRAME>', caseSensitive: false),
      RegExp(r'<div id="player2">[\s\S]*?<iframe[^>]*src="([^"]*)"[^>]*>', caseSensitive: false),
      RegExp(r'<div class="movieplay">[\s\S]*?<IFRAME SRC="(.+?)".*?</IFRAME>', caseSensitive: false),
      RegExp(r'<IFRAME\s+SRC="(.+?)".*?FRAMEBORDER', caseSensitive: false),
    ];

    for (var regex in iframeRegexPatterns) {
      final match = regex.firstMatch(response.body);
      if (match != null && match.group(1) != null) {
        iframeSrc = match.group(1);
        print('Found iframe src with pattern');
        break;
      }
    }

    if (iframeSrc == null || iframeSrc.isEmpty) {
      print('No iframe found in player2 div');
      return [];
    }

    print('Found iframe src: $iframeSrc');

    // Fetch content from the iframe source
    final iframeResponse = await http.get(
      Uri.parse(iframeSrc),
      headers: {
        'Referer': '$baseUrl/',
        'Origin': baseUrl,
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Cookie': '__ddgid_=88FVtslcjtsA0CNp; __ddg2_=p1eTrO8cHLFLo48r; __ddg1_=13P5sx17aDtqButGko8N',
      },
    );

    if (iframeResponse.statusCode != 200) {
      print('YoMovies: Failed to fetch iframe, status: ${iframeResponse.statusCode}');
      return [];
    }

    print('Iframe response preview: ${iframeResponse.body.substring(0, iframeResponse.body.length > 200 ? 200 : iframeResponse.body.length)}');

    // Try multiple regex patterns for the stream URL
    String? streamUrl;
    final streamRegexPatterns = [
      // Direct pattern matching the exact format
      RegExp(r'sources:\s*\[\s*\{\s*file:\s*"([^"]+)"', caseSensitive: false),
      // Backup patterns with slight variations
      RegExp(r'sources:\s*\[\{file:"([^"]+)"', caseSensitive: false),
      RegExp(r'\{file:"([^"]+)"', caseSensitive: false),
      // More flexible patterns
      RegExp(r'file:\s*"(https?://[^"]+\.m3u8[^"]*)"', caseSensitive: false),
      RegExp(r'file:\s*"(https?://[^"]+\.mp4[^"]*)"', caseSensitive: false),
      RegExp(r'file:\s*"(https?://[^"]+)"', caseSensitive: false),
      // JSON style patterns
      RegExp(r'"file":\s*"([^"]+)"', caseSensitive: false),
      // Fallback patterns
      RegExp(r'file:"([^"]+)"', caseSensitive: false),
      RegExp(r'source\s+src="(.+?)"', caseSensitive: false),
    ];

    for (var regex in streamRegexPatterns) {
      print('Trying pattern: ${regex.pattern}');
      final match = regex.firstMatch(iframeResponse.body);
      if (match != null && match.group(1) != null) {
        streamUrl = match.group(1);
        print('Matched stream URL with pattern');
        print('Extracted URL: $streamUrl');
        break;
      } else {
        print('No match for pattern');
      }
    }

    if (streamUrl == null || streamUrl.isEmpty) {
      print('Stream URL not found in iframe content');
      return [];
    }

    print('Found stream URL: $streamUrl');

    // Create stream object with proper headers
    final streamLinks = [
      Stream(
        server: 'YoMovies Server',
        link: streamUrl,
        type: streamUrl.contains('.m3u8') ? 'm3u8' : 'mp4',
        headers: {
          'Referer': 'https://spedostream.com/',
          'Origin': 'https://spedostream.com',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          'Cookie': '__ddgid_=88FVtslcjtsA0CNp; __ddg2_=p1eTrO8cHLFLo48r; __ddg1_=13P5sx17aDtqButGko8N',
        },
      ),
    ];

    print('Stream extraction completed successfully');
    return streamLinks;
  } catch (error) {
    print('Error getting YoMovies stream: $error');
    return [];
  }
}
