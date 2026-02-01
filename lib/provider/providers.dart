import 'dart:convert';
import 'package:http/http.dart' as http;

class ProviderData {
  final String name;
  final String url;

  ProviderData({required this.name, required this.url});

  factory ProviderData.fromJson(Map<String, dynamic> json) {
    return ProviderData(
      name: json['name'] ?? '',
      url: json['url'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'url': url,
    };
  }
}

class Providers {
  static const String providersUrl = 'https://anshu78780.github.io/json/providers.json';

  /// Fetch providers from the JSON endpoint
  static Future<Map<String, ProviderData>> fetchProviders() async {
    try {
      final response = await http.get(Uri.parse(providersUrl));

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        final Map<String, ProviderData> providers = {};

        jsonData.forEach((key, value) {
          if (value is Map<String, dynamic>) {
            providers[key] = ProviderData.fromJson(value);
          }
        });

        return providers;
      } else {
        throw Exception('Failed to load providers: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching providers: $e');
    }
  }

  /// Get a specific provider by key
  static Future<ProviderData?> getProvider(String key) async {
    try {
      final providers = await fetchProviders();
      return providers[key];
    } catch (e) {
      print('Error getting provider: $e');
      return null;
    }
  }

  /// Get the drive provider specifically
  static Future<ProviderData?> getDriveProvider() async {
    return await getProvider('drive');
  }
}
