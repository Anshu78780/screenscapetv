import 'package:flutter/material.dart';

/// Provider Manager - Manages the active content provider
/// 
/// This singleton class tracks which provider is currently active (Drive, Netflix, etc.)
/// and notifies listeners when the provider changes.
/// 
/// To add a new provider:
/// 1. Create a new folder under lib/provider/ (e.g., lib/provider/netflix/)
/// 2. Add an index.dart file to export all provider modules
/// 3. Add the provider to availableProviders list below
/// 4. Update _loadMovies() in movies_screen.dart to handle the new provider
/// 5. Update _loadMovieInfo() in info.dart to handle the new provider
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
