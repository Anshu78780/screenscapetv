import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'stream_types.dart';

class VCloudExtractor {
  static final List<String> _userAgents = [
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/121.0',
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  ];

  static String _getRandomUserAgent() {
    final random = Random();
    return _userAgents[random.nextInt(_userAgents.length)];
  }

  static Map<String, String> _getRequestHeaders({String? referer}) {
    final headers = {
      'User-Agent': _getRandomUserAgent(),
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9',
      'DNT': '1',
      'Connection': 'keep-alive',
      'Upgrade-Insecure-Requests': '1',
      'Sec-Fetch-Dest': 'document',
      'Sec-Fetch-Mode': 'navigate',
      'Sec-Fetch-Site': 'none',
      'Sec-Fetch-User': '?1',
    };

    if (referer != null) {
      headers['Referer'] = referer;
    }

    return headers;
  }

  static Future<String?> _extractVCloudUrl(String vcloudUrl) async {
    try {
      print('Extracting VCloud URL from: $vcloudUrl');

      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          final response = await http.get(
            Uri.parse(vcloudUrl),
            headers: _getRequestHeaders(),
          ).timeout(const Duration(seconds: 15));

          if (response.statusCode != 200) {
            throw Exception('HTTP ${response.statusCode}');
          }

          final html = response.body;

          // Extract the URL from the JavaScript variable
          final urlMatch = RegExp(
            r"var\s+url\s*=\s*'([^']+)'",
          ).firstMatch(html);

          if (urlMatch != null && urlMatch.group(1) != null) {
            final extractedUrl = urlMatch.group(1)!;
            print('Successfully extracted URL: $extractedUrl');
            return extractedUrl;
          }

          // Alternative pattern matching
          final altUrlMatch = RegExp(
            r"url\s*=\s*'([^']+)'",
          ).firstMatch(html);
          if (altUrlMatch != null && altUrlMatch.group(1) != null) {
            final extractedUrl = altUrlMatch.group(1)!;
            print('Successfully extracted URL (alternative pattern): $extractedUrl');
            return extractedUrl;
          }

          // Look for hubcloud.php URLs
          final hubcloudMatch = RegExp(
            r"'(https?://[^']*hubcloud\.php[^']*)'",
          ).firstMatch(html);
          if (hubcloudMatch != null && hubcloudMatch.group(1) != null) {
            final extractedUrl = hubcloudMatch.group(1)!;
            print('Successfully extracted hubcloud URL: $extractedUrl');
            return extractedUrl;
          }

          print('No URL found in the VCloud page');
          return null;
        } catch (fetchError) {
          if (attempt == 3) {
            rethrow;
          }
          print('Attempt $attempt failed: $fetchError');
          await Future.delayed(Duration(seconds: attempt));
        }
      }

