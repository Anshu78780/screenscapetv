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
  bool _isNavigatingCategories = false; // Track if navigating categories
  final ScrollController _scrollController = ScrollController();
  final int _crossAxisCount = 6; // Number of columns in grid

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
    super.dispose();
  }

  Future<void> _loadMovies() async {
    setState(() {
      _isLoading = true;
      _error = '';
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

  void _changeCategory(int delta) {
    if (_categories.isEmpty) return;
    
    setState(() {
      _selectedCategoryIndex = (_selectedCategoryIndex + delta) % _categories.length;
      if (_selectedCategoryIndex < 0) {
        _selectedCategoryIndex = _categories.length - 1;
      }
    });
    _loadMovies();
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
        if (_movies.isNotEmpty) {
          _showMovieDetails(_movies[_selectedMovieIndex]);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with categories
            _buildCategoryTabs(),
            
            // Main content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error.isNotEmpty
                      ? Center(
                          child: Text(
                            _error,
                            style: const TextStyle(color: Colors.red),
                          ),
                        )
                      : _buildMoviesGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
      decoration: _isNavigatingCategories 
          ? BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.red.withOpacity(0.5), width: 2),
              ),
            )
          : null,
      child: Row(
        children: [
          const Text(
            'ScreenScapeTV',
            style: TextStyle(
              color: Colors.red,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 60),
          ..._categories.asMap().entries.map((entry) {
            final index = entry.key;
            final category = entry.value;
            final isSelected = index == _selectedCategoryIndex;
            
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategoryIndex = index;
                    _isNavigatingCategories = false;
                  });
                  _loadMovies();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    border: (_isNavigatingCategories && isSelected)
                        ? Border.all(color: Colors.red, width: 2)
                        : null,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    category['name']!,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey,
                      fontSize: 18,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMoviesGrid() {
    if (_movies.isEmpty) {
      return const Center(
        child: Text(
          'No movies found',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(40),
      children: [
        const Text(
          'Latest Releases',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 30),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _crossAxisCount,
            childAspectRatio: 0.6,
            crossAxisSpacing: 20,
            mainAxisSpacing: 50,
          ),
          itemCount: _movies.length,
          itemBuilder: (context, index) {
            return _buildMovieCard(_movies[index], index == _selectedMovieIndex);
          },
        ),
      ],
    );
  }

  Widget _buildMovieCard(Movie movie, bool isSelected) {
    return Padding(
      padding: EdgeInsets.all(isSelected ? 8.0 : 0.0),
      child: GestureDetector(
        onTap: () => _showMovieDetails(movie),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.identity()..scale(isSelected ? 1.1 : 1.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(color: Colors.white, width: 3)
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Movie poster
                movie.imageUrl.isNotEmpty
                    ? Image.network(
                        movie.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[800],
                            child: const Icon(
                              Icons.movie,
                              color: Colors.white,
                              size: 50,
                            ),
                          );
                        },
                      )
                    : Container(
                        color: Colors.grey[800],
                        child: const Icon(
                          Icons.movie,
                          color: Colors.white,
                          size: 50,
                        ),
                      ),
                
                // Title overlay
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.8),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Text(
                      movie.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getQualityColor(String quality) {
    if (quality.contains('4K') || quality.contains('2160p')) {
      return Colors.purple;
    } else if (quality.contains('FHD') || quality.contains('1080p')) {
      return Colors.blue;
    } else if (quality.contains('BluRay')) {
      return Colors.green;
    } else if (quality.contains('CAM') || quality.contains('HDTC')) {
      return Colors.orange;
    }
    return Colors.grey;
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
