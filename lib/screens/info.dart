import 'package:flutter/material.dart';
import '../models/movie_info.dart';
import '../provider/drive/info.dart';
import '../provider/drive/hubcloud_extractor.dart';
import '../provider/drive/geteps.dart';
import '../widgets/seasonlist.dart';
import '../utils/key_event_handler.dart';
import '../widgets/streaming_links_dialog.dart';
import '../widgets/episode_selection_dialog.dart';

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
  String _selectedSeason = 'All';
  int _selectedDownloadIndex = 0;
  int _selectedQualityIndex = 0;
  int _selectedSeasonIndex = 0;
  bool _isQualitySelectorFocused = false;
  bool _isSeasonSelectorFocused = false;
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
    
    var filtered = _movieInfo!.downloadLinks;
    
    // Filter by quality
    if (_selectedQuality.isNotEmpty && _selectedQuality != 'All') {
      filtered = filtered.where((link) {
        return link.quality.toLowerCase().contains(_selectedQuality.toLowerCase());
      }).toList();
    }
    
    // Filter by season
    if (_selectedSeason != 'All') {
      filtered = filtered.where((link) {
        return link.season == _selectedSeason;
      }).toList();
    }
    
    return filtered;
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

  List<String> _getAvailableSeasons() {
    if (_movieInfo == null) return ['All'];
    
    final Set<String> seasons = {'All'};
    for (var link in _movieInfo!.downloadLinks) {
      if (link.season != null && link.season!.isNotEmpty) {
        seasons.add(link.season!);
      }
    }
    return seasons.toList();
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

  void _navigateSeasons(int delta) {
    if (!_isSeasonSelectorFocused) return;
    
    final seasons = _getAvailableSeasons();
    if (seasons.isEmpty) return;
    
    setState(() {
      _selectedSeasonIndex = (_selectedSeasonIndex + delta) % seasons.length;
      if (_selectedSeasonIndex < 0) {
        _selectedSeasonIndex = seasons.length - 1;
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

  void _selectCurrentSeason() {
    if (!_isSeasonSelectorFocused) return;
    
    final seasons = _getAvailableSeasons();
    if (_selectedSeasonIndex >= 0 && _selectedSeasonIndex < seasons.length) {
      setState(() {
        _selectedSeason = seasons[_selectedSeasonIndex];
        _selectedDownloadIndex = 0;
      });
    }
  }

  void _navigateVertical(int delta) {
    setState(() {
      if (delta < 0) {
        // Up arrow
        if (!_isBackButtonFocused && !_isQualitySelectorFocused && !_isSeasonSelectorFocused && _selectedDownloadIndex == 0) {
          // From first download to quality/season selector
          final seasons = _getAvailableSeasons();
          if (seasons.length > 1) {
            _isSeasonSelectorFocused = true;
          } else {
            _isQualitySelectorFocused = true;
          }
        } else if (_isSeasonSelectorFocused) {
          // From season to quality selector
          _isSeasonSelectorFocused = false;
          _isQualitySelectorFocused = true;
        } else if (_isQualitySelectorFocused) {
          // From quality selector to back button
          _isQualitySelectorFocused = false;
          _isBackButtonFocused = true;
          _scrollToTop();
        } else if (!_isBackButtonFocused && !_isQualitySelectorFocused && !_isSeasonSelectorFocused) {
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
          // From quality selector to season selector or downloads
          _isQualitySelectorFocused = false;
          final seasons = _getAvailableSeasons();
          if (seasons.length > 1) {
            _isSeasonSelectorFocused = true;
          }
        } else if (_isSeasonSelectorFocused) {
          // From season selector to downloads
          _isSeasonSelectorFocused = false;
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
    final seasons = _getAvailableSeasons();
    
    return KeyEventHandler(
      onLeftKey: () {
        if (_isQualitySelectorFocused) {
          _navigateQualities(-1);
        } else if (_isSeasonSelectorFocused) {
          _navigateSeasons(-1);
        } else {
          _navigateDownloads(-1);
        }
      },
      onRightKey: () {
        if (_isQualitySelectorFocused) {
          _navigateQualities(1);
        } else if (_isSeasonSelectorFocused) {
          _navigateSeasons(1);
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
          _selectCurrentQuality();
          _seasonListKey.currentState?.openDropdown();
        } else if (_isSeasonSelectorFocused) {
          _selectCurrentSeason();
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
        body: Stack(
          children: [
            // Background Image with Blur
            if (_movieInfo != null && _movieInfo!.imageUrl.isNotEmpty)
              Positioned.fill(
                child: ShaderMask(
                  shaderCallback: (rect) {
                    return LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black.withOpacity(0.3), Colors.black],
                      stops: const [0.0, 0.8],
                    ).createShader(rect);
                  },
                  blendMode: BlendMode.darken,
                  child: Image.network(
                    _movieInfo!.imageUrl,
                    headers: const {
                      'User-Agent': 'Mozilla/5.0',
                      'Referer': 'https://www.reddit.com/',
                    },
                    fit: BoxFit.cover,
                    color: Colors.black.withOpacity(0.8),
                    colorBlendMode: BlendMode.darken,
                    errorBuilder: (_, __, ___) => const SizedBox(),
                  ),
                ),
              ),

            // Content
            _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.red))
                : _error.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 60, color: Colors.orange),
                            const SizedBox(height: 20),
                            Text(
                              _error,
                              style: const TextStyle(color: Colors.white, fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 30),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Go Back'),
                            ),
                          ],
                        ),
                      )
                    : _buildContent(qualities, seasons),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(List<String> qualities, List<String> seasons) {
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
      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: _isBackButtonFocused ? Colors.red : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                  border: _isBackButtonFocused
                      ? Border.all(color: Colors.white, width: 2)
                      : Border.all(color: Colors.transparent, width: 2),
                ),
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text(
                    'Back',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          
          // Movie header with poster and details
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poster
              Container(
                width: 320,
                height: 480,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.6),
                      blurRadius: 30,
                      spreadRadius: 10,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _movieInfo!.imageUrl.isNotEmpty
                    ? Image.network(
                        _movieInfo!.imageUrl,
                        headers: const {
                          'User-Agent': 'Mozilla/5.0',
                          'Referer': 'https://www.reddit.com/',
                        },
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[900],
                          child: const Icon(Icons.movie, color: Colors.white54, size: 80),
                        ),
                      )
                    : Container(
                        color: Colors.grey[900],
                        child: const Icon(Icons.movie, color: Colors.white54, size: 80),
                      ),
                ),
              ),
              const SizedBox(width: 50),
              
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _movieInfo!.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Meta Badges
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        if (_movieInfo!.imdbRating.isNotEmpty)
                           _buildMetaBadge(Icons.star, _movieInfo!.imdbRating, Colors.amber),
                        if (_movieInfo!.quality.isNotEmpty)
                           _buildMetaBadge(Icons.hd, _movieInfo!.quality, Colors.blue),
                        if (_movieInfo!.language.isNotEmpty)
                           _buildMetaBadge(Icons.language, _movieInfo!.language, Colors.green),
                      ],
                    ),

                    const SizedBox(height: 30),
                    
                    // Storyline (Moved up)
                    if (_movieInfo!.storyline.isNotEmpty) ...[
                      Text(
                        _movieInfo!.storyline,
                        style: TextStyle(
                          color: Colors.grey[300],
                          fontSize: 16,
                          height: 1.6,
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 30),
                    ],

                    _buildInfoRow('Genre', _movieInfo!.genre),
                    _buildInfoRow('Director', _movieInfo!.director),
                    _buildInfoRow('Stars', _movieInfo!.stars),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 50),
          
          Divider(color: Colors.white.withOpacity(0.1)),
          
          const SizedBox(height: 30),

          // Quality and Season selectors
          Row(
            children: [
              const Text(
                'Available Downloads',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (seasons.length > 1) ...[
                SizedBox(
                  width: 240,
                  child: SeasonList(
                    items: seasons,
                    selectedItem: _selectedSeason,
                    label: "Season",
                    icon: Icons.folder_open,
                    isFocused: _isSeasonSelectorFocused,
                    onChanged: (season) {
                      setState(() {
                        _selectedSeason = season;
                        _selectedDownloadIndex = 0;
                        _selectedSeasonIndex = seasons.indexOf(season);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
              ],
              SizedBox(
                width: 240,
                child: SeasonList(
                  key: _seasonListKey,
                  items: qualities,
                  selectedItem: _selectedQuality,
                  label: "Quality",
                  icon: Icons.hd_outlined,
                  isFocused: _isQualitySelectorFocused,
                  onChanged: (quality) {
                    setState(() {
                      _selectedQuality = quality;
                      _selectedDownloadIndex = 0;
                      _selectedQualityIndex = qualities.indexOf(quality);
                    });
                  },
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 30),
          
          _buildDownloadLinks(),
          const SizedBox(height: 100), // Bottom padding
        ],
      ),
    );
  }

  Widget _buildMetaBadge(IconData icon, String text, Color color) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400), // Prevent super wide badges
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
     if (value.isEmpty) return const SizedBox.shrink();
     return Padding(
       padding: const EdgeInsets.only(bottom: 8.0),
       child: RichText(
         text: TextSpan(
           style: const TextStyle(fontSize: 15, height: 1.5),
           children: [
             TextSpan(
               text: '$label:  ',
               style: TextStyle(color: Colors.grey[500]),
             ),
             TextSpan(
               text: value,
               style: const TextStyle(color: Colors.white),
             ),
           ],
         ),
       ),
     );
  }

  Widget _buildDownloadLinks() {
    final downloads = _getFilteredDownloads();
    
    if (downloads.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(Icons.cloud_off, size: 48, color: Colors.grey[800]),
            const SizedBox(height: 16),
            Text(
              'No download links available',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Column(
      children: downloads.asMap().entries.map((entry) {
        final index = entry.key;
        final download = entry.value;
        final isSelected = index == _selectedDownloadIndex;
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () => _openDownloadLink(download),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              transform: Matrix4.identity()..scale(isSelected ? 1.02 : 1.0),
              height: 72,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isSelected 
                    ? const Color(0xFFD32F2F) // Cleaner solid red
                    : const Color(0xFF212121), // Dark grey
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.white.withOpacity(0.05),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ] : [],
              ),
              child: Row(
                children: [
                  // Quality Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black26, // Subtle background for text
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      download.quality,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Metadata
                  Expanded(
                    child: Row(
                      children: [
                        if (download.season != null || download.episodeInfo != null) ...[
                          Icon(
                            Icons.movie_creation_outlined,
                            size: 16,
                            color: isSelected ? Colors.white70 : Colors.grey[500],
                          ),
                          const SizedBox(width: 8),
                          if (download.season != null)
                             Text(
                              download.season!,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.grey[300],
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          if (download.season != null && download.episodeInfo != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Text('•', style: TextStyle(color: Colors.white24)),
                            ),
                          if (download.episodeInfo != null)
                            Expanded(
                              child: Text(
                                download.episodeInfo!,
                                style: TextStyle(
                                  color: isSelected ? Colors.white70 : Colors.grey[500],
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),

                  // File Size
                  Row(
                    children: [
                      Icon(
                        Icons.data_usage,
                        size: 16,
                        color: isSelected ? Colors.white70 : Colors.grey[600],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        download.size,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[400],
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(width: 20),

                  // Download Icon
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.download_rounded,
                      color: isSelected ? Colors.white : Colors.grey[500],
                      size: 20,
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
        content: Text('Fetching episodes...'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 30),
      ),
    );
    
    try {
      // Step 1: Fetch Episodes from the download URL page
      print('Step 1: Fetching episodes from: ${downloadLink.url}');
      final episodes = await EpisodeParser.fetchEpisodes(downloadLink.url);
      print('Found ${episodes.length} episodes');
      
      if (episodes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No episodes found on download page'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      Episode? selectedEpisode;

      if (episodes.length == 1) {
        selectedEpisode = episodes.first;
      } else {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        selectedEpisode = await showDialog<Episode>(
          context: context,
          barrierDismissible: true,
          builder: (context) => EpisodeSelectionDialog(
            episodes: episodes,
            quality: downloadLink.quality,
          ),
        );
      }

      if (selectedEpisode == null) {
        // User cancelled selection
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
      
      // Step 2: Extract streaming links from HubCloud using the selected episode link
      final hubCloudUrl = selectedEpisode.link;
      print('Step 2: Extracting streams from HubCloud: $hubCloudUrl for ${selectedEpisode.title}');
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
