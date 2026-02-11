import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'headers.dart';

/// Follow redirects using external API and extract hubcloud link
Future<String> getRedirectLinks(String url) async {
  try {
    print('[khdhub] Getting redirect link for: $url');
    
    // Call the external API to get the redirected URL
    final apiUrl = 'https://screenscapeapi.dev/api/hdhub4u/extractor?url=${Uri.encodeComponent(url)}';
    print('[khdhub] Calling API: $apiUrl');
    
    final apiResponse = await http.get(
      Uri.parse(apiUrl),
    ).timeout(const Duration(seconds: 15), onTimeout: () {
      print('[khdhub] API request timeout');
      throw Exception('API request timeout');
    });

    if (apiResponse.statusCode != 200) {
      print('[khdhub] API request failed with status: ${apiResponse.statusCode}');
      return url;
    }

    // Parse the API response
    final apiData = json.decode(apiResponse.body);
    
    if (apiData['success'] != true || apiData['redirectUrl'] == null) {
      print('[khdhub] API returned unsuccessful response or no redirectUrl');
      return url;
    }

    final redirectUrl = apiData['redirectUrl'].toString();
    print('[khdhub] Got redirectUrl from API: $redirectUrl');

    // If the API already returned a hubcloud/hubdrive link, return it directly
    if (redirectUrl.contains('hubcloud') || redirectUrl.contains('hubdrive')) {
      print('[khdhub] API returned direct hubcloud/hubdrive link, using it directly');
      return redirectUrl;
    }

    // Fetch the redirect page to extract the hubcloud link
    print('[khdhub] Fetching redirect page: $redirectUrl');
    final redirectResponse = await http.get(
      Uri.parse(redirectUrl),
      headers: khdHubHeaders,
    ).timeout(const Duration(seconds: 10), onTimeout: () {
      print('[khdhub] Redirect page fetch timeout');
      throw Exception('Redirect page fetch timeout');
    });

    if (redirectResponse.statusCode != 200) {
      print('[khdhub] Failed to fetch redirect page, status: ${redirectResponse.statusCode}');
      return redirectUrl; // Return the redirect URL as fallback
    }

    // Parse HTML to extract hubcloud link
    final document = html_parser.parse(redirectResponse.body);
    
    // Try to find anchor with hubcloud link
    final hubcloudLink = document.querySelector('a[href*="hubcloud"]')?.attributes['href'];
    
    if (hubcloudLink != null && hubcloudLink.isNotEmpty) {
      print('[khdhub] Found hubcloud link: $hubcloudLink');
      return hubcloudLink;
    }

    // Try alternative selectors
    final altLink = document.querySelector('a[target="_blank"][href*="drive"]')?.attributes['href'] ??
                    document.querySelector('a[href*="hubdrive"]')?.attributes['href'];
    
    if (altLink != null && altLink.isNotEmpty) {
      print('[khdhub] Found alternative link: $altLink');
      return altLink;
    }

    print('[khdhub] No hubcloud/hubdrive link found in page, returning redirectUrl');
    return redirectUrl;

  } catch (error) {
    print('[khdhub] Error in getRedirectLinks: $error');
    return url;
  }
}
