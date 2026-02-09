import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../extractors/stream_types.dart';

class TechExtractor {
  static const Map<String, String> headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
  };

  /// Check if the link is a drive leach link and resolve it
  static Future<String> _isDriveLink(String ddl) async {
    if (ddl.contains('drive')) {
      try {
        final response = await http.get(Uri.parse(ddl), headers: headers);
        final match = RegExp(r'window\.location\.replace\("([^"]+)"\)').firstMatch(response.body);
        if (match != null) {
          final path = match.group(1);
          final uri = Uri.parse(ddl);
          final mainUrl = uri.host;
          final driveUrl = 'https://$mainUrl$path';
          print('driveUrl = $driveUrl');
          return driveUrl;
        }
      } catch (e) {
        print('Error resolving drive link: $e');
      }
    }
    return ddl;
  }

  /// Extract the actual download link from tech.unblockedgames.world
  static Future<String?> extractDownloadLink(String url) async {
    try {
      if (!url.contains('sid=')) {
        return null;
      }

      final wpHttp = url.split('sid=')[1];
      final baseUrl = url.split('?')[0];

      // Step 1: First POST request with _wp_http
      print('Tech extractor: Step 1 - POST with _wp_http');
      final response1 = await http.post(
        Uri.parse(baseUrl),
        body: {'_wp_http': wpHttp},
      );

      if (response1.statusCode != 200) {
        print('Tech extractor: First POST failed with status ${response1.statusCode}');
        return null;
      }

      final document = html_parser.parse(response1.body);

      // Find input with name="_wp_http2"
      final wpHttp2Input = document.querySelector('input[name="_wp_http2"]');
      final wpHttp2 = wpHttp2Input?.attributes['value'] ?? '';

      if (wpHttp2.isEmpty) {
        print('Tech extractor: Could not find _wp_http2 value');
        return null;
      }

      // Get form action URL
      final formElement = document.querySelector('form');
      final formAction = formElement?.attributes['action'] ?? baseUrl;

      // Step 2: Second POST request with _wp_http2
      print('Tech extractor: Step 2 - POST with _wp_http2');
      final response2 = await http.post(
        Uri.parse(formAction),
        body: {'_wp_http2': wpHttp2},
      );

      if (response2.statusCode != 200) {
        print('Tech extractor: Second POST failed with status ${response2.statusCode}');
        return null;
      }

      // Extract link from setAttribute
      final linkMatch = RegExp(r'setAttribute\("href",\s*"(.*?)"').firstMatch(response2.body);
      if (linkMatch == null) {
        print('Tech extractor: Could not extract link from response');
        return null;
      }

      final link = linkMatch.group(1)!;
      print('Tech extractor: Extracted link: $link');

      // Extract cookie value
      final cookie = link.split('=').length > 1 ? link.split('=')[1] : '';
      print('Tech extractor: Cookie: $cookie');

      // Step 3: GET request with cookie to get final redirect
      print('Tech extractor: Step 3 - GET with cookie');
      final response3 = await http.get(
        Uri.parse(link),
        headers: {
          ...headers,
          'Referer': formAction,
          'Cookie': '$cookie=$wpHttp2',
        },
      );

      // Extract final download link from meta refresh
      final ddlMatch = RegExp(r'content="0;url=(.*?)"').firstMatch(response3.body);
      if (ddlMatch == null) {
        print('Tech extractor: Could not find meta refresh URL');
        return url; // Return original if extraction fails
      }

      final ddl = ddlMatch.group(1)!;
      print('Tech extractor: Final DDL: $ddl');

      return ddl;
    } catch (e) {
      print('Tech extractor error: $e');
      return null;
    }
  }

  /// Extract streaming servers from the resolved link
  static Future<List<Stream>> extractStreams(String url) async {
    try {
      print('Tech extractor: Starting stream extraction for: $url');

      // Step 1: Extract download link
      final ddl = await extractDownloadLink(url);
      if (ddl == null) {
        return [];
      }

      // Step 2: Resolve drive link if needed
      final driveLink = await _isDriveLink(ddl);
      
      final servers = <Stream>[];
      
      // Step 3: Fetch the drive page
      final driveResponse = await http.get(Uri.parse(driveLink), headers: headers);
      final driveDocument = html_parser.parse(driveResponse.body);

      // Try ResumeBot
      try {
        final resumeBot = driveDocument.querySelector('.btn.btn-light')?.attributes['href'];
        if (resumeBot != null && resumeBot.isNotEmpty) {
          print('Tech extractor: Found ResumeBot link: $resumeBot');
          
          final resumeBotRes = await http.get(Uri.parse(resumeBot), headers: headers);
          final tokenMatch = RegExp(r"formData\.append\('token', '([a-f0-9]+)'\)").firstMatch(resumeBotRes.body);
          final pathMatch = RegExp(r"fetch\('\/download\?id=([a-zA-Z0-9\/+]+)'").firstMatch(resumeBotRes.body);
          
          if (tokenMatch != null && pathMatch != null) {
            final token = tokenMatch.group(1)!;
            final path = pathMatch.group(1)!;
            final baseUrl = resumeBot.split('/download')[0];
            
            final downloadUrl = '$baseUrl/download?id=$path';
            final downloadResponse = await http.post(
              Uri.parse(downloadUrl),
              body: {'token': token},
              headers: {
                ...headers,
                'Referer': resumeBot,
                'Cookie': 'PHPSESSID=7e9658ce7c805dab5bbcea9046f7f308',
              },
            );
            
            final jsonData = json.decode(downloadResponse.body);
            if (jsonData['url'] != null) {
              print('Tech extractor: ResumeBot stream found');
              servers.add(Stream(
                server: 'ResumeBot',
                link: jsonData['url'],
                type: 'mkv',
              ));
            }
          }
        }
      } catch (e) {
        print('Tech extractor: ResumeBot extraction failed: $e');
      }

      // Cloud Download fallback
      if (servers.isEmpty) {
        try {
          final cloudDownload = driveDocument.querySelector('.btn.btn-success')?.attributes['href'];
          if (cloudDownload != null && cloudDownload.isNotEmpty) {
            print('Tech extractor: Using Cloud Download: $cloudDownload');
            servers.add(Stream(
              server: 'Cloud Download',
              link: cloudDownload,
              type: 'mkv',
            ));
          }
        } catch (e) {
          print('Tech extractor: Cloud Download extraction failed: $e');
        }
      }

      // CF Workers type 1
      try {
        final cfWorkersLink = '${driveLink.replaceAll('/file', '/wfile')}?type=1';
        final cfWorkersRes = await http.get(Uri.parse(cfWorkersLink), headers: headers);
        final cfWorkersDoc = html_parser.parse(cfWorkersRes.body);
        
        final cfStreams = cfWorkersDoc.querySelectorAll('.btn-success');
        for (var i = 0; i < cfStreams.length; i++) {
          final link = cfStreams[i].attributes['href'];
          if (link != null && link.isNotEmpty) {
            servers.add(Stream(
              server: 'Cf Worker 1.$i',
              link: link,
              type: 'mkv',
            ));
          }
        }
      } catch (e) {
        print('Tech extractor: CF Workers type 1 extraction failed: $e');
      }

      // CF Workers type 2
      try {
        final cfWorkersLink = '${driveLink.replaceAll('/file', '/wfile')}?type=2';
        final cfWorkersRes = await http.get(Uri.parse(cfWorkersLink), headers: headers);
        final cfWorkersDoc = html_parser.parse(cfWorkersRes.body);
        
        final cfStreams = cfWorkersDoc.querySelectorAll('.btn-success');
        for (var i = 0; i < cfStreams.length; i++) {
          final link = cfStreams[i].attributes['href'];
          if (link != null && link.isNotEmpty) {
            servers.add(Stream(
              server: 'Cf Worker 2.$i',
              link: link,
              type: 'mkv',
            ));
          }
        }
      } catch (e) {
        print('Tech extractor: CF Workers type 2 extraction failed: $e');
      }

      // Instant link (btn-danger with cdn.video-leech.pro or other instant downloads)
      try {
        final instantButtons = driveDocument.querySelectorAll('.btn-danger');
        for (var button in instantButtons) {
          final buttonLink = button.attributes['href'];
          final buttonText = button.text.toLowerCase();
          
          // Check if it's an instant download button
          if (buttonLink != null && buttonText.contains('instant')) {
            print('Tech extractor: Found Instant Download link: $buttonLink');
            
            // Process through redirect API if it's a cdn.video-leech.pro link
            if (buttonLink.contains('cdn.video-leech.pro')) {
              try {
                final apiUrl = 'https://ssbackend-2r7z.onrender.com/api/redirect?url=${Uri.encodeComponent(buttonLink)}';
                print('Tech extractor: Processing instant link through API: $apiUrl');
                
                final apiResponse = await http.get(Uri.parse(apiUrl), headers: headers);
                
                if (apiResponse.statusCode == 200) {
                  final jsonData = json.decode(apiResponse.body);
                  String? finalUrl = jsonData['finalUrl'];
                  
                  if (finalUrl != null) {
                    print('Tech extractor: Got finalUrl: $finalUrl');
                    
                    // Remove the video-seed.dev prefix if present
                    if (finalUrl.contains('video-seed.dev/?url=')) {
                      finalUrl = Uri.decodeComponent(finalUrl.split('video-seed.dev/?url=')[1]);
                      print('Tech extractor: Cleaned URL: $finalUrl');
                    }
                    
                    servers.add(Stream(
                      server: 'Instant Download',
                      link: finalUrl,
                      type: 'mkv',
                    ));
                  }
                }
              } catch (e) {
                print('Tech extractor: Instant Download API processing failed: $e');
              }
            }
          }
          
          // Also try the old seed token method for other instant downloads
          if (buttonLink != null && buttonLink.contains('=') && !buttonLink.contains('cdn.video-leech.pro')) {
            try {
              final instantToken = buttonLink.split('=')[1];
              final uri = Uri.parse(buttonLink);
              final videoSeedUrl = '${uri.scheme}://${uri.host}/api';
              
              final instantResponse = await http.post(
                Uri.parse(videoSeedUrl),
                body: {'keys': instantToken},
                headers: {
                  ...headers,
                  'x-token': videoSeedUrl,
                },
              );
              
              final jsonData = json.decode(instantResponse.body);
              if (jsonData['error'] == false && jsonData['url'] != null) {
                print('Tech extractor: Instant link found via token method');
                servers.add(Stream(
                  server: 'Gdrive-Instant',
                  link: jsonData['url'],
                  type: 'mkv',
                ));
              }
            } catch (e) {
              print('Tech extractor: Token instant link extraction failed: $e');
            }
          }
        }
      } catch (e) {
        print('Tech extractor: Instant link extraction failed: $e');
      }

      print('Tech extractor: Found ${servers.length} streams');
      return servers;
    } catch (e) {
      print('Tech extractor: Stream extraction error: $e');
      return [];
    }
  }
}
