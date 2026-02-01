import 'package:flutter/material.dart';
import '../models/movie_info.dart';
import '../provider/drive/movie_info_parser.dart';
import '../provider/drive/hubcloud_extractor.dart';
import '../provider/drive/geteps.dart';
import '../widgets/seasonlist.dart';
import '../utils/key_event_handler.dart';
import '../widgets/streaming_links_dialog.dart';
import 'video_player_screen.dart';

class InfoScreen extends StatefulWidget {
  final String movieUrl;

  const InfoScreen({super.key, required this.movieUrl});

  @override
  State<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen> {
  MovieInfo? _movieInfo;
  bool _isLoading = true;
  String _error = '';
  String _selectedQuality = '';
  int _selectedDownloadIndex = 0;
  int _selectedQualityIndex = 0;
  bool _isQualitySelectorFocused = false;
  bool _isBackButtonFocused = false;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<SeasonListState> _seasonListKey = GlobalKey<SeasonListState>();

  @override
  void initState() {
    super.initState();
    _loadMovieInfo();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMovieInfo() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final movieInfo = await MovieInfoParser.fetchMovieInfo(widget.movieUrl);
      setState(() {
        _movieInfo = movieInfo;
        _isLoading = false;
        // Set default quality to first available quality
        if (movieInfo.downloadLinks.isNotEmpty) {
          final firstQuality = movieInfo.downloadLinks.first.quality;
          // Extract base quality (480p, 720p, etc.)
          final match = RegExp(r'(480p|720p|1080p|2160p|4k)').firstMatch(firstQuality);
          _selectedQuality = match?.group(0) ?? 'All';
        } else {
          _selectedQuality = 'All';
        }
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<DownloadLink> _getFilteredDownloads() {
    if (_movieInfo == null) return [];
    
    if (_selectedQuality.isEmpty || _selectedQuality == 'All') {
      return _movieInfo!.downloadLinks;
    }
    
    return _movieInfo!.downloadLinks.where((link) {
      return link.quality.toLowerCase().contains(_selectedQuality.toLowerCase());
    }).toList();
  }

  List<String> _getAvailableQualities() {
    if (_movieInfo == null) return ['All'];
    
    final Set<String> qualities = {'All'};
    for (var link in _movieInfo!.downloadLinks) {
      final match = RegExp(r'(480p|720p|1080p|2160p|4k)').firstMatch(link.quality);
      if (match != null) {
        qualities.add(match.group(0)!);
      }
    }
    return qualities.toList();
  }

  void _navigateDownloads(int delta) {
    if (_isQualitySelectorFocused) return; // Don't navigate downloads when in quality selector
    
    final downloads = _getFilteredDownloads();
    if (downloads.isEmpty) return;
    
    setState(() {
      _selectedDownloadIndex = (_selectedDownloadIndex + delta) % downloads.length;
      if (_selectedDownloadIndex < 0) {
        _selectedDownloadIndex = downloads.length - 1;
      }
    });
    _scrollToSelected();
  }

  void _navigateQualities(int delta) {
    if (!_isQualitySelectorFocused) return; // Only navigate qualities when focused
    
    final qualities = _getAvailableQualities();
    if (qualities.isEmpty) return;
    
    setState(() {
      _selectedQualityIndex = (_selectedQualityIndex + delta) % qualities.length;
      if (_selectedQualityIndex < 0) {
        _selectedQualityIndex = qualities.length - 1;
      }
    });
  }

  void _selectCurrentQuality() {
    if (!_isQualitySelectorFocused) return;
    
    final qualities = _getAvailableQualities();
    if (_selectedQualityIndex >= 0 && _selectedQualityIndex < qualities.length) {
      setState(() {
        _selectedQuality = qualities[_selectedQualityIndex];
        _selectedDownloadIndex = 0;
      });
    }
  }

  void _navigateVertical(int delta) {
    setState(() {
      if (delta < 0) {
        // Up arrow
        if (!_isBackButtonFocused && !_isQualitySelectorFocused && _selectedDownloadIndex == 0) {
          // From first download to quality selector
          _isQualitySelectorFocused = true;
        } else if (_isQualitySelectorFocused) {
          // From quality selector to back button
          _isQualitySelectorFocused = false;
          _isBackButtonFocused = true;
          _scrollToTop();
        } else if (!_isBackButtonFocused && !_isQualitySelectorFocused) {
          // Navigate up in downloads
          _navigateDownloads(delta);
        }
      } else {
        // Down arrow
        if (_isBackButtonFocused) {
          // From back button to quality selector
          _isBackButtonFocused = false;
          _isQualitySelectorFocused = true;
        } else if (_isQualitySelectorFocused) {
          // From quality selector to downloads
          _isQualitySelectorFocused = false;
        } else {
          // Navigate down in downloads
          _navigateDownloads(delta);
        }
      }
    });
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _scrollToSelected() {
    if (!_scrollController.hasClients || _isQualitySelectorFocused) return;

    // Simple scroll to bring selected item into view
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final double itemHeight = 100.0;
        final double targetPosition = 400 + (_selectedDownloadIndex * itemHeight);
        
        _scrollController.animateTo(
          targetPosition,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final qualities = _getAvailableQualities();
    
    return KeyEventHandler(
      onLeftKey: () {
        if (_isQualitySelectorFocused) {
          _navigateQualities(-1);
        } else {
          _navigateDownloads(-1);
        }
      },
      onRightKey: () {
        if (_isQualitySelectorFocused) {
          _navigateQualities(1);
        } else {
          _navigateDownloads(1);
        }
      },
      onUpKey: () => _navigateVertical(-1),
      onDownKey: () => _navigateVertical(1),
      onEnterKey: () {
        if (_isBackButtonFocused) {
          Navigator.of(context).pop();
        } else if (_isQualitySelectorFocused) {
          _seasonListKey.currentState?.openDropdown();
        } else {
          final downloads = _getFilteredDownloads();
          if (downloads.isNotEmpty) {
            _openDownloadLink(downloads[_selectedDownloadIndex]);
          }
        }
      },
      onBackKey: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error.isNotEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _error,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Go Back'),
                        ),
                      ],
                    ),
                  )
                : _buildContent(qualities),
      ),
    );
  }

  Widget _buildContent(List<String> qualities) {
    if (_movieInfo == null) {
      return const Center(
        child: Text(
          'No movie info available',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isBackButtonFocused 
                    ? [Colors.red, Colors.red.shade700]
                    : [Colors.red.withOpacity(0.8), Colors.red],
              ),
              borderRadius: BorderRadius.circular(8),
              border: _isBackButtonFocused
                  ? Border.all(color: Colors.white, width: 3)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: _isBackButtonFocused ? Colors.red.withOpacity(0.6) : Colors.red.withOpacity(0.3),
                  blurRadius: _isBackButtonFocused ? 12 : 8,
                  spreadRadius: _isBackButtonFocused ? 2 : 0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  label: const Text(
                    'Back to Movies',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_isBackButtonFocused) ...[
                  const SizedBox(width: 8),
                  Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white.withOpacity(0.5)),
                    ),
                    child: const Text(
                      'Press Enter ⏎',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 30),
          
          // Movie header with poster and details
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poster
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.red.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _movieInfo!.imageUrl.isNotEmpty
                    ? Image.network(
                        _movieInfo!.imageUrl,
                        width: 300,
                        height: 450,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 300,
                            height: 450,
                            color: Colors.grey[800],
                            child: const Icon(
                              Icons.movie,
                              color: Colors.white,
                              size: 80,
                            ),
                          );
                        },
                      )
                    : Container(
                        width: 300,
                        height: 450,
                        color: Colors.grey[800],
                        child: const Icon(
                          Icons.movie,
                          color: Colors.white,
                          size: 80,
                        ),
                      ),
                ),
              ),
              const SizedBox(width: 40),
              
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [Colors.white, Colors.red.shade200],
                      ).createShader(bounds),
                      child: Text(
                        _movieInfo!.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                    Container(
                      height: 3,
                      width: 100,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.red, Colors.transparent],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    _buildDetailRow('⭐ IMDb Rating', _movieInfo!.imdbRating),
                    _buildDetailRow('🎬 Genre', _movieInfo!.genre),
                    _buildDetailRow('👮 Director', _movieInfo!.director),
                    _buildDetailRow('✍ Writer', _movieInfo!.writer),
                    _buildDetailRow('⭐ Stars', _movieInfo!.stars),
                    _buildDetailRow('🗣 Language', _movieInfo!.language),
                    _buildDetailRow('🎵 Quality', _movieInfo!.quality),
                    _buildDetailRow('🎙 Format', _movieInfo!.format),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 40),
          
          // Storyline
          if (_movieInfo!.storyline.isNotEmpty) ...[
            const Text(
              'Storyline',
              style: TextStyle(
                color: Colors.red,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _movieInfo!.storyline,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
          ],
          
          // Quality selector
          SeasonList(
            key: _seasonListKey,
            qualities: qualities,
            selectedQuality: _selectedQuality,
            isFocused: _isQualitySelectorFocused,
            onQualityChanged: (quality) {
              setState(() {
                _selectedQuality = quality;
                _selectedDownloadIndex = 0;
                _selectedQualityIndex = qualities.indexOf(quality);
              });
            },
          ),
          
          const SizedBox(height: 30),
          
          // Download links
          const Text(
            'Download Links',
            style: TextStyle(
              color: Colors.red,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          
          _buildDownloadLinks(),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[900]?.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: Colors.red.withOpacity(0.5),
            width: 3,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadLinks() {
    final downloads = _getFilteredDownloads();
    
    if (downloads.isEmpty) {
      return const Text(
        'No download links available',
        style: TextStyle(color: Colors.grey),
      );
    }

    return Column(
      children: downloads.asMap().entries.map((entry) {
        final index = entry.key;
        final download = entry.value;
        final isSelected = index == _selectedDownloadIndex;
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: GestureDetector(
            onTap: () => _openDownloadLink(download),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              transform: Matrix4.identity()..scale(isSelected ? 1.02 : 1.0),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isSelected 
                      ? [Colors.red.withOpacity(0.9), Colors.red.shade700]
                      : [Colors.grey[850]!, Colors.grey[900]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.red.withOpacity(0.3),
                  width: isSelected ? 3 : 1,
                ),
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ] : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                download.quality,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.storage,
                              color: Colors.grey[400],
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              download.size,
                              style: TextStyle(
                                color: Colors.grey[300],
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.download_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _openDownloadLink(DownloadLink downloadLink) async {
    print('=== DOWNLOAD LINK DEBUG ===');
    print('Quality: ${downloadLink.quality}');
    print('Size: ${downloadLink.size}');
    print('URL: ${downloadLink.url}');
    print('========================');
    
    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fetching download page...'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 30),
      ),
    );
    
    try {
      // Step 1: Fetch HubCloud links from the download URL page
      print('Step 1: Fetching HubCloud links from: ${downloadLink.url}');
      final hubCloudLinks = await EpisodeParser.fetchHubCloudLinks(downloadLink.url);
      print('Found ${hubCloudLinks.length} HubCloud links');
      
      if (hubCloudLinks.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No HubCloud links found on download page'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Update loading message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Extracting streaming links...'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 30),
        ),
      );
      
      // Step 2: Extract streaming links from HubCloud
      final hubCloudUrl = hubCloudLinks.first;
      print('Step 2: Extracting streams from HubCloud: $hubCloudUrl');
      final result = await HubCloudExtractor.extractLinks(hubCloudUrl);
      print('Extractor result - Success: ${result.success}, Streams count: ${result.streams.length}');
      
      // Hide loading indicator
      ScaffoldMessenger.of(context).clearSnackBars();
      
      if (result.success && result.streams.isNotEmpty) {
        // Show dialog with streaming links
        _showStreamingLinksDialog(result.streams, downloadLink.quality);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No streaming links found'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error in download link processing: $e');
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
  
  void _showStreamingLinksDialog(List<Stream> streams, String quality) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StreamingLinksDialog(
          streams: streams,
          quality: quality,
          movieTitle: _movieInfo?.title ?? 'Movie',
        ),
      ),
    );
  }
}
