import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'stream_types.dart';

class HubCloudResponse {
  final bool success;
  final List<Stream> streams;

  HubCloudResponse({required this.success, required this.streams});
}

class HubCloudExtractor {
  static const Map<String, String> headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.5',
  };

  static String decode(String? value) {
    if (value == null || value.isEmpty) {
      return '';
    }
    try {
      return utf8.decode(base64.decode(value));
    } catch (e) {
      return '';
    }
  }

  static Future<HubCloudResponse> extractLinks(String link) async {
    try {
      print('hubcloudExtractor: $link');
      final baseUrl = Uri.parse(link).origin;
      final List<Stream> streamLinks = [];

      // Check if this looks like a direct hubcloud link (any hubcloud domain)
      String? vcloudLink;
      final uri = Uri.parse(link);
      final isHubcloudDomain = uri.host.contains('hubcloud');
      
      if (isHubcloudDomain) {
        print('Detected hubcloud domain, attempting direct extraction');
        
        try {
          final directRes = await http.get(Uri.parse(link), headers: headers);
          final directDoc = html_parser.parse(directRes.body);
          
          // Try to extract links directly from this page
          final directButtons = directDoc.querySelectorAll(
            'a.btn, .btn-success, .btn-danger, .btn-secondary, a[href*="download"]',
          );
          
          if (directButtons.isNotEmpty) {
            print('Found ${directButtons.length} direct buttons, processing them');
            
            // Find the first valid link - prefer gamerxyt links for full processing
            for (var element in directButtons) {
              final href = element.attributes['href'];
              if (href != null && href.isNotEmpty && href.startsWith('http')) {
                if (href.contains('gamerxyt.com') && href.contains('hubcloud.php')) {
                  // This needs further processing, set it as vcloudLink
                  vcloudLink = href;
                  print('Found gamerxyt.com link, will process through normal flow: $href');
                  break;
                } else {
                  // Direct playable link
                  streamLinks.add(Stream(server: 'HubCloud', link: href, type: 'mkv'));
                  print('Added direct playable link: $href');
                }
              }
            }
          }
          
          print('Continuing with normal flow for further processing');
        } catch (e) {
          print('Error in direct extraction attempt: $e, falling back to normal flow');
        }
      }

      // Step 1: Get initial page (skip if we already have vcloudLink from direct extraction)
      if (vcloudLink == null) {
        final vLinkRes = await http.get(Uri.parse(link), headers: headers);
        final vLinkText = vLinkRes.body;
        final vLinkDoc = html_parser.parse(vLinkText);

        // Extract redirect URL from JavaScript - try multiple patterns
        final patterns = [
          RegExp(r"var\s+url\s*=\s*'([^']+)'"),
          RegExp(r"const\s+url\s*=\s*'([^']+)'"),
          RegExp(r"let\s+url\s*=\s*'([^']+)'"),
          RegExp(r"url\s*=\s*'([^']+)'"),
          RegExp(r'var\s+url\s*=\s*"([^"]+)"'),
          RegExp(r'const\s+url\s*=\s*"([^"]+)"'),
          RegExp(r'let\s+url\s*=\s*"([^"]+)"'),
          RegExp(r'url\s*=\s*"([^"]+)"'),
        ];

        String? redirectUrl;

        for (var pattern in patterns) {
          final match = pattern.firstMatch(vLinkText);
          if (match != null && match.group(1) != null) {
            redirectUrl = match.group(1);
            print('Found redirect URL pattern: $redirectUrl');
            break;
          }
        }

        if (redirectUrl != null) {
          final rParam = Uri.parse(redirectUrl).queryParameters['r'];
          if (rParam != null && rParam.isNotEmpty) {
            vcloudLink = decode(rParam);
            print('Decoded vcloudLink from r parameter: $vcloudLink');
          } else {
            // If no 'r' parameter, use the redirect URL directly
            vcloudLink = redirectUrl;
            print('Using redirect URL directly: $vcloudLink');
          }
        }

        // Fallback to download button
        if (vcloudLink == null || vcloudLink.isEmpty) {
          print('No JavaScript redirect found, looking for download button');
          final downloadButton = vLinkDoc
              .querySelector('.fa-file-download.fa-lg')
              ?.parent;
          if (downloadButton != null) {
            vcloudLink = downloadButton.attributes['href'] ?? link;
            print('Found download button: $vcloudLink');
          } else {
            print('No download button found, checking if current page has download links');
            // Check if this page already has download buttons
            final directButtons = vLinkDoc.querySelectorAll(
              '.btn-success.btn-lg.h6,.btn-danger,.btn-secondary',
            );
            if (directButtons.isNotEmpty) {
              print('Found ${directButtons.length} direct download buttons on current page');
              vcloudLink = link; // Use current page
            } else {
              print('No download buttons found, using original link as fallback');
              vcloudLink = link;
            }
          }
        }
      }

      print('vcloudLink: $vcloudLink');

      // Handle relative URLs
      if (vcloudLink.startsWith('/')) {
        vcloudLink = '$baseUrl$vcloudLink';
        print('New vcloudLink: $vcloudLink');
      }

      // Check if this is a gamerxyt.com hubcloud.php link (domain-agnostic check)
      if (vcloudLink.contains('gamerxyt.com') && vcloudLink.contains('hubcloud.php')) {
        print('Detected gamerxyt.com hubcloud.php link');

        try {
          final gamerxytRes = await http.get(
            Uri.parse(vcloudLink),
            headers: {...headers, 'Referer': baseUrl},
          );

          final gamerxytDoc = html_parser.parse(gamerxytRes.body);
          print('gamerxyt.com page loaded, extracting links...');

          final linkElements = gamerxytDoc.querySelectorAll('a.btn');
          final futures = <Future>[];

          for (final element in linkElements) {
            final href = element.attributes['href'];
            final buttonText = element.text.trim();

            if (href != null &&
                (href.startsWith('http://') || href.startsWith('https://'))) {
              // Skip certain links
              if (href.contains('telegram') ||
                  href.contains('bloggingvector') ||
                  href.contains('ampproject.org') ||
                  buttonText.toLowerCase().contains('telegram')) {
                continue;
              }

              print('Found button: $buttonText - $href');

              if (buttonText.contains('FSL Server') ||
                  buttonText.contains('FSLv2 Server') ||
                  href.contains('.r2.dev') ||
                  href.contains('fsl.cdnbaba') ||
                  href.contains('cdn.fsl-buckets')) {
                streamLinks.add(
                  Stream(server: 'Cf Worker', link: href, type: 'mkv'),
                );
                print('Added Cf Worker link: $href');
              } else if (href.contains('gpdl2.hubcdn.fans') ||
                  href.contains('gpdl.hubcdn.fans')) {
                futures.add(_extractGpdlLink(href, streamLinks));
              } else if (href.contains('pixel.hubcdn.fans')) {
                futures.add(_extractPixelLink(href, streamLinks));
              } else if (buttonText.contains('PixeLServer') ||
                  href.contains('pixeldrain.dev')) {
                String pixeldrainLink = href;
                if (href.contains('/u/')) {
                  final token = href.split('/u/')[1].split('?')[0];
                  final base = href.split('/u/')[0];
                  pixeldrainLink = '$base/api/file/$token';
                  print('Converted pixeldrain link: $href -> $pixeldrainLink');
                }
                streamLinks.add(
                  Stream(
                    server: 'Pixeldrain',
                    link: pixeldrainLink,
                    type: 'mkv',
                  ),
                );
                print('Added Pixeldrain link: $pixeldrainLink');
              } else if (href.contains('mega.hubcloud') ||
                  buttonText.toLowerCase().contains('mega')) {
                streamLinks.add(
                  Stream(server: 'Mega', link: href, type: 'mkv'),
                );
                print('Added Mega link: $href');
              } else if (href.contains('cloudserver') ||
                  href.contains('workers.dev') ||
                  buttonText.toLowerCase().contains('zipdisk')) {
                streamLinks.add(
                  Stream(server: 'ZipDisk', link: href, type: 'zip'),
                );
                print('Added ZipDisk link: $href');
              } else if (href.contains('cloudflarestorage')) {
                streamLinks.add(
                  Stream(server: 'CfStorage', link: href, type: 'mkv'),
                );
                print('Added CfStorage link: $href');
              } else if (href.contains('fastdl')) {
                streamLinks.add(
                  Stream(server: 'FastDl', link: href, type: 'mkv'),
                );
                print('Added FastDl link: $href');
              }
            }
          }

          await Future.wait(futures);
          print('Extracted ${streamLinks.length} links from gamerxyt.com');
          return HubCloudResponse(success: true, streams: streamLinks);
        } catch (e) {
          print('Error in gamerxyt.com request: $e');
        }
      }

      // Original flow for non-gamerxyt links
      final vcloudRes = await http.get(Uri.parse(vcloudLink), headers: headers);
      final vcloudDoc = html_parser.parse(vcloudRes.body);
      print('vcloudRes page loaded, looking for download links...');

      // Try multiple selector patterns for different hubcloud page layouts
      final selectors = [
        '.btn-success.btn-lg.h6,.btn-danger,.btn-secondary',
        '.btn-success,.btn-danger,.btn-secondary',
        'a.btn',
        'a[href*="download"]',
        'a[href*="pixeld"]',
        'a[href*="hubcdn"]',
        'a[href*=".dev"]',
      ];

      List<dynamic> linkElements = [];
      for (var selector in selectors) {
        linkElements = vcloudDoc.querySelectorAll(selector);
        if (linkElements.isNotEmpty) {
          print('Found ${linkElements.length} links using selector: $selector');
          break;
        }
      }

      if (linkElements.isEmpty) {
        print('WARNING: No download links found with any selector');
        print('Page URL: $vcloudLink');
        print('Page title: ${vcloudDoc.querySelector('title')?.text ?? 'No title'}');
        
        // Try to find any links on the page for debugging
        final allLinks = vcloudDoc.querySelectorAll('a[href]');
        print('Total links found on page: ${allLinks.length}');
        if (allLinks.isNotEmpty && allLinks.length < 20) {
          for (var link in allLinks) {
            final href = link.attributes['href'];
            final text = link.text.trim();
            print('  Link: $text -> $href');
          }
        }
      }

      for (final element in linkElements) {
        String? link = element.attributes['href'];
        if (link == null || link.isEmpty) continue;

        if (link.contains('.dev') && !link.contains('/?id=')) {
          streamLinks.add(Stream(server: 'Cf Worker', link: link, type: 'mkv'));
        }

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
        }

        if (link.contains('hubcloud') || link.contains('/?id=')) {
          try {
            final client = http.Client();
            final request = http.Request('HEAD', Uri.parse(link))
              ..headers.addAll(headers);
            final response = await client.send(request);
            final newLink =
                response.headers['location']?.split('link=').last ?? link;
            streamLinks.add(
              Stream(server: 'hubcloud', link: newLink, type: 'mkv'),
            );
            client.close();
          } catch (e) {
            print('Error in hubcloud link: $e');
          }
        }

        if (link.contains('cloudflarestorage')) {
          streamLinks.add(Stream(server: 'CfStorage', link: link, type: 'mkv'));
        }

        if (link.contains('fastdl')) {
          streamLinks.add(Stream(server: 'FastDl', link: link, type: 'mkv'));
        }

        if (link.contains('hubcdn')) {
          streamLinks.add(Stream(server: 'HubCdn', link: link, type: 'mkv'));
        }
      }

      print('Returning final streamLinks: ${streamLinks.length} links');
      return HubCloudResponse(success: true, streams: streamLinks);
    } catch (e) {
      print('hubcloudExtractor error: $e');
      return HubCloudResponse(success: false, streams: []);
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
        headers: headers,
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
        headers: headers,
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
}
