import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../extractors/hubcloud_extractor.dart';
import '../extractors/stream_types.dart' as stream_types;
import 'headers.dart';
import 'get_redirect_links.dart';

/// Extract streaming links from khdhub, focusing on HubCloud links
Future<List<stream_types.Stream>> khdHubGetStream(
  String link,
  String type,
) async {
  try {
    print('[khdhub] Processing stream link: $link');

    // Handle hubcdn.fans links directly
    if (link.contains('hubcdn.fans')) {
      return await _handleHubcdnFans(link);
    }

    String finalLink = link;

    // Check if this is a redirect link that needs processing
    if (link.contains('?id=') || link.contains('redirect')) {
      print('[khdhub] Detected redirect link, calling external API');
      finalLink = await getRedirectLinks(link);
      print('[khdhub] Got link from API: $finalLink');
      
      // If API returned a hubdrive link, extract hubcloud from it
      if (finalLink.contains('hubdrive') && !finalLink.contains('hubcloud')) {
        print('[khdhub] API returned hubdrive link, extracting hubcloud link');
        finalLink = await _extractHubcloudFromHubdrive(finalLink);
        print('[khdhub] Extracted hubcloud link: $finalLink');
      }
    }
    // For hubdrive links, extract the hubcloud link
    else if (link.contains('hubdrive') && !link.contains('hubcloud')) {
      print('[khdhub] Detected hubdrive link, extracting hubcloud link');
      finalLink = await _extractHubcloudFromHubdrive(link);
      print('[khdhub] Extracted hubcloud link: $finalLink');
    }
    // For other links (including direct hubcloud links), use as-is
    else {
      print('[khdhub] Using link as-is: $link');
    }

    // Use the HubCloudExtractor for all links
    print('[khdhub] Extracting streams from: $finalLink');
    final result = await HubCloudExtractor.extractLinks(finalLink);

    if (result.success) {
      return result.streams;
    } else {
      print('[khdhub] HubCloud extraction failed');
      return [];
    }
  } catch (error) {
    print('[khdhub] getStream error: $error');
    return [];
  }
}

/// Handle hubcdn.fans links
Future<List<stream_types.Stream>> _handleHubcdnFans(String link) async {
  try {
    print('[khdhub] Processing hubcdn.fans link: $link');
    final response = await http.get(
      Uri.parse(link),
      headers: khdHubHeaders,
    );
    final text = response.body;

    // Extract reurl from script tag
    final reurlMatch = RegExp(r'var reurl = "([^"]+)"').firstMatch(text);
    if (reurlMatch != null && reurlMatch.group(1) != null) {
      final reurlValue = reurlMatch.group(1)!;
      print('[khdhub] Found reurl: $reurlValue');

      // Extract base64 encoded part after r=
      final urlMatch = RegExp(r'\?r=(.+)$').firstMatch(reurlValue);
      if (urlMatch != null && urlMatch.group(1) != null) {
        final base64Encoded = urlMatch.group(1)!;
        print('[khdhub] Base64 encoded part: $base64Encoded');

        try {
          // Decode base64
          final decodedUrl = utf8.decode(base64.decode(base64Encoded));
          print('[khdhub] Decoded URL: $decodedUrl');

          // Extract hubcloud link from the decoded URL
          if (decodedUrl.contains('hubcloud')) {
            return await HubCloudExtractor.extractLinks(decodedUrl).then((result) {
              return result.success ? result.streams : [];
            });
          }
        } catch (e) {
          print('[khdhub] Base64 decode error: $e');
        }
      }
    }

    print('[khdhub] Could not extract hubcloud link from hubcdn.fans');
    return [];
  } catch (error) {
    print('[khdhub] Error handling hubcdn.fans: $error');
    return [];
  }
}

/// Extract HubCloud link from HubDrive page
Future<String> _extractHubcloudFromHubdrive(String hubdriveLink) async {
  try {
    print('[khdhub] Fetching hubdrive page: $hubdriveLink');
    final response = await http.get(
      Uri.parse(hubdriveLink),
      headers: khdHubHeaders,
    );

    if (response.statusCode != 200) {
      print('[khdhub] Failed to fetch hubdrive page');
      return hubdriveLink;
    }

    final document = html_parser.parse(response.body);

    // Look for hubcloud link in various places
    final hubcloudLink = document.querySelector('a[href*="hubcloud"]')?.attributes['href'] ??
                        document.querySelector('iframe[src*="hubcloud"]')?.attributes['src'];

    if (hubcloudLink != null && hubcloudLink.isNotEmpty) {
      print('[khdhub] Found hubcloud link in page: $hubcloudLink');
      return hubcloudLink;
    }

    print('[khdhub] No hubcloud link found in hubdrive page');
    return hubdriveLink;
  } catch (error) {
    print('[khdhub] Error extracting from hubdrive: $error');
    return hubdriveLink;
  }
}
