import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/movie_info.dart';

class WatchHistoryStorage {
  static const String _historyKey = 'watch_history_items_v1';
  static const int _maxItems = 200;

  static Future<List<WatchHistoryItem>> getItems() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final items = decoded
          .whereType<Map>()
          .map((e) => WatchHistoryItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      items.sort((a, b) => b.watchedAt.compareTo(a.watchedAt));
      return items;
    } catch (_) {
      return [];
    }
  }

  static Future<void> addItem({
    required String movieUrl,
    required String title,
    required String imageUrl,
    required String provider,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await getItems();

    items.removeWhere((e) => e.movieUrl == movieUrl);
    items.insert(
      0,
      WatchHistoryItem(
        movieUrl: movieUrl,
        title: title,
        imageUrl: imageUrl,
        provider: provider,
        watchedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    if (items.length > _maxItems) {
      items.removeRange(_maxItems, items.length);
    }

    await prefs.setString(
      _historyKey,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> removeItem(String movieUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await getItems();
    items.removeWhere((e) => e.movieUrl == movieUrl);
    await prefs.setString(
      _historyKey,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }
}
