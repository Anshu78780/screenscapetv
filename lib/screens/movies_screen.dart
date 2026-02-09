import 'package:flutter/material.dart';
import '../models/movie.dart';
import '../provider/drive/index.dart';
import '../provider/hdhub/index.dart';
import '../provider/xdmovies/index.dart';
import '../provider/desiremovies/index.dart';
import '../provider/moviesmod/index.dart';
import '../provider/zinkmovies/index.dart';
import '../provider/provider_manager.dart';
import '../utils/key_event_handler.dart';
import '../widgets/sidebar.dart';
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
  bool _isSidebarOpen = false;
  bool _isMenuButtonFocused = false;
  bool _isSearchFocused = false;
  bool _isSearchActive = false;
  int _selectedSidebarIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  final ScrollController _scrollController = ScrollController();
  final int _crossAxisCount = 6;
  
  // Provider Manager
  final ProviderManager _providerManager = ProviderManager();
  String get _currentProvider => _providerManager.activeProvider;

  // Get categories dynamically based on active provider
  List<Map<String, String>> get _categories {
    switch (_currentProvider) {
      case 'Hdhub':
        return HdhubCatalog.categories;
      case 'Xdmovies':
        return XdmoviesCatalog.categories;
      case 'Desiremovies':
        return DesireMoviesCatalog.categories;
      case 'Moviesmod':
        return MoviesmodCatalog.categories;
      case 'Zinkmovies':
        return ZinkMoviesCatalog.categories;
      case 'Drive':
      default:
        return DriveCatalog.categories;
    }
  }

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
      List<Movie> movies;
      
      switch (_currentProvider) {
        case 'Hdhub':
          final categoryUrl = await HdhubCatalog.getCategoryUrl(category['path']!);
          movies = await HdhubGetPost.fetchMovies(categoryUrl);
          break;
        case 'Xdmovies':
          final categoryUrl = await XdmoviesCatalog.getCategoryUrl(category['path']!);
          movies = await XdmoviesGetPost.fetchMovies(categoryUrl);
          break;
        case 'Desiremovies':
          final categoryUrl = await DesireMoviesCatalog.getCategoryUrl(category['path']!);
          movies = await DesireMoviesGetPost.fetchMovies(categoryUrl);
          break;
        case 'Moviesmod':
          final categoryUrl = await MoviesmodCatalog.getCategoryUrl(category['path']!);
          movies = await MoviesmodGetPost.fetchMovies(categoryUrl);
          break;
        case 'Zinkmovies':
          movies = await zinkmoviesGetPosts(category['filter']!, 1);
          break;
        case 'Drive':
        default:
          final categoryUrl = await DriveCatalog.getCategoryUrl(category['path']!);
          movies = await GetPost.fetchMovies(categoryUrl);
          break;
      }
      
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
      List<Movie> movies;
      
      switch (_currentProvider) {
        case 'Hdhub':
          movies = await HdhubGetPost.searchMovies(query);
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
        case 'Xdmovies':
          movies = await XdmoviesGetPost.searchMovies(query);
          break;
        case 'Drive':
        default:
          movies = await GetPost.searchMovies(query);
          break;
      }
      
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
        _isMenuButtonFocused = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _searchFocusNode.requestFocus();
        });
      } else {
        _isSearchFocused = false;
        _isNavigatingCategories = true;
        _isMenuButtonFocused = false;
        // Optional: reload category movies if cancelling search?
        // _loadMovies(); 
      }
    });
  }

  void _changeCategory(int delta) {
    if (_categories.isEmpty) return;
    
    setState(() {
      if (_isMenuButtonFocused) {
        // Navigate from menu button
        if (delta > 0) {
          _isMenuButtonFocused = false;
          _selectedCategoryIndex = 0;
        }
      } else if (_isSearchFocused) {
        if (delta < 0) {
          _isSearchFocused = false;
          _selectedCategoryIndex = _categories.length - 1;
          if (!_isSearchActive) _loadMovies();
        } else if (delta > 0) {
          // Can't go further right from search
        }
      } else {
        int newIndex = _selectedCategoryIndex + delta;
        if (newIndex >= _categories.length) {
          _isSearchFocused = true;
        } else if (newIndex < 0) {
          _isMenuButtonFocused = true;
        } else {
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

  void _navigateSidebar(int delta) {
    final providerCount = ProviderManager.availableProviders.length;
    setState(() {
      _selectedSidebarIndex = (_selectedSidebarIndex + delta) % providerCount;
      if (_selectedSidebarIndex < 0) {
        _selectedSidebarIndex = providerCount - 1;
      }
    });
  }

  void _navigateUp() {
    if (_isSidebarOpen) {
      // Navigate up in sidebar
      _navigateSidebar(-1);
      return;
    }
    
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
    if (_isSidebarOpen) {
      // Navigate down in sidebar
      _navigateSidebar(1);
      return;
    }
    
    if (_isNavigatingCategories) {
      if (_isMenuButtonFocused) {
        // Open sidebar when pressing down on menu button
        setState(() {
          _isSidebarOpen = true;
          _selectedSidebarIndex = ProviderManager.availableProviders.indexWhere(
            (p) => p['id'] == _currentProvider
          );
          if (_selectedSidebarIndex < 0) _selectedSidebarIndex = 0;
        });
        return;
      }
      
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          // Prevent app from closing on back button
          // Could show an exit confirmation dialog here if needed
        }
      },
      child: KeyEventHandler(
        onLeftKey: () {
          // Don't intercept if search field is focused
          if (_searchFocusNode.hasFocus) return;
          _navigateGrid(-1);
        },
        onRightKey: () {
          // Don't intercept if search field is focused
          if (_searchFocusNode.hasFocus) return;
          _navigateGrid(1);
        },
        onUpKey: () {
          // Don't intercept if search field is focused
          if (_searchFocusNode.hasFocus) return;
          _navigateUp();
        },
        onDownKey: () {
          // Don't intercept if search field is focused
          if (_searchFocusNode.hasFocus) return;
          _navigateDown();
        },
        onBackKey: () {
          // Don't intercept if search field is focused (allow backspace)
          if (_searchFocusNode.hasFocus) return;
          
          // Close sidebar if open
          if (_isSidebarOpen) {
            setState(() {
              _isSidebarOpen = false;
              _isNavigatingCategories = true;
              _isMenuButtonFocused = true;
            });
            return;
          }
          // Close search if active
          if (_isSearchActive) {
            _toggleSearch();
            return;
          }
          // Prevent back button from closing the app on home screen
          // Do nothing or show exit confirmation
        },
        onEnterKey: () {
        // If search field is focused, perform search
        if (_searchFocusNode.hasFocus && _isSearchActive) {
            _performSearch(_searchController.text);
            return;
        }
        
        // If sidebar is open, select the provider
        if (_isSidebarOpen) {
          final selectedProvider = ProviderManager.availableProviders[_selectedSidebarIndex];
          _handleProviderChange(selectedProvider['id'] as String);
          return;
        }
        // If menu button is focused, open sidebar
        if (_isMenuButtonFocused) {
          setState(() {
            _isSidebarOpen = true;
            _selectedSidebarIndex = ProviderManager.availableProviders.indexWhere(
              (p) => p['id'] == _currentProvider
            );
            if (_selectedSidebarIndex < 0) _selectedSidebarIndex = 0;
          });
          return;
        }
        // If search icon is focused in category navigation, toggle search
        if (_isNavigatingCategories && _isSearchFocused) {
            _toggleSearch();
            return;
        }
        // Otherwise, open the selected movie
        if (_movies.isNotEmpty && !_isNavigatingCategories) {
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
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFC107)))
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

            // Sidebar Overlay
            if (_isSidebarOpen) 
              GestureDetector(
                onTap: () => setState(() {
                  _isSidebarOpen = false;
                  _isNavigatingCategories = true;
                  _isMenuButtonFocused = true;
                }),
                child: Container(color: Colors.black.withOpacity(0.5)),
              ),

              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                left: _isSidebarOpen ? 0 : -250,
                top: 0,
                bottom: 0,
                width: 250,
                child: Sidebar(
                  selectedProvider: _currentProvider,
                  focusedIndex: _selectedSidebarIndex,
                  onProviderSelected: _handleProviderChange,
                ),
              ),
          ],
        ),
        ),
      ),
    );
  }

  void _handleProviderChange(String provider) {
    setState(() {
      _isSidebarOpen = false;
      _isNavigatingCategories = true;
      _isMenuButtonFocused = true;
    });
    
    if (provider != _currentProvider) {
      _providerManager.setProvider(provider);
      // Reload data for the new provider
      _loadMovies();
    }
  }

  Widget _buildCategoryTabs() {
    if (_isSearchActive) {
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        height: 100,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(30),
                  border: _isSearchFocused 
                      ? Border.all(color: const Color(0xFFFFC107), width: 2)
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
                  onChanged: (value) {
                    // Auto-focus search field when typing
                    if (!_isSearchFocused) {
                      setState(() {
                        _isSearchFocused = true;
                        _isNavigatingCategories = true;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 15),
            // Search Submit Button
            GestureDetector(
              onTap: () => _performSearch(_searchController.text),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                ),
                child: const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 10),
            // Close Search Button
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _isSidebarOpen = !_isSidebarOpen;
                if (_isSidebarOpen) {
                  _selectedSidebarIndex = ProviderManager.availableProviders.indexWhere(
                    (p) => p['id'] == _currentProvider
                  );
                  if (_selectedSidebarIndex < 0) _selectedSidebarIndex = 0;
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _isMenuButtonFocused ? const Color(0xFFFFC107) : Colors.white.withOpacity(0.05), // Premium Yellow
                borderRadius: BorderRadius.circular(12),
                border: _isMenuButtonFocused
                    ? Border.all(color: Colors.white, width: 2)
                    : Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                boxShadow: _isMenuButtonFocused
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFFC107).withOpacity(0.5),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : [],
              ),
              child: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = index == _selectedCategoryIndex;
                  final isFocused = _isNavigatingCategories && isSelected && !_isSearchFocused && !_isSearchActive && !_isMenuButtonFocused;
                  
                  return Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: GestureDetector(
                        onTap: () {
                            setState(() {
                                _isSearchFocused = false;
                                _isSearchActive = false;
                                _isMenuButtonFocused = false;
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
                              ? (isFocused ? const Color(0xFFFFC107) : Colors.white.withOpacity(0.1)) 
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
                              color: (isSelected && !_isSearchFocused) ? (isFocused ? Colors.black : Colors.white) : Colors.grey[400],
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
                color: _isSearchFocused ? const Color(0xFFFFC107) : Colors.transparent,
                borderRadius: BorderRadius.circular(30),
                border: _isSearchFocused 
                    ? Border.all(color: Colors.white, width: 2) 
                    : Border.all(color: Colors.white.withOpacity(0.3), width: 1),
              ),
              child: Icon(
                Icons.search, 
                color: _isSearchFocused ? Colors.black : Colors.grey[400],
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
                      color: const Color(0xFFFFC107).withOpacity(0.3),
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
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: Colors.grey[850],
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              color: const Color(0xFFFFC107),
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      },
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
                           const Icon(Icons.play_circle_fill, size: 14, color: Color(0xFFFFC107)),
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
