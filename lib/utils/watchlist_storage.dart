import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/movie_info.dart';

class WatchlistStorage {
  static const String _watchlistKey = 'watchlist_items_v1';

  static Future<List<WatchlistItem>> getItems() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_watchlistKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final items = decoded
          .whereType<Map>()
          .map((e) => WatchlistItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      items.sort((a, b) {
        return b.addedAt.compareTo(a.addedAt);
      });
      return items;
    } catch (_) {
      return [];
    }
  }

  static Future<bool> isInWatchlist(String movieUrl) async {
    final items = await getItems();
    return items.any((e) => e.movieUrl == movieUrl);
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
      WatchlistItem(
        movieUrl: movieUrl,
        title: title,
        imageUrl: imageUrl,
        provider: provider,
        addedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    await prefs.setString(
      _watchlistKey,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> removeItem(String movieUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await getItems();
    items.removeWhere((e) => e.movieUrl == movieUrl);
    await prefs.setString(
      _watchlistKey,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }
}
