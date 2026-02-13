import 'package:flutter/material.dart';
class ProviderManager extends ChangeNotifier {
  static final ProviderManager _instance = ProviderManager._internal();
  factory ProviderManager() => _instance;
  ProviderManager._internal();

  String _activeProvider = 'Drive';
  
  String get activeProvider => _activeProvider;
  
  void setProvider(String provider) {
    if (_activeProvider != provider) {
      _activeProvider = provider;
      notifyListeners();
    }
  }
  
  // List of available providers
  static final List<Map<String, dynamic>> availableProviders = [
    {
      'id': 'Drive',
      'name': 'Drive',
      'icon': Icons.cloud,
    },
    {
      'id': 'Hdhub',
      'name': 'Hdhub4u',
      'icon': Icons.movie_filter,
    },
    {
      'id': 'Xdmovies',
      'name': 'Xdmovies',
      'icon': Icons.movie_outlined,
    },
    {
      'id': 'Desiremovies',
      'name': 'DesireMovies',
      'icon': Icons.local_movies_outlined,
    },
    {
      'id': 'Moviesmod',
      'name': 'Moviesmod',
      'icon': Icons.movie_creation_outlined,
    },
    {
      'id': 'Zinkmovies',
      'name': 'ZinkMovies',
      'icon': Icons.subscriptions_outlined,
    },
    {
      'id': 'Animesalt',
      'name': 'AnimeSalt',
      'icon': Icons.animation_outlined,
    },
    {
      'id': 'Movies4u',
      'name': 'Movies4u',
      'icon': Icons.video_library_outlined,
    },
    {
      'id': 'Vega',
      'name': 'VegaMovies',
      'icon': Icons.videocam_outlined,
    },
    {
      'id': 'Filmycab',
      'name': 'FilmyCab',
      'icon': Icons.local_movies,
    },
    {
      'id': 'Zeefliz',
      'name': 'Zeefliz',
      'icon': Icons.video_collection,
    },
    {
      'id': 'NfMirror',
      'name': 'Netflix Mirror',
      'icon': Icons.live_tv,
    },
    {
      'id': 'Animepahe',
      'name': 'AnimePahe',
      'icon': Icons.animation,
    },
    {
      'id': 'YoMovies',
      'name': 'YoMovies',
      'icon': Icons.play_circle_outline,
    },
    {
      'id': 'KhdHub',
      'name': '4kHDHub',
      'icon': Icons.hd_outlined,
    },
    {
      'id': 'Castle',
      'name': 'Castle',
      'icon': Icons.castle_outlined,
    },
    // Add more providers here in the future
    // {
    //   'id': 'Netflix',
    //   'name': 'Netflix',
    //   'icon': Icons.movie,
    // },
  ];
  
  Map<String, dynamic>? getProviderById(String id) {
    try {
      return availableProviders.firstWhere((p) => p['id'] == id);
    } catch (e) {
      return null;
    }
  }
}
