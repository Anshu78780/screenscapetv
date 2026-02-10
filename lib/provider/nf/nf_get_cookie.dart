import 'package:http/http.dart' as http;
import 'dart:convert';

class NfCookieManager {
  static String? _cachedCookie;
  static DateTime? _cacheTime;
  static const _cacheTimeout = Duration(hours: 1); // Cache for 1 hour

  /// Fetch the cookie from the remote JSON endpoint
  static Future<String> getCookie() async {
    // Return cached cookie if still valid
    if (_cachedCookie != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheTimeout) {
      return _cachedCookie!;
    }

    try {
      final response = await http.get(
        Uri.parse('https://anshu78780.github.io/json/cookies.json'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['cookies'] != null && data['cookies'].isNotEmpty) {
          _cachedCookie = data['cookies'] as String;
          _cacheTime = DateTime.now();
          print('NF: Successfully fetched cookie');
          return _cachedCookie!;
        }
      }

      print('NF: Failed to fetch cookie from API (${response.statusCode})');
      return '';
    } catch (error) {
      print('NF: Error fetching cookie: $error');
      return '';
    }
  }

  /// Clear the cached cookie
  static void clearCache() {
    _cachedCookie = null;
    _cacheTime = null;
  }
}
