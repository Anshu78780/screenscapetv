class NfCatalog {
  static String? _baseUrl;

  static const List<Map<String, String>> categories = [
    {'name': 'Home', 'path': '/home'},
    {'name': 'Top 10 Movies', 'path': 'top10:movies'},
    {'name': 'Top 10 Series', 'path': 'top10:series'},
    {'name': 'Movies', 'path': '/movies'},
    {'name': 'TV Shows', 'path': '/series'},
  ];

  static Future<String> get baseUrl async {
    if (_baseUrl != null) return _baseUrl!;

    _baseUrl = 'https://net22.cc';
    return _baseUrl!;
  }

  static void clearCache() {
    _baseUrl = null;
  }
}
