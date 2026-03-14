import 'package:shared_preferences/shared_preferences.dart';

class PlaybackProgressCache {
  static const String _prefix = 'playback_progress_v1::';

  static Future<Duration> getProgress(String movieTitle) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _keyFor(movieTitle);
    final millis = prefs.getInt(key) ?? 0;
    if (millis <= 0) return Duration.zero;
    return Duration(milliseconds: millis);
  }

  static Future<void> saveProgress({
    required String movieTitle,
    required Duration position,
    Duration? duration,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _keyFor(movieTitle);

    if (_shouldClearProgress(position: position, duration: duration)) {
      await prefs.remove(key);
      return;
    }

    // Ignore very early playback positions to avoid resuming at the intro.
    if (position.inSeconds < 15) {
      return;
    }

    await prefs.setInt(key, position.inMilliseconds);
  }

  static Future<void> clearProgress(String movieTitle) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyFor(movieTitle));
  }

  static String _keyFor(String movieTitle) {
    final normalized = movieTitle.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    return '$_prefix$normalized';
  }

  static bool _shouldClearProgress({
    required Duration position,
    Duration? duration,
  }) {
    if (duration == null || duration <= Duration.zero) return false;

    final remaining = duration - position;
    return remaining <= const Duration(seconds: 90);
  }
}
