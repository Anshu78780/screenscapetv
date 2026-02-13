import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/movie.dart';
import '../provider/provider_factory.dart';
import '../provider/provider_manager.dart';
import '../utils/key_event_handler.dart';
import '../widgets/sidebar.dart';
import 'info.dart';
import 'global_search_screen.dart';
import 'user_guide_screen.dart';

class MoviesScreen extends StatefulWidget {
  const MoviesScreen({super.key});

  @override
  State<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends State<MoviesScreen> {
  int _selectedCategoryIndex = 0;
  int _selectedMovieIndex = -1; // No selection by default
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

  // Provider Manager
  final ProviderManager _providerManager = ProviderManager();
  String get _currentProvider => _providerManager.activeProvider;

  // Get categories dynamically based on active provider
  List<Map<String, String>> get _categories {
    return ProviderFactory.getCategories(_currentProvider);
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
      final movies = await ProviderFactory.loadMovies(
        _currentProvider,
        category,
      );

      setState(() {
        _movies = movies;
        _isLoading = false;
        _selectedMovieIndex = -1; // No default selection
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

    // Keep focus on search bar until navigation
    // _searchFocusNode.unfocus();

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final movies = await ProviderFactory.searchMovies(
        _currentProvider,
        query,
      );

      setState(() {
        _movies = movies;
        _isLoading = false;
        _selectedMovieIndex =
            -1; // No selection after search, user navigates first
        // Automatically focus the grid results when search completes
        _isNavigatingCategories = false;
        _isSearchFocused = false;
      });
      _searchFocusNode.unfocus();
      FocusScope.of(context).unfocus();
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
      int newIndex = _selectedCategoryIndex + delta;
      if (newIndex >= 0 && newIndex < _categories.length) {
        _selectedCategoryIndex = newIndex;
        if (!_isSearchActive) _loadMovies();
      }
    });
  }

  void _navigateHorizontal(int delta) {
    // 1. Top Bar Navigation (Menu <-> Search)
    if (_isMenuButtonFocused || (_isSearchFocused && !_isSearchActive)) {
      if (delta > 0) {
        // Right
        if (_isMenuButtonFocused) {
          setState(() {
            _isMenuButtonFocused = false;
            _isSearchFocused = true;
          });
        }
      } else {
        // Left
        if (_isSearchFocused) {
          setState(() {
            _isSearchFocused = false;
            _isMenuButtonFocused = true;
          });
        }
      }
      return;
    }

    // 2. Category Navigation
    if (_isNavigatingCategories) {
      // Allow navigation to Search button from the last category
      if (delta > 0 &&
          _selectedCategoryIndex >= _categories.length - 1 &&
          !_isSearchActive) {
        setState(() {
          _isNavigatingCategories = false;
          _isSearchFocused = true;
        });
        return;
      }

      _changeCategory(delta);
      return;
    }

    // 3. Movie Grid Navigation
    if (_movies.isEmpty) return;

    // Get responsive cross axis count
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth < 600 ? 3 : 7;

    setState(() {
      // If nothing selected, start from first item on right, last item on left
      if (_selectedMovieIndex < 0) {
        _selectedMovieIndex = delta > 0 ? 0 : _movies.length - 1;
      } else {
        final currentRow = _selectedMovieIndex ~/ crossAxisCount;
        final currentCol = _selectedMovieIndex % crossAxisCount;
        final newCol = currentCol + delta;

        if (newCol >= 0 && newCol < crossAxisCount) {
          // Move within the same row
          final newIndex = currentRow * crossAxisCount + newCol;
          if (newIndex < _movies.length) {
            _selectedMovieIndex = newIndex;
          }
        } else if (newCol < 0) {
          // Move to previous row, last column
          if (currentRow > 0) {
            final newIndex =
                (currentRow - 1) * crossAxisCount + (crossAxisCount - 1);
            _selectedMovieIndex = newIndex < _movies.length
                ? newIndex
                : _movies.length - 1;
          }
        } else {
          // Move to next row, first column
          final newIndex = (currentRow + 1) * crossAxisCount;
          if (newIndex < _movies.length) {
            _selectedMovieIndex = newIndex;
          }
        }
      }
    });
    _scrollToSelected();
  }

  void _navigateSidebar(int delta) {
    final providerCount = ProviderManager.availableProviders.length;
    // Indices:
    // -1: Global Search
    // 0 to providerCount-1: Providers
    // providerCount: User Guide/Disclaimer

    setState(() {
      _selectedSidebarIndex = (_selectedSidebarIndex + delta);

      // Wrap around logic
      final maxIndex = providerCount; // This is the user guide index

      if (_selectedSidebarIndex < -1) {
        _selectedSidebarIndex = maxIndex;
      } else if (_selectedSidebarIndex > maxIndex) {
        _selectedSidebarIndex = -1;
      }
    });
  }

  void _navigateUp() {
    if (_isSidebarOpen) {
      // Navigate up in sidebar
      _navigateSidebar(-1);
      return;
    }

    // 1. In Categories -> Go to Header (Menu or Search)
    if (_isNavigatingCategories) {
      if (_isSearchActive) {
        _searchFocusNode.requestFocus();
        setState(() {
          _isNavigatingCategories = false;
          _isSearchFocused = true;
        });
      } else {
        setState(() {
          _isNavigatingCategories = false;
          _isMenuButtonFocused = true;
          _isSearchFocused = false;
        });
      }
      return;
    }

    // 2. In Header -> Cannot go up
    if (_isMenuButtonFocused || (_isSearchFocused && !_isSearchActive)) return;

    // 3. In Grid -> Go up or to Categories
    if (_movies.isEmpty) return;

    // If nothing selected, go to categories
    if (_selectedMovieIndex < 0) {
      setState(() {
        _isNavigatingCategories = true;
      });
      return;
    }

    // Get responsive cross axis count
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth < 600 ? 3 : 7;

    final currentRow = _selectedMovieIndex ~/ crossAxisCount;
    if (currentRow > 0) {
      // Move up one row
      setState(() {
        final newIndex = _selectedMovieIndex - crossAxisCount;
        _selectedMovieIndex = newIndex >= 0 ? newIndex : 0;
      });
      _scrollToSelected();
    } else {
      // On first row
      if (_isSearchActive) {
        // If search is active, skip categories and go straight to search bar
        _searchFocusNode.requestFocus();
        setState(() {
          _isNavigatingCategories = false;
          _isSearchFocused = true;
        });
      } else {
        // Switch to category navigation
        setState(() {
          _isNavigatingCategories = true;
        });
      }
    }
  }

  void _navigateDown() {
    if (_isSidebarOpen) {
      // Navigate down in sidebar
      _navigateSidebar(1);
      return;
    }

    if (_searchFocusNode.hasFocus) {
      if (_movies.isNotEmpty) {
        _searchFocusNode.unfocus();
        setState(() {
          _isNavigatingCategories = false;
          _isSearchFocused = false;
          _selectedMovieIndex = 0;
        });
        _scrollToSelected();
      }
      return;
    }

    // 1. In Header -> Go to Categories
    if (_isMenuButtonFocused || (_isSearchFocused && !_isSearchActive)) {
      setState(() {
        _isMenuButtonFocused = false;
        _isSearchFocused = false;
        _isNavigatingCategories = true;
      });
      return;
    }

    // 2. In Categories -> Go to Grid
    if (_isNavigatingCategories) {
      if (_isMenuButtonFocused) {
        // Open sidebar when pressing down on menu button
        // Logic moved: pressing down on menu button goes to categories now
        // If sidebar opening logic on down was desired, it conflicts with layout
        // Let's assume standard behavior: Down from Menu = Category List
        // Sidebar trigger is 'Enter' on Menu button usually.
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

    // Get responsive cross axis count
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth < 600 ? 3 : 7;

    // If nothing selected, select first item
    if (_selectedMovieIndex < 0) {
      setState(() {
        _selectedMovieIndex = 0;
      });
      _scrollToSelected();
      return;
    }

    final totalRows = (_movies.length / crossAxisCount).ceil();
    final currentRow = _selectedMovieIndex ~/ crossAxisCount;

    if (currentRow < totalRows - 1) {
      // Move down one row
      final newIndex = _selectedMovieIndex + crossAxisCount;
      setState(() {
        _selectedMovieIndex = newIndex < _movies.length
            ? newIndex
            : _movies.length - 1;
      });
      _scrollToSelected();
    }
  }

  void _scrollToSelected() {
    if (!_scrollController.hasClients) return;

    // Get responsive cross axis count
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth < 600 ? 3 : 7;

    // Calculate approximate position of selected item
    const double itemHeight =
        360.0; // Approximate card height including spacing (adjusted for new UI)
    final int row = _selectedMovieIndex ~/ crossAxisCount;
    final double targetPosition = row * itemHeight;

    // Get viewport height
    final double viewportHeight = _scrollController.position.viewportDimension;
    final double currentScroll = _scrollController.offset;

    // Center the selected item comfortably in the viewport
    // If wrapping or huge list, basic scroll into view logic:
    if (targetPosition < currentScroll ||
        targetPosition > currentScroll + viewportHeight - itemHeight) {
      _scrollController.animateTo(
        targetPosition - (viewportHeight / 3), // Center it a bit better
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _handleProviderChange(String provider) {
    if (provider == 'user_guide_action') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const UserGuideScreen()),
      );
      return;
    }

    setState(() {
      _isSidebarOpen = false;
      _isNavigatingCategories = true;
      _isMenuButtonFocused = true;
      // Reset to first category when switching providers
      _selectedCategoryIndex = 0;
      _selectedMovieIndex = 0;
    });

    if (provider != _currentProvider) {
      _providerManager.setProvider(provider);
      // Reload data for the new provider
      _loadMovies();
    }
  }

  void _showMovieDetails(Movie movie) {
    // Navigate to info screen
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => InfoScreen(movieUrl: movie.link)),
    );
  }

  // --- UI BUILDERS ---

  @override
  Widget build(BuildContext context) {
    // Determine background image from selected movie
    String? backgroundImg;
    if (_movies.isNotEmpty &&
        _selectedMovieIndex >= 0 &&
        _movies.length > _selectedMovieIndex) {
      backgroundImg = _movies[_selectedMovieIndex].imageUrl;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          // Prevent closing logic here
        }
      },
      child: KeyEventHandler(
        treatSpaceAsEnter: !_isSearchActive,
        treatBackspaceAsBack: !_isSearchActive,
        onLeftKey: () {
          if (_searchFocusNode.hasFocus) return;
          _navigateHorizontal(-1);
        },
        onRightKey: () {
          if (_searchFocusNode.hasFocus) return;
          _navigateHorizontal(1);
        },
        onUpKey: () {
          if (_searchFocusNode.hasFocus) return;
          _navigateUp();
        },
        onDownKey: () {
          _navigateDown();
        },
        onBackKey: () {
          if (_searchFocusNode.hasFocus) return;
          if (_isSidebarOpen) {
            setState(() {
              _isSidebarOpen = false;
              _isNavigatingCategories = true;
              _isMenuButtonFocused = true;
            });
            return;
          }
          if (_isSearchActive) {
            _toggleSearch();
            return;
          }
          if (_isMenuButtonFocused || _isSearchFocused) {
            // Already at top level/header, maybe show exit dialog or nothing
            setState(() {
              _isMenuButtonFocused = false;
              _isSearchFocused = false;
              _isNavigatingCategories = true;
            });
            return;
          }
        },
        onEnterKey: () {
          if (_searchFocusNode.hasFocus && _isSearchActive) {
            _performSearch(_searchController.text);
            return;
          }

          if (_isSidebarOpen) {
            final providerCount = ProviderManager.availableProviders.length;

            if (_selectedSidebarIndex == -1) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GlobalSearchScreen(),
                ),
              );
              setState(() {
                _isSidebarOpen = false;
              });
            } else if (_selectedSidebarIndex == providerCount) {
              // User Guide / Disclaimer
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UserGuideScreen(),
                ),
              );
              // Do not close sidebar or do, user pref. Let's keep sidebar logic simple.
              setState(() {
                _isSidebarOpen = false;
              });
            } else {
              final selectedProvider =
                  ProviderManager.availableProviders[_selectedSidebarIndex];
              _handleProviderChange(selectedProvider['id'] as String);
            }
            return;
          }

          if (_isMenuButtonFocused) {
            setState(() {
              _isSidebarOpen = true;
              _selectedSidebarIndex = ProviderManager.availableProviders
                  .indexWhere((p) => p['id'] == _currentProvider);
              if (_selectedSidebarIndex < 0) _selectedSidebarIndex = 0;
            });
            return;
          }

          if (_isSearchFocused) {
            _toggleSearch();
            return;
          }

          if (_movies.isNotEmpty &&
              !_isNavigatingCategories &&
              !_isMenuButtonFocused &&
              !_isSearchFocused &&
              _selectedMovieIndex >= 0) {
            _showMovieDetails(_movies[_selectedMovieIndex]);
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Dynamic Background with Blur
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 700),
                  child: Container(
                    key: ValueKey<String>(backgroundImg ?? 'default_bg'),
                    decoration: BoxDecoration(
                      image: backgroundImg != null && backgroundImg.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(
                                backgroundImg,
                                headers: {
                                  'User-Agent': 'Mozilla/5.0',
                                  if (backgroundImg.contains('yomovies'))
                                    'Cookie':
                                        '__ddgid_=88FVtslcjtsA0CNp; __ddg2_=p1eTrO8cHLFLo48r; __ddg1_=13P5sx17aDtqButGko8N',
                                  'Referer': backgroundImg.contains('animepahe')
                                      ? 'https://animepahe.si/'
                                      : backgroundImg.contains('yomovies')
                                      ? 'https://yomovies.beer/'
                                      : 'https://www.reddit.com/',
                                },
                              ),
                              fit: BoxFit.cover,
                            )
                          : null,
                      color: Colors.black,
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(color: Colors.black.withOpacity(0.7)),
                    ),
                  ),
                ),

                // 2. Ambient Gradient Overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.6),
                        Colors.transparent,
                        Colors.black.withOpacity(0.8),
                        Colors.black,
                      ],
                      stops: const [0.0, 0.3, 0.8, 1.0],
                    ),
                  ),
                ),

                // 3. Main Content Area
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFFFFC107),
                              ),
                            )
                          : _error.isNotEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: Colors.amber,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _error,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 16,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : _buildMoviesGrid(),
                    ),
                  ],
                ),

                // 4. Sidebar Overlay
                if (_isSidebarOpen)
                  GestureDetector(
                    onTap: () => setState(() {
                      _isSidebarOpen = false;
                      _isNavigatingCategories = true;
                      _isMenuButtonFocused = true;
                    }),
                    child: Container(color: Colors.black.withOpacity(0.7)),
                  ),

                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  left: _isSidebarOpen ? 0 : -300,
                  top: 0,
                  bottom: 0,
                  width: 280,
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
      ),
    );
  }

  Widget _buildHeader() {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(25, topPadding, 25,2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Bar with Menu & Title/Logo placeholder
          Row(
            children: [
              // Sidebar / Provider Menu Button
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isSidebarOpen = !_isSidebarOpen;
                    if (_isSidebarOpen) {
                      _selectedSidebarIndex = ProviderManager.availableProviders
                          .indexWhere((p) => p['id'] == _currentProvider);
                      if (_selectedSidebarIndex < 0) _selectedSidebarIndex = 0;
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _isMenuButtonFocused
                        ? const Color(0xFFFFC107)
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: _isMenuButtonFocused
                        ? [
                            BoxShadow(
                              color: const Color(0xFFFFC107).withOpacity(0.4),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ]
                        : [],
                    border: Border.all(
                      color: _isMenuButtonFocused
                          ? Colors.white
                          : Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.menu,
                        color: _isMenuButtonFocused
                            ? Colors.black
                            : Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _currentProvider,
                        style: TextStyle(
                          color: _isMenuButtonFocused
                              ? Colors.black
                              : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              // Only show Search button if search is not active to avoid clutter
              if (!_isSearchActive)
                GestureDetector(
                  onTap: _toggleSearch,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isSearchFocused
                          ? const Color(0xFFFFC107)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: _isSearchFocused
                          ? Border.all(color: Colors.white, width: 2)
                          : Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Icon(
                      Icons.search,
                      color: _isSearchFocused ? Colors.black : Colors.white,
                      size: 24,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 15),

          // Search Bar Expanded
          if (_isSearchActive)
            Container(
              height: 60,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(16),
                border: _isSearchFocused
                    ? Border.all(color: const Color(0xFFFFC107), width: 2)
                    : Border.all(color: Colors.white24),
                boxShadow: _isSearchFocused
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFFC107).withOpacity(0.2),
                          blurRadius: 12,
                        ),
                      ]
                    : [],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  const Icon(Icons.search, color: Colors.white54),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CallbackShortcuts(
                      bindings: {
                        const SingleActivator(
                          LogicalKeyboardKey.arrowDown,
                        ): () {
                          _navigateDown();
                        },
                      },
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Search for movies, TV shows...',
                          hintStyle: TextStyle(color: Colors.white30),
                          border: InputBorder.none,
                        ),
                        textInputAction: TextInputAction.search,
                        onSubmitted: _performSearch,
                        onChanged: (val) {
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
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: _toggleSearch,
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),

          // Categories Tabs
          if (_categories.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (ctx, i) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final isSelected = index == _selectedCategoryIndex;
                    final isFocused =
                        _isNavigatingCategories &&
                        isSelected &&
                        !_isSearchFocused &&
                        !_isSearchActive &&
                        !_isMenuButtonFocused;

                    return GestureDetector(
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected && !_isSearchFocused
                              ? (isFocused
                                    ? const Color(0xFFFFC107)
                                    : Colors.white.withOpacity(0.15))
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: isFocused
                              ? Border.all(color: Colors.white, width: 2)
                              : Border.all(
                                  color: isSelected && !_isSearchFocused
                                      ? Colors.transparent
                                      : Colors.white.withOpacity(0.1),
                                ),
                        ),
                        child: Center(
                          child: Text(
                            category['name']!.toUpperCase(),
                            style: TextStyle(
                              color: (isSelected && !_isSearchFocused)
                                  ? (isFocused ? Colors.black : Colors.white)
                                  : Colors.grey[400],
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
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
            Icon(Icons.movie_filter_rounded, size: 80, color: Colors.white10),
            const SizedBox(height: 20),
            Text(
              'No content available',
              style: TextStyle(color: Colors.grey[500], fontSize: 18),
            ),
          ],
        ),
      );
    }

    // Responsive grid: 3 columns on mobile, 7 on larger screens
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth < 600 ? 3 : 7;
    final cardSpacing = screenWidth < 600 ? 16.0 : 35.0;
    final mainSpacing = screenWidth < 600 ? 20.0 : 42.0;

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(30, 50, 30, 50),
      clipBehavior: Clip.hardEdge, // Prevent cards from overlapping header
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.62, // Taller cards
        crossAxisSpacing: cardSpacing,
        mainAxisSpacing: mainSpacing,
      ),
      itemCount: _movies.length,
      itemBuilder: (context, index) {
        return _buildMovieCard(_movies[index], index == _selectedMovieIndex);
      },
    );
  }

  Widget _buildMovieCard(Movie movie, bool isSelected) {
    return Material(
      color: Colors.transparent,
      elevation: isSelected ? 20 : 0, // Higher elevation for better z-index
      borderRadius: BorderRadius.circular(16),
      child: GestureDetector(
        onTap: () => _showMovieDetails(movie),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          transformAlignment: Alignment.center, // Scale from center
          transform: Matrix4.identity()
            ..scale(isSelected ? 1.08 : 1.0), // Reduced scale to fit spacing
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFFFC107).withOpacity(0.3),
                      blurRadius: 25,
                      spreadRadius: -5,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Image
                movie.imageUrl.isNotEmpty
                    ? Image.network(
                        movie.imageUrl,
                        headers: {
                          'User-Agent': 'Mozilla/5.0',
                          if (movie.imageUrl.contains('yomovies'))
                            'Cookie':
                                '__ddgid_=88FVtslcjtsA0CNp; __ddg2_=p1eTrO8cHLFLo48r; __ddg1_=13P5sx17aDtqButGko8N',
                          'Referer': movie.imageUrl.contains('animepahe')
                              ? 'https://animepahe.si/'
                              : movie.imageUrl.contains('yomovies')
                              ? 'https://yomovies.beer/'
                              : 'https://www.reddit.com/',
                        },
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[900],
                          child: const Icon(
                            Icons.broken_image,
                            color: Colors.white24,
                            size: 40,
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.grey[900],
                        child: const Icon(
                          Icons.movie,
                          color: Colors.white24,
                          size: 40,
                        ),
                      ),

                // Gradient Overlay
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
                      stops: const [0.0, 0.5, 0.75, 1.0],
                    ),
                  ),
                ),

                // Selection Border
                if (isSelected)
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFFFC107),
                        width: 3,
                      ),
                    ),
                  ),

                // Content Layout
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quality Badge
                      if (movie.quality.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFC107),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            movie.quality,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        movie.title,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: isSelected ? 14 : 13,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                          shadows: [
                            Shadow(
                              blurRadius: 2,
                              color: Colors.black.withOpacity(0.8),
                              offset: const Offset(1, 1),
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
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
}
