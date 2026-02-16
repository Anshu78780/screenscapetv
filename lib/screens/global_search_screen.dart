import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/movie.dart';
import '../provider/provider_manager.dart';
import '../provider/provider_factory.dart';
import '../utils/key_event_handler.dart';
import '../utils/device_info_helper.dart';
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
  
  // Low memory device detection
  bool _isLowMemoryDevice = false;

  // Selection state
  int _selectedProviderIndex = -1; // -1 means focus is on search bar
  int _selectedMovieIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkDeviceMemory();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }
  
  Future<void> _checkDeviceMemory() async {
    _isLowMemoryDevice = await DeviceInfoHelper.isLowMemoryDevice();
    if (_isLowMemoryDevice) {
      print('GlobalSearchScreen: Low memory device detected - enabling lazy image loading');
    }
    setState(() {});
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
        })
        .toList();
  }

  void _performGlobalSearch(String query) {
    if (query.trim().isEmpty) return;

    // Keep focus on search bar until user navigates away
    // _searchFocusNode.unfocus();

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
      final movies = await ProviderFactory.searchMovies(providerId, query);

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
      MaterialPageRoute(builder: (context) => InfoScreen(movieUrl: movie.link)),
    );
  }

  void _navigateHorizontal(int delta) {
    if (_searchFocusNode.hasFocus) return;

    final visibleProviders = _getVisibleProviders();
    if (visibleProviders.isEmpty) return;
    if (_selectedProviderIndex < 0 ||
        _selectedProviderIndex >= visibleProviders.length) {
      return;
    }

    final providerId = visibleProviders[_selectedProviderIndex];
    final results = _results[providerId] ?? [];

    if (results.isEmpty) return;

    setState(() {
      _selectedMovieIndex = (_selectedMovieIndex + delta).clamp(
        0,
        results.length - 1,
      );
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
        _verticalScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
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

    // Revised dimensions based on new UI
    // Header (76px) + List (320px) = 396px height per provider section
    const double sectionHeight = 396.0;

    // Calculate target offset to align the selected provider to top
    // Adjusted by a small padding to show the section clearly
    final targetOffset = (_selectedProviderIndex * sectionHeight);

    _verticalScrollController.animateTo(
      targetOffset.clamp(
        0.0,
        _verticalScrollController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _scrollToSelectedHorizontal(String providerId) {
    final controller = _horizontalScrollControllers[providerId];
    if (controller != null && controller.hasClients) {
      // Get responsive card width
      final screenWidth = MediaQuery.of(context).size.width;
      final cardWidth = screenWidth < 600 ? (screenWidth - 90) / 3 : 160.0;
      const double gap = 25.0;
      final double itemExtent = cardWidth + gap;

      // Scroll to the selected item
      final targetOffset = (_selectedMovieIndex * itemExtent);

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
    if (_selectedProviderIndex >= 0 &&
        _selectedProviderIndex < visibleProviders.length) {
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
      treatSpaceAsEnter: false,
      treatBackspaceAsBack: false,
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
            _verticalScrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Ambient Background
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF1E1E1E),
                      Colors.black,
                      Colors.black,
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            ),

            Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(25, 50, 25, 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            color: const Color(0xFFFFD700),
                            iconSize: 28,
                            onPressed: () => Navigator.pop(context),
                            tooltip: 'Back',
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFFFD700).withOpacity(0.1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            'Global Search',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                              color: Colors.white,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      CallbackShortcuts(
                        bindings: {
                          const SingleActivator(
                            LogicalKeyboardKey.arrowDown,
                          ): () {
                            // Pass arrow down to vertical navigation
                            _navigateVertical(1);
                          },
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(16),
                            border: _searchFocusNode.hasFocus
                                ? Border.all(
                                    color: const Color(0xFFFFD700),
                                    width: 2,
                                  )
                                : Border.all(color: Colors.white12, width: 1),
                            boxShadow: _searchFocusNode.hasFocus
                                ? [
                                    BoxShadow(
                                      color: const Color(
                                        0xFFFFD700,
                                      ).withOpacity(0.2),
                                      blurRadius: 20,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : [],
                          ),
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search across all providers...',
                              hintStyle: TextStyle(color: Colors.white24),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: _searchFocusNode.hasFocus
                                    ? const Color(0xFFFFD700)
                                    : Colors.white54,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 18,
                                horizontal: 20,
                              ),
                            ),
                            onSubmitted: _performGlobalSearch,
                            textInputAction: TextInputAction.search,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (!_hasSearched)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(30),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.03),
                            ),
                            child: Icon(
                              Icons.manage_search_rounded,
                              size: 80,
                              color: Colors.white10,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Search everywhere',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView(
                      controller: _verticalScrollController,
                      padding: const EdgeInsets.only(bottom: 50, top: 10),
                      children: ProviderManager.availableProviders.map((
                        provider,
                      ) {
                        return _buildProviderSection(provider);
                      }).toList(),
                    ),
                  ),
              ],
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
    final isProviderSelected =
        _selectedProviderIndex >= 0 &&
        _selectedProviderIndex < visibleProviders.length &&
        visibleProviders[_selectedProviderIndex] == providerId;

    if (!_horizontalScrollControllers.containsKey(providerId)) {
      _horizontalScrollControllers[providerId] = ScrollController();
    }

    // Colors & Styles
    final headerColor = isProviderSelected ? Colors.white : Colors.white60;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Provider Header
        Padding(
          padding: const EdgeInsets.fromLTRB(30, 24, 30, 16),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isProviderSelected
                      ? const Color(0xFFFFD700).withOpacity(0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: isProviderSelected
                      ? Border.all(
                          color: const Color(0xFFFFD700).withOpacity(0.5),
                        )
                      : null,
                ),
                child: Icon(
                  provider['icon'] as IconData, // Ensure icons are valid
                  size: 20,
                  color: isProviderSelected
                      ? const Color(0xFFFFD700)
                      : Colors.white30,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                (provider['name'] as String).toUpperCase(),
                style: TextStyle(
                  color: headerColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
              if (results.isNotEmpty) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${results.length}',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (isLoading)
                const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    color: Color(0xFFFFD700),
                    strokeWidth: 2,
                  ),
                ),
            ],
          ),
        ),

        // Horizontal List
        SizedBox(
          height: 320,
          child: isLoading && results.isEmpty
              ? ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  itemCount: 4,
                  separatorBuilder: (_, __) => const SizedBox(width: 25),
                  itemBuilder: (context, index) => _buildShimmerCard(),
                )
              : ListView.separated(
                  controller: _horizontalScrollControllers[providerId],
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 10,
                  ),
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 25),
                  itemBuilder: (context, index) {
                    final isSelected =
                        isProviderSelected && _selectedMovieIndex == index;
                    final shouldLoadImage = _shouldLoadImageForProvider(
                      providerId,
                      index,
                      isProviderSelected,
                    );
                    return _buildMovieCard(
                      results[index],
                      providerId,
                      isSelected,
                      shouldLoadImage,
                    );
                  },
                ),
        ),
      ],
    );
  }
  
  /// Determines if an image should be loaded in a horizontal list for a specific provider
  bool _shouldLoadImageForProvider(String providerId, int index, bool isProviderSelected) {
    if (!_isLowMemoryDevice) return true;
    
    // For low memory devices, only load images within range of selected item
    if (!isProviderSelected) {
      // If provider is not selected, load first 5 items
      return index < 5;
    }
    
    // Load selected item ± 5 items
    return (index - _selectedMovieIndex).abs() <= 5;
  }

  Widget _buildShimmerCard() {
    // Responsive card width: matching info.dart mobile layout (35% of width)
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    // On mobile: Use same size as info.dart poster (screenWidth * 0.35)
    // On desktop: Keep default 160.0
    final cardWidth = isMobile ? screenWidth * 0.35 : 160.0;

    return Container(
      width: cardWidth,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget _buildMovieCard(Movie movie, String providerId, bool isSelected, bool shouldLoadImage) {
    // 0.62 Aspect Ratio matching movies_screen
    // Responsive card width: matching info.dart mobile layout (35% of width)
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    // On mobile: Use same size as info.dart poster (screenWidth * 0.35)
    // On desktop: Keep default 160.0
    final cardWidth = isMobile ? screenWidth * 0.35 : 160.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _navigateToInfo(movie, providerId),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          width: cardWidth,
          transform: Matrix4.identity()..scale(isSelected ? 1.05 : 1.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withOpacity(0.3),
                      blurRadius: 25,
                      spreadRadius: -5,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
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
                if (movie.imageUrl.isNotEmpty && shouldLoadImage)
                  Image.network(
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
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF2A2A2A),
                      child: const Icon(
                        Icons.broken_image,
                        color: Colors.white24,
                        size: 40,
                      ),
                    ),
                  )
                else
                  Container(
                    color: const Color(0xFF2A2A2A),
                    child: const Icon(
                      Icons.movie,
                      color: Colors.white24,
                      size: 40,
                    ),
                  ),

                // Gradient
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

                // Border
                if (isSelected)
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFFFD700),
                        width: 3,
                      ),
                    ),
                  ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (movie.quality.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700),
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
                      Text(
                        movie.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: isSelected ? 14 : 13,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                          shadows: [
                            Shadow(
                              blurRadius: 2,
                              color: Colors.black,
                              offset: const Offset(1, 1),
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
    );
  }
}
