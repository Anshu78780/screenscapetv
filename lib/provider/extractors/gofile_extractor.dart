import 'dart:convert';
import 'package:http/http.dart' as http;

class GofileResponse {
  final bool success;
  final String link;
  final String token;
  final String? message;

  GofileResponse({
    required this.success,
    required this.link,
    required this.token,
    this.message,
  });

  factory GofileResponse.fromSuccess({
    required String link,
    required String token,
  }) {
    return GofileResponse(
      success: true,
      link: link,
      token: token,
    );
  }

  factory GofileResponse.fromError({
    required String message,
  }) {
    return GofileResponse(
      success: false,
      link: '',
      token: '',
      message: message,
    );
  }
}

class GofileExtractor {
  static const Map<String, String> headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'application/json, text/plain, */*',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  static Future<GofileResponse> extractLink(String id) async {
    try {
      print('gofile extractor: starting extraction for id: $id');

      // Step 1: Generate account and get token
      final accountResponse = await http.post(
        Uri.parse('https://api.gofile.io/accounts'),
        headers: headers,
      );

      if (accountResponse.statusCode != 200) {
        throw Exception('Failed to create account: ${accountResponse.statusCode}');
      }

      final accountData = json.decode(accountResponse.body);
      if (accountData['status'] != 'ok') {
        throw Exception('Account creation failed: ${accountData['status']}');
      }

      final token = accountData['data']['token'] as String;
      print('gofile token: $token');

      // Step 2: Fetch content with the token
      print('gofile fetching content for id: $id');
      final contentResponse = await http.get(
        Uri.parse(
          'https://api.gofile.io/contents/$id?contentFilter=&page=1&pageSize=1000&sortField=name&sortDirection=1',
        ),
        headers: {
          ...headers,
          'Authorization': 'Bearer $token',
          'x-website-token': '4fd6sg89d7s6',
          'origin': 'https://gofile.io',
          'referer': 'https://gofile.io/',
        },
      );

      if (contentResponse.statusCode != 200) {
        throw Exception('Failed to fetch content: ${contentResponse.statusCode}');
      }

      final contentData = json.decode(contentResponse.body);
      print('gofile response status: ${contentData['status']}');

      if (contentData['status'] != 'ok') {
        throw Exception('Content fetch failed: ${contentData['status']}');
      }

      final childrenData = contentData['data']?['children'] as Map<String, dynamic>?;
      if (childrenData == null || childrenData.isEmpty) {
        throw Exception('No children found in response data');
      }

      print('gofile response data keys: ${contentData['data']?.keys?.toList() ?? []}');

      // Get the first child's link
      final firstChildId = childrenData.keys.first;
      final firstChild = childrenData[firstChildId] as Map<String, dynamic>;
      final link = firstChild['link'] as String?;

      if (link == null || link.isEmpty) {
        throw Exception('No valid link found in first child');
      }

      print('gofile extractor link: $link');

      return GofileResponse.fromSuccess(
        link: link,
        token: token,
      );
    } catch (e) {
      final errorMessage = e.toString();
      print('gofile extractor error: $errorMessage');
      return GofileResponse.fromError(
        message: errorMessage.contains('Exception:') 
          ? errorMessage.replaceFirst('Exception: ', '')
          : 'Failed to extract gofile link',
      );
    }
  }
}