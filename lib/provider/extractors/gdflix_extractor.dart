import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'gofile_extractor.dart';
import 'stream_types.dart';

class GdFlixExtractor {
  static const Map<String, String> headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.5',
  };

  static Future<List<Stream>> extractStreams(String link) async {
    try {
      final List<Stream> streamLinks = [];
      print('gdFlixExtracter: $link');

      final response = await http.get(Uri.parse(link), headers: headers);

      if (response.statusCode != 200) {
        print('gdFlixExtracter: Failed to fetch page: ${response.statusCode}');
        return [];
      }

      final document = html_parser.parse(response.body);

      // Resume cloud/bot processing
      await _processResumeCloud(document, link, streamLinks);

      // Instant link processing
      await _processInstantLink(document, streamLinks);

      // PixelDrain link processing
      await _processPixelDrain(document, streamLinks);

      // GoFile processing
      await _processGoFile(document, streamLinks);

      return streamLinks;
    } catch (error) {
      print('gdFlixExtracter error: $error');
      return [];
    }
  }

  static Future<void> _processResumeCloud(
    document,
    String link,
    List<Stream> streamLinks,
  ) async {
    try {
      final baseUrl = Uri.parse(link).origin;
      final resumeDriveElement = document.querySelector('.btn-secondary');
      final resumeDrive = resumeDriveElement?.attributes['href'] ?? '';

      print('resumeDrive: $resumeDrive');

      if (resumeDrive.isEmpty) return;

      if (resumeDrive.contains('indexbot')) {
        await _processResumeBot(resumeDrive, streamLinks);
      } else {
        await _processResumeCloudLink(baseUrl, resumeDrive, streamLinks);
      }
    } catch (err) {
      print('Resume link not found');
    }
  }

  static Future<void> _processResumeBot(
    String resumeDrive,
    List<Stream> streamLinks,
  ) async {
    try {
      final resumeBotRes = await http.get(
        Uri.parse(resumeDrive),
        headers: headers,
      );

      final tokenMatch = RegExp(
        r"formData\.append\('token', '([a-f0-9]+)'\)",
      ).firstMatch(resumeBotRes.body);
      final pathMatch = RegExp(
        r"fetch\('\/download\?id=([a-zA-Z0-9\/+]+)'",
      ).firstMatch(resumeBotRes.body);

      if (tokenMatch == null || pathMatch == null) {
        print('ResumeBot: Token or path not found');
        return;
      }

      final token = tokenMatch.group(1)!;
      final path = pathMatch.group(1)!;
      final baseUrl = resumeDrive.split('/download')[0];

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/download?id=$path'),
      );
      request.fields['token'] = token;
      request.headers.addAll({
        'Referer': resumeDrive,
        'Cookie': 'PHPSESSID=7e9658ce7c805dab5bbcea9046f7f308',
      });

      final streamedResponse = await request.send();
      final downloadResponse = await http.Response.fromStream(streamedResponse);

      if (downloadResponse.statusCode == 200) {
        final downloadData = json.decode(downloadResponse.body);
        final downloadUrl = downloadData['url'] as String?;

        if (downloadUrl != null) {
          print('resumeBotDownloadData: $downloadUrl');
          streamLinks.add(
            Stream(server: 'ResumeBot', link: downloadUrl, type: 'mkv'),
          );
        }
      }
    } catch (err) {
      print('ResumeBot processing error: $err');
    }
  }

  static Future<void> _processResumeCloudLink(
    String baseUrl,
    String resumeDrive,
    List<Stream> streamLinks,
  ) async {
    try {
      final url = '$baseUrl$resumeDrive';
      final resumeDriveRes = await http.get(Uri.parse(url), headers: headers);

      final resumeDocument = html_parser.parse(resumeDriveRes.body);
      final resumeLinkElement = resumeDocument.querySelector('.btn-success');
      final resumeLink = resumeLinkElement?.attributes['href'];

      if (resumeLink != null && resumeLink.isNotEmpty) {
        streamLinks.add(
          Stream(server: 'ResumeCloud', link: resumeLink, type: 'mkv'),
        );
      }
    } catch (err) {
      print('ResumeCloud processing error: $err');
    }
  }

  static Future<void> _processInstantLink(
    document,
    List<Stream> streamLinks,
  ) async {
    try {
      final seedElement = document.querySelector('.btn-danger');
      final seed = seedElement?.attributes['href'] ?? '';

      print('seed: $seed');

      if (seed.isEmpty) return;

      // Check if it's an instant.busycdn.xyz link with :: separator
      if (seed.contains('instant.busycdn.xyz') && seed.contains('::')) {
        print('Processing instant.busycdn.xyz link with redirect API');
        await _processInstantBusyCdn(seed, streamLinks);
        return;
      }

      if (!seed.contains('?url=')) {
        // Process direct link
        final headResponse = await http.head(Uri.parse(seed), headers: headers);

        String newLink = headResponse.headers['location'] ?? seed;

        // Remove fastcdn-dl.pages.dev prefix if present
        if (newLink.contains('fastcdn-dl.pages.dev/?url=')) {
          final parts = newLink.split('?url=');
          if (parts.length > 1) {
            newLink = Uri.decodeComponent(parts[1]);
            print('Cleaned G-Drive link: $newLink');
          }
        }

        streamLinks.add(Stream(server: 'G-Drive', link: newLink, type: 'mkv'));
      } else {
        // Process instant token
        await _processInstantToken(seed, streamLinks);
      }
    } catch (err) {
      print('Instant link not found: $err');
    }
  }

  static Future<void> _processInstantBusyCdn(
    String seed,
    List<Stream> streamLinks,
  ) async {
    try {
      // Call the redirect API
      final apiUrl =
          'https://ssbackend-2r7z.onrender.com/api/redirect?url=${Uri.encodeComponent(seed)}';
      print('Calling redirect API: $apiUrl');

      final response = await http.get(Uri.parse(apiUrl), headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String finalUrl = data['finalUrl'] as String? ?? '';

        print('Redirect API response finalUrl: $finalUrl');

        if (finalUrl.isNotEmpty) {
          // Remove fastcdn-dl.pages.dev prefix if present
          if (finalUrl.contains('fastcdn-dl.pages.dev/?url=')) {
            final parts = finalUrl.split('fastcdn-dl.pages.dev/?url=');
            if (parts.length > 1) {
              finalUrl = Uri.decodeComponent(parts[1]);
              print('Cleaned G-Drive link from busycdn: $finalUrl');
            }
          }

          streamLinks.add(
            Stream(server: 'G-Drive', link: finalUrl, type: 'mkv'),
          );
        } else {
          print('Empty finalUrl in redirect API response');
        }
      } else {
        print('Redirect API failed with status: ${response.statusCode}');
      }
    } catch (err) {
      print('InstantBusyCdn processing error: $err');
    }
  }

  static Future<void> _processInstantToken(
    String seed,
    List<Stream> streamLinks,
  ) async {
    try {
      final instantToken = seed.split('=')[1];
      final seedUri = Uri.parse(seed);
      final videoSeedUrl = '${seedUri.scheme}://${seedUri.host}/api';

      final request = http.MultipartRequest('POST', Uri.parse(videoSeedUrl));
      request.fields['keys'] = instantToken;
      request.headers['x-token'] = videoSeedUrl;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['error'] == false && data['url'] != null) {
          streamLinks.add(
            Stream(server: 'Gdrive-Instant', link: data['url'], type: 'mkv'),
          );
        } else {
          print('Instant link not found: $data');
        }
      }
    } catch (err) {
      print('Instant token processing error: $err');
    }
  }

  static Future<void> _processPixelDrain(
    document,
    List<Stream> streamLinks,
  ) async {
    try {
      final pixelElement = document.querySelector('.btn-success');
      String pixelDrainLink = pixelElement?.attributes['href'] ?? '';

      print('pixelDrainLink: $pixelDrainLink');

      if (pixelDrainLink.isNotEmpty && pixelDrainLink.contains('pixeldrain')) {
        // Convert /u/TOKEN to /api/file/TOKEN
        if (pixelDrainLink.contains('/u/')) {
          final parts = pixelDrainLink.split('/u/');
          if (parts.length > 1) {
            final token = parts[1].split('?')[0];
            if (token.isNotEmpty) {
              final baseUrl = parts[0];
              pixelDrainLink = '$baseUrl/api/file/$token';
              print('Converted pixeldrain link to: $pixelDrainLink');
            }
          }
        }

        streamLinks.add(
          Stream(server: 'Pixeldrain', link: pixelDrainLink, type: 'mkv'),
        );
      }
    } catch (err) {
      print('PixelDrain link not found: $err');
    }
  }

  static Future<void> _processGoFile(document, List<Stream> streamLinks) async {
    try {
      // Find GoFile [Multiup] button
      final gofileElements = document.querySelectorAll('a.btn-outline-info');
      String? gofileButton;

      for (final element in gofileElements) {
        if (element.text.contains('GoFile [Multiup]')) {
          gofileButton = element.attributes['href'];
          break;
        }
      }

      print('gofileButton link: $gofileButton');

      if (gofileButton == null || gofileButton.isEmpty) return;

      final gofileMirrorRes = await http.get(
        Uri.parse(gofileButton),
        headers: headers,
      );

      final gofileMirrorDoc = html_parser.parse(gofileMirrorRes.body);
      final gofileLinkElement = gofileMirrorDoc.querySelector(
        'footer.panel-footer a[namehost="gofile.io"]',
      );
      final gofileLink = gofileLinkElement?.attributes['href'];

      print('gofileLink: $gofileLink');

      if (gofileLink != null && gofileLink.contains('/d/')) {
        final parts = gofileLink.split('/d/');
        if (parts.length > 1) {
          final gofileId = parts[1];
          print('gofileId: $gofileId');

          final gofileResult = await GofileExtractor.extractLink(gofileId);
          if (gofileResult.success && gofileResult.link.isNotEmpty) {
            streamLinks.add(
              Stream(
                server: 'GoFile',
                link: gofileResult.link,
                type: 'mkv',
                headers: {
                  'referer': 'https://gofile.io/',
                  'cookie': 'accountToken=${gofileResult.token}',
                },
              ),
            );
          }
        }
      }
    } catch (err) {
      print('GoFile link not found: $err');
    }
  }
}
