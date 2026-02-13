import 'package:shared_preferences/shared_preferences.dart';

class TelegramHelper {
  static const String _keyJoined = 'telegram_channel_joined';
  static const String _keyIgnoreUntil = 'telegram_ignore_until';
  static const String telegramChannelUrl = 'https://t.me/Filmfansmovie';

  static Future<bool> shouldShowJoinDialog() async {
    final prefs = await SharedPreferences.getInstance();
    
    final hasJoined = prefs.getBool(_keyJoined) ?? false;
    if (hasJoined) {
      return false;
    }
    
    final ignoreUntil = prefs.getInt(_keyIgnoreUntil) ?? 0;
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    
    if (currentTime < ignoreUntil) {
      return false;
    }
    
    return true;
  }

  static Future<void> markAsJoined() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyJoined, true);
    await prefs.remove(_keyIgnoreUntil);
  }

  static Future<void> ignoreFor5Hours() async {
    final prefs = await SharedPreferences.getInstance();
    final ignoreUntil = DateTime.now().add(const Duration(hours: 5)).millisecondsSinceEpoch;
    await prefs.setInt(_keyIgnoreUntil, ignoreUntil);
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyJoined);
    await prefs.remove(_keyIgnoreUntil);
  }
}
