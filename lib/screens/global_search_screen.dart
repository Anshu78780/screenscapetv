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
  
  // Map to store errors/empty states if needed
  final Map<String, String> _errors = {};

  bool _hasSearched = false;
  
  // Selection state
  int _selectedProviderIndex = -1; // -1 means focus is on search bar
  int _selectedMovieIndex = 0;

  @override
  void initState() {
    super.initState();
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
    
    _searchFocusNode.unfocus();

    setState(() {
      _hasSearched = true;
      _results.clear();
      _errors.clear();
      _loading.clear();
      _selectedProviderIndex = -1;
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
    ProviderManager().setProvider(providerId);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InfoScreen(movieUrl: movie.link),
      ),
    );
  }

  void _navigateHorizontal(int delta) {
    if (_searchFocusNode.hasFocus) return;

    final visibleProviders = _getVisibleProviders();
    if (visibleProviders.isEmpty) return;
    if (_selectedProviderIndex < 0 || _selectedProviderIndex >= visibleProviders.length) return;

    final providerId = visibleProviders[_selectedProviderIndex];
    final results = _results[providerId] ?? [];
    
    if (results.isEmpty) return;

    setState(() {
      _selectedMovieIndex = (_selectedMovieIndex + delta).clamp(0, results.length - 1);
    });
    
    _scrollToSelectedHorizontal(providerId);
  }

  void _navigateVertical(int delta) {
    final visibleProviders = _getVisibleProviders();
    
    for (var id in visibleProviders) {
      if (!_horizontalScrollControllers.containsKey(id)) {
        _horizontalScrollControllers[id] = ScrollController();
      }
    }

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

    if (delta < 0 && _selectedProviderIndex <= 0) {
      setState(() {
        _selectedProviderIndex = -1;
      });
      _searchFocusNode.requestFocus();
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
        _selectedMovieIndex = 0;
        _scrollToSelectedVertical();
      }
    });
  }
  
  void _scrollToSelectedVertical() {
    if (!_verticalScrollController.hasClients) return;
    
    const double sectionHeight = 400.0; 
    const double headerHeight = 120.0;
    
    final targetOffset = (_selectedProviderIndex * sectionHeight) + headerHeight - 100;
    
    _verticalScrollController.animateTo(
      targetOffset.clamp(0.0, _verticalScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _scrollToSelectedHorizontal(String providerId) {
    final controller = _horizontalScrollControllers[providerId];
    if (controller != null && controller.hasClients) {
      const double cardWidth = 150.0;
      const double gap = 24.0;
      const double itemExtent = cardWidth + gap;
      
      final targetOffset = (_selectedMovieIndex * itemExtent) - 75; 
      
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
        backgroundColor: const Color(0xFF0D0D0D),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Global Search', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          centerTitle: false,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _searchFocusNode.hasFocus 
                      ? [BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.2), blurRadius: 16, spreadRadius: 1)]
                      : [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))],
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Search movies & shows...',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    prefixIcon: Icon(
                      Icons.search, 
                      color: _searchFocusNode.hasFocus ? const Color(0xFFFFD700) : Colors.grey[500]
                    ),
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFFFD700), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                  ),
                  onSubmitted: _performGlobalSearch,
                  textInputAction: TextInputAction.search,
                ),
              ),
            ),
            
            if (!_hasSearched)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.movie_filter_outlined, size: 80, color: Colors.grey[900]),
                      const SizedBox(height: 24),
                      Text(
                        'Discover content across all providers',
                        style: TextStyle(color: Colors.grey[700], fontSize: 16),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView(
                  controller: _verticalScrollController,
                  padding: const EdgeInsets.only(bottom: 50),
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
    
    if (!isLoading && results.isEmpty) {
      return const SizedBox.shrink();
    }
    
    final visibleProviders = _getVisibleProviders();
    final isProviderSelected = _selectedProviderIndex >= 0 && 
                               _selectedProviderIndex < visibleProviders.length &&
                               visibleProviders[_selectedProviderIndex] == providerId;

    if (!_horizontalScrollControllers.containsKey(providerId)) {
      _horizontalScrollControllers[providerId] = ScrollController();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isProviderSelected ? const Color(0xFFFFD700).withOpacity(0.1) : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  provider['icon'] as IconData, 
                  size: 20, 
                  color: isProviderSelected ? const Color(0xFFFFD700) : Colors.grey[400],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                provider['name'] as String,
                style: TextStyle(
                  color: isProviderSelected ? Colors.white : Colors.white70,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              if (isLoading) ...[
                const SizedBox(width: 12),
                const SizedBox(
                  width: 16, 
                  height: 16, 
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFD700))
                ),
              ] else if (results.isNotEmpty) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isProviderSelected 
                        ? const Color(0xFFFFD700).withOpacity(0.2)
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isProviderSelected ? const Color(0xFFFFD700).withOpacity(0.3) : Colors.transparent,
                      width: 1,
                    )
                  ),
                  child: Text(
                    '${results.length}',
                    style: TextStyle(
                      color: isProviderSelected ? const Color(0xFFFFD700) : Colors.white60,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ]
            ],
          ),
        ),
        
        if (isLoading && results.isEmpty)
          SizedBox(
            height: 250,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(width: 24),
              itemBuilder: (context, index) => _buildShimmerCard(),
            ),
          )
        else if (results.isNotEmpty)
          SizedBox(
            height: 320,
            child: ListView.separated(
              controller: _horizontalScrollControllers[providerId],
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              itemCount: results.length,
              separatorBuilder: (_, __) => const SizedBox(width: 24),
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
      width: 150,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget _buildMovieCard(Movie movie, String providerId, bool isSelected) {
    return Center(
      child: AnimatedScale(
        scale: isSelected ? 1.15 : 1.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.fastOutSlowIn,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 150,
          curve: Curves.fastOutSlowIn,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withOpacity(0.4),
                      blurRadius: 24,
                      spreadRadius: 2,
                      offset: const Offset(0, 12),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ],
          ),
          child: Material(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () => _navigateToInfo(movie, providerId),
              borderRadius: BorderRadius.circular(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      movie.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: const Color(0xFF2A2A2A),
                        child: Icon(Icons.movie, color: Colors.white.withOpacity(0.1), size: 40),
                      ),
                    ),
                    
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.0),
                            Colors.black.withOpacity(0.6),
                            Colors.black.withOpacity(0.95),
                          ],
                          stops: const [0.0, 0.5, 0.8, 1.0],
                        ),
                      ),
                    ),

                    if (isSelected)
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFFFD700),
                            width: 3.0,
                          ),
                        ),
                      ),

                    Positioned(
                      bottom: 16,
                      left: 12,
                      right: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (movie.quality.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD700),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                movie.quality,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          Text(
                            movie.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white.withOpacity(0.8),
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              height: 1.2,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.8),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
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
      ),
    );
  }
}
