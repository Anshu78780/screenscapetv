import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../extractors/hubcloud_extractor.dart';
import 'headers.dart';
import 'get_redirect_links.dart';

/// Extract streaming links from hdhub4u, focusing on HubCloud links
Future<List<Stream>> hdhubGetStream(String link, String type) async {
  try {
    // Handle hubcdn.fans links directly
    if (link.contains('hubcdn.fans')) {
      return await _handleHubcdnFans(link);
    }

    String finalLink = link;

    // Only call external API for gadgetsweb.xyz links
    if (link.contains('gadgetsweb.xyz') && link.contains('?id=')) {
      print('Detected gadgetsweb.xyz link, calling external API');
      finalLink = await getRedirectLinks(link);
      print('Got hubcloud link from API: $finalLink');
    }
    // For hubdrive links, extract the hubcloud link
    else if (link.contains('hubdrive') && !link.contains('hubcloud')) {
      print('Detected hubdrive link, extracting hubcloud link');
      finalLink = await _extractHubcloudFromHubdrive(link);
      print('Extracted hubcloud link: $finalLink');
    }
    // For other links (including direct hubcloud links), use as-is
    else {
      print('Using link as-is: $link');
    }
    
    // Use the Drive provider's HubCloudExtractor for all links
    print('Extracting streams from: $finalLink');
    final result = await HubCloudExtractor.extractLinks(finalLink);
    
    if (result.success) {
      return result.streams;
    } else {
      print('HubCloud extraction failed');
      return [];
    }
  } catch (error) {
    print('hdhub getStream error: $error');
    return [];
  }
}

/// Handle hubcdn.fans links
Future<List<Stream>> _handleHubcdnFans(String link) async {
  try {
    print('Processing hubcdn.fans link: $link');
    final response = await http.get(Uri.parse(link), headers: HdhubHeaders.headers);
    final text = response.body;

    // Extract reurl from script tag
    final reurlMatch = RegExp(r'var reurl = "([^"]+)"').firstMatch(text);
    if (reurlMatch != null && reurlMatch.group(1) != null) {
      final reurlValue = reurlMatch.group(1)!;
      print('Found reurl: $reurlValue');

      // Extract base64 encoded part after r=
      final urlMatch = RegExp(r'\?r=(.+)$').firstMatch(reurlValue);
      if (urlMatch != null && urlMatch.group(1) != null) {
        final base64Encoded = urlMatch.group(1)!;
        print('Base64 encoded part: $base64Encoded');

        try {
          // Decode base64
          final decodedUrl = utf8.decode(base64.decode(base64Encoded));
          print('Decoded URL: $decodedUrl');
          
          // Extract the actual video URL from link= parameter
          String finalVideoUrl = decodedUrl;
          final linkMatch = RegExp(r'[?&]link=(.+)$').firstMatch(decodedUrl);
          if (linkMatch != null && linkMatch.group(1) != null) {
            finalVideoUrl = Uri.decodeComponent(linkMatch.group(1)!);
            print('Extracted video URL: $finalVideoUrl');
          }
          
          return [
            Stream(
              server: 'HDHub4u Direct',
              link: finalVideoUrl,
              type: 'mp4',
            ),
          ];
        } catch (decodeError) {
          print('Error decoding base64: $decodeError');
        }
      }
    }

    print('reurl extraction failed, falling back to original method');
    return [];
  } catch (error) {
    print('Error processing hubcdn.fans link: $error');
    return [];
  }
}

/// Extract final hubcloud link from hubdrive link
Future<String> _extractHubcloudFromHubdrive(String hubdriveLink) async {
  try {
    print('Extracting hubcloud from hubdrive: $hubdriveLink');
    
    // Add cookie for hubdrive.space requests
    final headers = Map<String, String>.from(HdhubHeaders.headers);
    if (hubdriveLink.contains('hubdrive.space')) {
      headers['Cookie'] = '_ga=GA1.1.493445100.1760626325; _ga_8QTNRD0R4M=GS2.1.s1763882919\$o4\$g0\$t1763882919\$j60\$l0\$h0';
    }
    
    final response = await http.get(Uri.parse(hubdriveLink), headers: headers);
    final document = html_parser.parse(response.body);
    
    // Look for HubCloud Server link in the specific button structure
    final hubcloudLink = document.querySelector('h5 a.btn.btn-primary.btn-user.btn-success1[href*="hubcloud"]')?.attributes['href'] ??
                         document.querySelector('.btn.btn-primary.btn-user.btn-success1.m-1[href*="hubcloud"]')?.attributes['href'];
    
    if (hubcloudLink != null && hubcloudLink.isNotEmpty) {
      print('Extracted hubcloud link: $hubcloudLink');
      
      // Check for meta refresh in the hubcloud link
      final finalResponse = await http.get(Uri.parse(hubcloudLink), headers: HdhubHeaders.headers);
      final metaRefreshMatch = RegExp(r'<META HTTP-EQUIV="refresh" content="0; url=([^"]+)">', caseSensitive: false).firstMatch(finalResponse.body);
      final finalLink = metaRefreshMatch?.group(1) ?? hubcloudLink;
      
      print('Final hubcloud link: $finalLink');
      return finalLink;
    }
    
    print('No hubcloud link found, returning original');
    return hubdriveLink;
  } catch (error) {
    print('Error extracting hubcloud from hubdrive: $error');
    return hubdriveLink;
  }
}