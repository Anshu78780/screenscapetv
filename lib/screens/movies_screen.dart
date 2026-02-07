import 'package:flutter/material.dart';
import '../models/movie.dart';
import '../provider/drive/getpost.dart';
import '../provider/drive/catalog.dart';
import '../utils/key_event_handler.dart';
import 'info.dart';

class MoviesScreen extends StatefulWidget {
  const MoviesScreen({super.key});

  @override
  State<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends State<MoviesScreen> {
  int _selectedCategoryIndex = 0;
  int _selectedMovieIndex = 0;
  List<Movie> _movies = [];
  bool _isLoading = false;
  String _error = '';
  
  // Navigation & Search State
  bool _isNavigatingCategories = false;
  bool _isSearchFocused = false;
  bool _isSearchActive = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  final ScrollController _scrollController = ScrollController();
  final int _crossAxisCount = 6; 

  // Get categories from DriveCatalog
  List<Map<String, String>> get _categories => DriveCatalog.categories;

  @override
  void initState() {
    super.initState();
    _loadMovies();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadMovies() async {
    setState(() {
      _isLoading = true;
      _error = '';
      _isSearchActive = false; // Reset search mode when loading category
    });

    try {
      final category = _categories[_selectedCategoryIndex];
      final categoryUrl = await DriveCatalog.getCategoryUrl(category['path']!);
      final movies = await GetPost.fetchMovies(categoryUrl);
      
      setState(() {
        _movies = movies;
        _isLoading = false;
        _selectedMovieIndex = 0;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;
    
    setState(() {
      _isLoading = true;
      _error = '';
    });
    
    try {
      final movies = await GetPost.searchMovies(query);
      setState(() {
        _movies = movies;
        _isLoading = false;
        _selectedMovieIndex = 0;
        // After search completes, unfocus search and move to results
        _isNavigatingCategories = false;
        _isSearchFocused = false;
      });
      _searchFocusNode.unfocus();
    } catch (e) {
         setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _toggleSearch() {
    setState(() {
      _isSearchActive = !_isSearchActive;
      if (_isSearchActive) {
        _isNavigatingCategories = true;
        _isSearchFocused = true; // Ensure focus stays on search area
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _searchFocusNode.requestFocus();
        });
      } else {
        _isSearchFocused = false;
        // Optional: reload category movies if cancelling search?
        // _loadMovies(); 
      }
    });
  }

  void _changeCategory(int delta) {
    if (_categories.isEmpty) return;
    
    setState(() {
      if (_isSearchFocused) {
        if (delta < 0) {
           _isSearchFocused = false;
           _selectedCategoryIndex = _categories.length - 1;
           if (!_isSearchActive) _loadMovies();
        }
      } else {
        int newIndex = _selectedCategoryIndex + delta;
        if (newIndex >= _categories.length) {
          _isSearchFocused = true;
        } else if (newIndex >= 0) {
          _selectedCategoryIndex = newIndex;
          if (!_isSearchActive) _loadMovies();
        }
      }
    });
  }

  void _navigateGrid(int delta) {
    if (_isNavigatingCategories) {
      // Navigate categories when in category mode
      _changeCategory(delta);
    } else {
      // Navigate movies normally
      if (_movies.isEmpty) return;
      
      setState(() {
        _selectedMovieIndex = (_selectedMovieIndex + delta) % _movies.length;
        if (_selectedMovieIndex < 0) {
          _selectedMovieIndex = _movies.length - 1;
        }
      });
      _scrollToSelected();
    }
  }

  void _navigateUp() {
    if (_isNavigatingCategories) return; // Already in category mode
    
    if (_movies.isEmpty) return;
    
    final currentRow = _selectedMovieIndex ~/ _crossAxisCount;
    if (currentRow > 0) {
      // Move up one row
      setState(() {
        _selectedMovieIndex -= _crossAxisCount;
      });
      _scrollToSelected();
    } else {
      // On first row, switch to category navigation
      setState(() {
        _isNavigatingCategories = true;
      });
    }
  }

  void _navigateDown() {
    if (_isNavigatingCategories) {
      if (_isSearchActive) {
         if (_movies.isNotEmpty) {
             _searchFocusNode.unfocus();
             setState(() {
                _isNavigatingCategories = false;
                _selectedMovieIndex = 0;
             });
         }
         return;
      }

      // Exit category mode and go back to movies
      setState(() {
        _isNavigatingCategories = false;
      });
      return;
    }
    
    if (_movies.isEmpty) return;
    
    final totalRows = (_movies.length / _crossAxisCount).ceil();
    final currentRow = _selectedMovieIndex ~/ _crossAxisCount;
    
    if (currentRow < totalRows - 1) {
      // Move down one row
      final newIndex = _selectedMovieIndex + _crossAxisCount;
      setState(() {
        _selectedMovieIndex = newIndex < _movies.length ? newIndex : _movies.length - 1;
      });
      _scrollToSelected();
    }
  }

  void _scrollToSelected() {
    if (!_scrollController.hasClients) return;

    // Calculate approximate position of selected item
    const double itemHeight = 280.0; // Approximate card height including spacing
    final int row = _selectedMovieIndex ~/ _crossAxisCount;
    final double targetPosition = row * itemHeight;

    // Get viewport height
    final double viewportHeight = _scrollController.position.viewportDimension;
    final double currentScroll = _scrollController.offset;

    // Check if item is visible
    if (targetPosition < currentScroll || targetPosition > currentScroll + viewportHeight - itemHeight) {
      _scrollController.animateTo(
        targetPosition - 100, // Offset for header
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyEventHandler(
      onLeftKey: () => _navigateGrid(-1),
      onRightKey: () => _navigateGrid(1),
      onUpKey: () => _navigateUp(),
      onDownKey: () => _navigateDown(),
      onEnterKey: () {
        // If search is focused (user is in search input), perform search
        if (_isSearchFocused && _isSearchActive) {
            _performSearch(_searchController.text);
            return;
        }
        // If search icon is focused in category navigation, toggle search
        if (_isNavigatingCategories && _isSearchFocused) {
            _toggleSearch();
            return;
        }
        // Otherwise, open the selected movie
        if (_movies.isNotEmpty) {
          _showMovieDetails(_movies[_selectedMovieIndex]);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Background Gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.grey[900]!,
                    Colors.black,
                  ],
                ),
              ),
            ),
            
            // Content
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with categories
                _buildCategoryTabs(),
                
                // Main content
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Colors.red))
                      : _error.isNotEmpty
                          ? Center(
                              child: Text(
                                _error,
                                style: const TextStyle(color: Colors.red, fontSize: 18),
                              ),
                            )
                          : _buildMoviesGrid(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTabs() {
    if (_isSearchActive) {
      return Container(
        padding: const EdgeInsets.fromLTRB(50, 40, 50, 20),
        height: 100,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(30),
                  border: _isSearchFocused 
                      ? Border.all(color: Colors.red, width: 2)
                      : null,
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  decoration: InputDecoration(
                    hintText: 'Search movies...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    prefixIcon: const Icon(Icons.search, color: Colors.white),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: _performSearch,
                ),
              ),
            ),
            const SizedBox(width: 20),
            GestureDetector(
              onTap: _toggleSearch,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 24),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(50, 40, 50, 20),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Colors.red, Colors.orange],
            ).createShader(bounds),
            child: const Text(
              'ScreenScapeTV',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 60),
          Expanded(
            child: SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = index == _selectedCategoryIndex;
                  final isFocused = _isNavigatingCategories && isSelected && !_isSearchFocused && !_isSearchActive;
                  
                  return Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: GestureDetector(
                        onTap: () {
                            setState(() {
                                _isSearchFocused = false;
                                _isSearchActive = false;
                                _selectedCategoryIndex = index;
                                _isNavigatingCategories = false;
                            });
                            _loadMovies();
                        },
                        child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected && !_isSearchFocused
                              ? (isFocused ? Colors.red : Colors.white.withOpacity(0.1)) 
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: isFocused
                              ? Border.all(color: Colors.white, width: 2)
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            category['name']!,
                            style: TextStyle(
                              color: (isSelected && !_isSearchFocused) ? Colors.white : Colors.grey[400],
                              fontSize: 16,
                              fontWeight: (isSelected && !_isSearchFocused) ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 30),
          // Search Icon Button
          GestureDetector(
            onTap: _toggleSearch,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _isSearchFocused ? Colors.red : Colors.transparent,
                borderRadius: BorderRadius.circular(30),
                border: _isSearchFocused 
                    ? Border.all(color: Colors.white, width: 2) 
                    : Border.all(color: Colors.white.withOpacity(0.3), width: 1),
              ),
              child: Icon(
                Icons.search, 
                color: _isSearchFocused ? Colors.white : Colors.grey[400],
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoviesGrid() {
    if (_movies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.movie_filter_outlined, size: 80, color: Colors.grey[800]),
            const SizedBox(height: 20),
            Text(
              'No movies found in this category',
              style: TextStyle(color: Colors.grey[500], fontSize: 18),
            ),
          ],
        ),
      );
    }

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
      children: [
        const Text(
          'Latest Releases',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 25),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _crossAxisCount,
            childAspectRatio: 0.65,
            crossAxisSpacing: 25,
            mainAxisSpacing: 40,
          ),
          itemCount: _movies.length,
          itemBuilder: (context, index) {
            return _buildMovieCard(_movies[index], index == _selectedMovieIndex);
          },
        ),
        const SizedBox(height: 50), // Bottom padding
      ],
    );
  }

  Widget _buildMovieCard(Movie movie, bool isSelected) {
    return GestureDetector(
      onTap: () => _showMovieDetails(movie),
      child: AnimatedScale(
        scale: isSelected ? 1.1 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: Colors.red.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: -2,
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
              // Movie poster
              movie.imageUrl.isNotEmpty
                  ? Image.network(
                      movie.imageUrl,
                      headers: const {
                        'User-Agent': 'Mozilla/5.0',
                        'Referer': 'https://www.reddit.com/',
                      },
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[850],
                        child: Icon(Icons.broken_image, color: Colors.grey[700]),
                      ),
                    )
                  : Container(
                      color: Colors.grey[850],
                      child: Icon(Icons.movie, color: Colors.grey[700], size: 40),
                    ),
              
              // Gradient Overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.4),
                      Colors.black.withOpacity(0.9),
                    ],
                    stops: const [0.0, 0.6, 0.8, 1.0],
                  ),
                ),
              ),

              // Selection Border
              if (isSelected)
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 3),
                    borderRadius: BorderRadius.circular(12),
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isSelected) ...[
                      const SizedBox(height: 4),
                       Row(
                        children: [
                           const Icon(Icons.play_circle_fill, size: 14, color: Colors.red),
                           const SizedBox(width: 4),
                           Text(
                            "Watch Now",
                            style: TextStyle(
                              color: Colors.grey[300],
                              fontSize: 10,
                            ),
                          )
                        ],
                      )
                    ]
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  void _showMovieDetails(Movie movie) {
    // Navigate to info screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => InfoScreen(movieUrl: movie.link),
      ),
    );
  }
}