      return null;
    } catch (error) {
      print('Error extracting VCloud URL: $error');
      rethrow;
    }
  }

  static Future<List<Stream>> _extractDownloadLinks(String intermediateUrl) async {
    try {
      print('Fetching download links from: $intermediateUrl');

      final List<Stream> streamLinks = [];

      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          final response = await http.get(
            Uri.parse(intermediateUrl),
            headers: _getRequestHeaders(referer: 'https://vcloud.lol/'),
          ).timeout(const Duration(seconds: 15));

          if (response.statusCode != 200) {
            throw Exception('HTTP ${response.statusCode}');
          }

          final document = html_parser.parse(response.body);

          // Extract download links using selectors
          final linkElements = document.querySelectorAll(
            '.btn-success, .btn-danger, .btn-secondary, a[href*="download"]',
          );

          final futures = <Future>[];

          for (var element in linkElements) {
            var linkAttr = element.attributes['href'];
            if (linkAttr == null || linkAttr.isEmpty) continue;

            String link = linkAttr;

            // Skip excluded URLs
            final excludedPatterns = [
              'google.com/search',
              't.me/',
              'telegram.me/',
              'whatsapp.com',
              'facebook.com',
              'twitter.com',
              'instagram.com',
            ];

            if (excludedPatterns.any((pattern) => link.contains(pattern))) {
              continue;
            }

            // Handle pixeldrain links
            if (link.contains('pixeld')) {
              if (link.contains('/u/')) {
                final token = link.split('/u/')[1].split('?')[0];
                final base = link.split('/u/')[0];
                link = '$base/api/file/$token';
                print('Converted pixeldrain link to: $link');
              } else if (!link.contains('api')) {
                final parts = link.split('/');
                final token = parts.last;
                final base = parts.sublist(0, parts.length - 2).join('/');
                link = '$base/api/file/$token';
              }
              streamLinks.add(
                Stream(server: 'Pixeldrain', link: link, type: 'mkv'),
              );
              continue;
            }

            // Handle pixel.hubcdn.fans links
            if (link.contains('pixel.hubcdn.fans')) {
              futures.add(_extractPixelLink(link, streamLinks));
              continue;
            }

            // Handle gpdl2.hubcdn.fans links
            if (link.contains('gpdl2.hubcdn.fans') || link.contains('gpdl.hubcdn.fans')) {
              futures.add(_extractGpdlLink(link, streamLinks));
              continue;
            }

            // Determine server type and add to streamLinks
            if (element.classes.contains('btn-danger')) {
              streamLinks.add(Stream(
                server: '10Gbps Server',
                link: link,
                type: 'mkv',
              ));
            } else if (link.contains('pub-') && link.contains('.r2.dev')) {
              streamLinks.add(Stream(
                server: 'R2 CDN',
                link: link,
                type: 'mkv',
              ));
            } else if (element.classes.contains('btn-success')) {
              streamLinks.add(Stream(
                server: 'Server 1',
                link: link,
                type: 'mkv',
              ));
            } else if (link.contains('download') ||
                link.contains('.mkv') ||
                link.contains('.mp4')) {
              streamLinks.add(Stream(
                server: 'VCloud',
                link: link,
                type: 'mkv',
              ));
            }
          }

          await Future.wait(futures);

          print('Successfully extracted ${streamLinks.length} download links');
          return streamLinks;
        } catch (fetchError) {
          if (attempt == 3) {
            rethrow;
          }
          print('Download links attempt $attempt failed: $fetchError');
          await Future.delayed(Duration(seconds: attempt));
        }
      }

      return streamLinks;
    } catch (error) {
      print('Error extracting download links: $error');
      rethrow;
    }
  }

  static Future<void> _extractGpdlLink(
    String href,
    List<Stream> streamLinks,
  ) async {
    try {
      print('Resolving gpdl.hubcdn.fans link via redirect API: $href');
      final response = await http.get(
        Uri.parse(
          'https://ssbackend-2r7z.onrender.com/api/redirect?url=${Uri.encodeComponent(href)}',
        ),
        headers: _getRequestHeaders(),
      );

      final data = json.decode(response.body);
      final finalUrl = data['finalUrl'];

      if (finalUrl != null && finalUrl.isNotEmpty) {
        print('Extracted final video URL from redirect API: $finalUrl');
        streamLinks.add(
          Stream(
            server: 'HubCdn (DRIVE-DOWNLOAD ONLY)',
            link: finalUrl,
            type: 'mkv',
          ),
        );
      } else {
        print('No finalUrl in redirect response, using original link');
        streamLinks.add(
          Stream(
            server: 'HubCdn (DRIVE-DOWNLOAD ONLY)',
            link: href,
            type: 'mkv',
          ),
        );
      }
    } catch (e) {
      print('Error resolving gpdl.hubcdn.fans via redirect API: $e');
      streamLinks.add(Stream(server: 'HubCdn', link: href, type: 'mkv'));
    }
  }

  static Future<void> _extractPixelLink(
    String href,
    List<Stream> streamLinks,
  ) async {
    try {
      print('Resolving pixel.hubcdn.fans link via redirect API: $href');
      final response = await http.get(
        Uri.parse(
          'https://ssbackend-2r7z.onrender.com/api/redirect?url=${Uri.encodeComponent(href)}',
        ),
        headers: _getRequestHeaders(),
      );

      final data = json.decode(response.body);
      final finalUrl = data['finalUrl'];

      if (finalUrl != null && finalUrl.isNotEmpty) {
        print('Extracted final video URL from redirect API: $finalUrl');
        streamLinks.add(
          Stream(
            server: 'DRIVE (NON-RESUME DOWNLOAD ONLY)',
            link: finalUrl,
            type: 'mkv',
          ),
        );
      } else {
        print('No finalUrl in redirect response for pixel.hubcdn.fans');
      }
    } catch (e) {
      print('Error resolving pixel.hubcdn.fans via redirect API: $e');
    }
  }

  static Future<List<Stream>> extractStreams(String link) async {
    try {
      print('vcloudExtractor: $link');

      // Step 1: Extract the intermediate URL
      final intermediateUrl = await _extractVCloudUrl(link);

      if (intermediateUrl == null || intermediateUrl.isEmpty) {
        print('No intermediate URL found');
        return [];
      }

      // Step 2: Extract the actual download links
      final streamLinks = await _extractDownloadLinks(intermediateUrl);

      print('vcloud streamLinks: $streamLinks');
      return streamLinks;
    } catch (error) {
      print('vcloudExtractor error: $error');
      return [];
    }
  }
}
