import 'dart:convert';
import 'package:http/http.dart' as http;
import '../extractors/hubcloud_extractor.dart';
import '../extractors/stream_types.dart';

Future<List<Stream>> xdmoviesGetStream(
  String link,
  String type,
) async {
  try {
    print('xdmovies getStream called with link: $link');
    
    // We already have the link.
    // Logic from TS:
    // const redirectApiUrl = `https://net-cookie-kacj.vercel.app/api/redirect?url=${encodeURIComponent(link)}`;
    
    final redirectApiUrl = 'https://net-cookie-kacj.vercel.app/api/redirect?url=${Uri.encodeComponent(link)}';
    print('Calling redirect API: $redirectApiUrl');
    
    final response = await http.get(
      Uri.parse(redirectApiUrl),
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      },
    );

    if (response.statusCode != 200) {
      print('xdmovies getStream error: HTTP ${response.statusCode}');
      return [];
    }

    final data = json.decode(response.body);
    // TS: const finalUrl = redirectRes.data?.data?.finalUrl;
    final finalUrl = data['data']?['finalUrl']?.toString();
    
    print('Got final URL from redirect API: $finalUrl');
    
    if (finalUrl == null || finalUrl.isEmpty) {
      print('No finalUrl in redirect response');
      return [];
    }
    
    if (finalUrl.contains('hubcloud')) {
      print('Extracting streams from hubcloud link');
      final result = await HubCloudExtractor.extractLinks(finalUrl);
      if (result.success) {
        return result.streams;
      }
      return [];
    } else {
      print('Direct link detected, returning as stream');
      return [
        Stream(
          server: 'Direct',
          link: finalUrl,
          type: 'mkv', 
        )
      ];
    }

  } catch (error) {
    print('xdmovies getStream error: $error');
    return [];
  }
}
