import 'dart:convert';
import 'package:http/http.dart' as http;

class Stream {
  final String server;
  final String link;
  final String type;

  Stream({
    required this.server,
    required this.link,
    required this.type,
  });

  factory Stream.fromJson(Map<String, dynamic> json) {
    return Stream(
      server: json['server'] ?? '',
      link: json['link'] ?? '',
      type: json['type'] ?? '',
    );
  }
}

class HubCloudResponse {
  final bool success;
  final List<Stream> streams;

  HubCloudResponse({
    required this.success,
    required this.streams,
  });

  factory HubCloudResponse.fromJson(Map<String, dynamic> json) {
    // The API returns streams nested under 'data'
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final streamsList = data['streams'] as List<dynamic>? ?? [];
    return HubCloudResponse(
      success: json['success'] ?? false,
      streams: streamsList.map((s) => Stream.fromJson(s)).toList(),
    );
  }
}

class HubCloudExtractor {
  static const String baseUrl = 'https://screenscapeapi.dev'; 
  static const String apiKey = 'sk_PEOMP8TQLYDXmBmQAqWLyJA2cp9nRyss'; 

  static Future<HubCloudResponse> extractLinks(String hubcloudUrl) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/extractors/hubcloud?url=${Uri.encodeComponent(hubcloudUrl)}'),
        headers: {
          'x-api-key': apiKey,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        print('API Response Body: ${response.body}');
        final data = json.decode(response.body);
        return HubCloudResponse.fromJson(data);
      } else {
        throw Exception('Failed to extract links: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error extracting HubCloud links: $e');
    }
  }
}
