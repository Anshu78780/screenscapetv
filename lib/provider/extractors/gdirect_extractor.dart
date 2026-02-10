import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'stream_types.dart';

class GDirectExtractor {
  static const Map<String, String> headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.5',
  };

  static Future<List<Stream>> extractStreams(String url) async {
    try {
      print('gDirectExtracter processing URL: $url');

      // Handle zee-dl.shop links
      if (url.contains('zee-dl.shop')) {
        print('Processing zee-dl.shop link');
        final response = await http.get(
          Uri.parse(url),
          headers: headers,
        );

        if (response.statusCode != 200) {
          print('zee-dl: Failed to fetch page: ${response.statusCode}');
          return [];
        }

        final document = html_parser.parse(response.body);
        final downloadElement = document.querySelector('#vd');
        final downloadLink = downloadElement?.attributes['href'];

        if (downloadLink != null && downloadLink.isNotEmpty) {
          print('Found zee-dl download link: $downloadLink');
          return [
            Stream(
              server: 'DRIVE',
              link: downloadLink,
              type: 'mkv',
            ),
          ];
        } else {
          print('zee-dl: No download link found');
          return [];
        }
      }

      // Make request to the redirect API
      final encodedUrl = Uri.encodeComponent(url);
      final apiUrl = 'https://ssbackend-2r7z.onrender.com/api/redirect?url=$encodedUrl';
      
      print('Making request to redirect API: $apiUrl');
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: headers,
      );

      if (response.statusCode != 200) {
        print('gDirectExtracter: API request failed: ${response.statusCode}');
        return [];
      }

      final responseData = json.decode(response.body);
      
      // Response format: {"finalUrl": "...", "redirectCount": 1, "maxRedirectsReached": false}
      if (responseData == null || responseData['finalUrl'] == null) {
        print('gDirectExtracter: No finalUrl in response');
        return [];
      }

      String finalUrl = responseData['finalUrl'] as String;
      print('gDirectExtracter finalUrl: $finalUrl');

      // Remove the fastdl.zip/dl.php?link= prefix if present
      if (finalUrl.contains('fastdl.zip/dl.php?link=')) {
        final parts = finalUrl.split('fastdl.zip/dl.php?link=');
        if (parts.length > 1) {
          finalUrl = parts[1];
          print('Cleaned finalUrl (removed fastdl prefix): $finalUrl');
        }
      }

      // Return as DRIVE stream
      return [
        Stream(
          server: 'DRIVE (G-Direct)',
          link: finalUrl,
          type: 'mkv',
        ),
      ];
    } catch (error) {
      print('gDirectExtracter error: $error');
      return [];
    }
  }
}