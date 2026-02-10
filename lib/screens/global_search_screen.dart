import 'package:flutter/material.dart';
import '../models/movie.dart';
import '../models/movie_info.dart';
import '../provider/provider_manager.dart';
import '../utils/key_event_handler.dart';
import '../provider/drive/getpost.dart' as drive;
import '../provider/hdhub/getpost.dart';
import '../provider/xdmovies/getpost.dart';
import '../provider/desiremovies/getpost.dart';
import '../provider/moviesmod/getpost.dart';
import '../provider/zinkmovies/getpost.dart';
import '../provider/animesalt/getpost.dart';
import '../provider/movies4u/getpost.dart';
import 'info.dart';

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _verticalScrollController = ScrollController();
  final Map<String, ScrollController> _horizontalScrollControllers = {};
  
  // Map to store results: ProviderID -> List of Movies
  final Map<String, List<Movie>> _results = {};
  
  // Map to store loading state: ProviderID -> bool
  final Map<String, bool> _loading = {};
  
  // Map to store errors/empty states if needed, or just rely on empty list
  final Map<String, String> _errors = {};

  bool _hasSearched = false;
  
  // Selection state
  int _selectedProviderIndex = -1; // -1 means focus is on search bar
  int _selectedMovieIndex = 0;

  @override
  void initState() {
    super.initState();
    // Auto-focus search on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _verticalScrollController.dispose();
    for (var controller in _horizontalScrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // Get list of providers that are actually visible (loading or have results)
  List<String> _getVisibleProviders() {
    return ProviderManager.availableProviders
        .map((p) => p['id'] as String)
        .where((id) {
           final isLoading = _loading[id] == true;
           final results = _results[id] ?? [];
           return isLoading || results.isNotEmpty;
        }).toList();
  }

  void _performGlobalSearch(String query) {
    if (query.trim().isEmpty) return;
    
    // Unfocus search bar to allow navigation
    _searchFocusNode.unfocus();

    setState(() {
      _hasSearched = true;
      _results.clear();
      _errors.clear();
      _loading.clear();
      _selectedProviderIndex = -1; // Keep focus on search bar initially
    });

    final providers = ProviderManager.availableProviders;
    
    for (var provider in providers) {
      final providerId = provider['id'] as String;
      _searchProvider(providerId, query);
    }
  }

  Future<void> _searchProvider(String providerId, String query) async {
    setState(() {
      _loading[providerId] = true;
    });

    try {
      List<Movie> movies = [];
      
      // Call appropriate search function based on provider ID
      switch (providerId) {
        case 'Drive':
          movies = await drive.GetPost.searchMovies(query);
          break;
        case 'Hdhub':
          movies = await HdhubGetPost.searchMovies(query);
          break;
        case 'Xdmovies':
          movies = await XdmoviesGetPost.searchMovies(query);
          break;
        case 'Desiremovies':
          movies = await DesireMoviesGetPost.searchMovies(query);
          break;
        case 'Moviesmod':
          movies = await MoviesmodGetPost.searchMovies(query);
          break;
        case 'Zinkmovies':
          movies = await zinkmoviesGetPostsSearch(query, 1);
          break;
        case 'Animesalt':
          movies = await animesaltGetPostsSearch(query, 1);
          break;
        case 'Movies4u':
          movies = await Movies4uGetPost.searchMovies(query);
          break;
        default:
          print('Unknown provider: $providerId');
      }

      if (mounted) {
        setState(() {
          _results[providerId] = movies;
          _loading[providerId] = false;
        });
        
        // If this is the first result and we're not focused on anything, 
        // essentially we keep waiting. User will navigate down manually.
      }
    } catch (e) {
      print('Error searching $providerId: $e');
      if (mounted) {
        setState(() {
          _errors[providerId] = e.toString();
          _loading[providerId] = false;
        });
      }
    }
  }

  void _navigateToInfo(Movie movie, String providerId) {
    // Set the global provider first
    ProviderManager().setProvider(providerId);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InfoScreen(movieUrl: movie.link),
      ),
    );
  }

  // Navigation Logic
  void _navigateHorizontal(int delta) {
    if (_searchFocusNode.hasFocus) return;

    final visibleProviders = _getVisibleProviders();
    if (visibleProviders.isEmpty) return;
    if (_selectedProviderIndex < 0 || _selectedProviderIndex >= visibleProviders.length) return;

    final providerId = visibleProviders[_selectedProviderIndex];
    final results = _results[providerId] ?? [];
    
    if (results.isEmpty) return; // Can't navigate loading shimmers

    setState(() {
      _selectedMovieIndex = (_selectedMovieIndex + delta).clamp(0, results.length - 1);
    });
    
    _scrollToSelectedHorizontal(providerId);
  }

  void _navigateVertical(int delta) {
    final visibleProviders = _getVisibleProviders();
    
    // Create ScrollController for provider if it doesn't exist
    for (var id in visibleProviders) {
      if (!_horizontalScrollControllers.containsKey(id)) {
        _horizontalScrollControllers[id] = ScrollController();
      }
    }

    // Moving down from search bar
    if (_searchFocusNode.hasFocus) {
      if (delta > 0 && visibleProviders.isNotEmpty) {
        _searchFocusNode.unfocus();
        setState(() {
          _selectedProviderIndex = 0;
          _selectedMovieIndex = 0;
        });
        _scrollToSelectedVertical();
      }
      return;
    }

    // Moving up to search bar
    if (delta < 0 && _selectedProviderIndex <= 0) {
      setState(() {
        _selectedProviderIndex = -1;
      });
      _searchFocusNode.requestFocus();
      // Scroll to top
      if (_verticalScrollController.hasClients) {
        _verticalScrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      }
      return;
    }

    if (visibleProviders.isEmpty) return;

    setState(() {
      final newIndex = _selectedProviderIndex + delta;
      if (newIndex >= 0 && newIndex < visibleProviders.length) {
        _selectedProviderIndex = newIndex;
        _selectedMovieIndex = 0; // Reset horizontal selection when changing rows
        _scrollToSelectedVertical();
      }
    });
  }
  
  void _scrollToSelectedVertical() {
    if (!_verticalScrollController.hasClients) return;
    
    // Approximate height logic: header + (card height + padding) * index
    // This is rough but works for uniform lists. 
    // Header ~ 100px. Each provider section ~ 280-300px.
    const double sectionHeight = 300.0; 
    const double headerHeight = 100.0;
    
    final targetOffset = (_selectedProviderIndex * sectionHeight) + headerHeight - 100; // -100 to center a bit
    
    _verticalScrollController.animateTo(
      targetOffset.clamp(0.0, _verticalScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _scrollToSelectedHorizontal(String providerId) {
    final controller = _horizontalScrollControllers[providerId];
    if (controller != null && controller.hasClients) {
      const double cardWidth = 140.0;
      const double gap = 16.0;
      const double itemExtent = cardWidth + gap;
      
      final targetOffset = (_selectedMovieIndex * itemExtent) - 50; // -50 to show some context
      
      controller.animateTo(
        targetOffset.clamp(0.0, controller.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _handleEnter() {
    if (_searchFocusNode.hasFocus) {
      _performGlobalSearch(_searchController.text);
      return;
    }

    final visibleProviders = _getVisibleProviders();
    if (_selectedProviderIndex >= 0 && _selectedProviderIndex < visibleProviders.length) {
      final providerId = visibleProviders[_selectedProviderIndex];
      final results = _results[providerId];
      
      if (results != null && results.isNotEmpty) {
        if (_selectedMovieIndex >= 0 && _selectedMovieIndex < results.length) {
          _navigateToInfo(results[_selectedMovieIndex], providerId);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyEventHandler(
      onLeftKey: () => _navigateHorizontal(-1),
      onRightKey: () => _navigateHorizontal(1),
      onUpKey: () => _navigateVertical(-1),
      onDownKey: () => _navigateVertical(1),
      onEnterKey: _handleEnter,
      onBackKey: () {
        if (_searchFocusNode.hasFocus) {
           Navigator.pop(context);
        } else {
          // If in results, go back to details search
          _searchFocusNode.requestFocus();
          setState(() {
            _selectedProviderIndex = -1;
          });
          if (_verticalScrollController.hasClients) {
             _verticalScrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D0D), // Deep dark background
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Global Search'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search across all providers...',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                  filled: true,
                  fillColor: _searchFocusNode.hasFocus 
                      ? Colors.white.withOpacity(0.15) 
                      : const Color(0xFF1E1E1E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: _searchFocusNode.hasFocus
                        ? const BorderSide(color: Color(0xFFFFD700), width: 1.5)
                        : BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onSubmitted: _performGlobalSearch,
                textInputAction: TextInputAction.search,
              ),
            ),
            
            if (!_hasSearched)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search, size: 64, color: Colors.grey[800]),
                      const SizedBox(height: 16),
                      Text(
                        'Search for movies & TV shows',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView(
                  controller: _verticalScrollController,
                  padding: const EdgeInsets.only(bottom: 20),
                  children: ProviderManager.availableProviders.map((provider) {
                    return _buildProviderSection(provider);
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderSection(Map<String, dynamic> provider) {
    final providerId = provider['id'] as String;
    final isLoading = _loading[providerId] == true;
    final results = _results[providerId] ?? [];
    
    // Hide section if not loading and no results
    if (!isLoading && results.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // Determine if this provider row is selected
    final visibleProviders = _getVisibleProviders();
    final isProviderSelected = _selectedProviderIndex >= 0 && 
                               _selectedProviderIndex < visibleProviders.length &&
                               visibleProviders[_selectedProviderIndex] == providerId;

    // Initialize controller for this provider if needed
    if (!_horizontalScrollControllers.containsKey(providerId)) {
      _horizontalScrollControllers[providerId] = ScrollController();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Row(
            children: [
              Icon(
                provider['icon'] as IconData, 
                size: 20, 
                color: isProviderSelected ? const Color(0xFFFFD700) : Colors.grey[400],
              ),
              const SizedBox(width: 10),
              Text(
                provider['name'] as String,
                style: TextStyle(
                  color: isProviderSelected ? Colors.white : Colors.white70,
                  fontSize: 18,
                  fontWeight: isProviderSelected ? FontWeight.bold : FontWeight.w500,
                  shadows: isProviderSelected 
                    ? [BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.5), blurRadius: 10)]
                    : null,
                ),
              ),
              if (isLoading) ...[
                const SizedBox(width: 10),
                const SizedBox(
                  width: 16, 
                  height: 16, 
                  child: CircularProgressIndicator(strokeWidth: 2)
                ),
              ] else if (results.isNotEmpty) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isProviderSelected 
                        ? const Color(0xFFFFD700).withOpacity(0.2)
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${results.length}',
                    style: TextStyle(
                      color: isProviderSelected ? const Color(0xFFFFD700) : Colors.white70,
                      fontSize: 12
                    ),
                  ),
                ),
              ]
            ],
          ),
        ),
        
        if (isLoading && results.isEmpty)
          SizedBox(
            height: 200, // Placeholder height
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) => _buildShimmerCard(),
            ),
          )
        else if (results.isNotEmpty)
          SizedBox(
            height: 240, // Height for posters
            child: ListView.separated(
              controller: _horizontalScrollControllers[providerId],
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: results.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final isSelected = isProviderSelected && _selectedMovieIndex == index;
                return _buildMovieCard(results[index], providerId, isSelected);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildShimmerCard() {
    return Container(
      width: 140,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _buildMovieCard(Movie movie, String providerId, bool isSelected) {
    return AnimatedScale(
      scale: isSelected ? 1.1 : 1.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutBack,
      child: Container(
        width: 140,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withOpacity(0.3), // Gold glow
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: const Color(0xFFFFD700).withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: -2,
                    ),
                  ]
                : null,
          ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _navigateToInfo(movie, providerId),
            borderRadius: BorderRadius.circular(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    movie.imageUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[800],
                        child: const Center(
                          child: Icon(Icons.broken_image, color: Colors.white54),
                        ),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / 
                                loadingProgress.expectedTotalBytes!
                              : null,
                          strokeWidth: 2,
                        ),
                      );
                    },
                  ),
                  
                  // Gradient Overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.2),
                          Colors.black.withOpacity(0.9),
                        ],
                        stops: const [0.6, 0.8, 1.0],
                      ),
                    ),
                  ),

                   // Selection Border
                  if (isSelected)
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFFFD700),
                          width: 2.5,
                        ),
                      ),
                    ),

                  // Title and Info
                  Positioned(
                    bottom: 12,
                    left: 10,
                    right: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          movie.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white.withOpacity(0.9),
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.8),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        if (movie.quality.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD700),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                movie.quality,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

