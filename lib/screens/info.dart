import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/movie_info.dart';
import '../provider/drive/index.dart';
import '../provider/hdhub/index.dart';
import '../provider/xdmovies/index.dart';
import '../provider/desiremovies/index.dart';
import '../provider/moviesmod/index.dart';
import '../provider/zinkmovies/info.dart' as zinkmovies_info;
import '../provider/zinkmovies/getstream.dart' as zinkmovies_stream;
import '../provider/animesalt/info.dart' as animesalt_info;
import '../provider/animesalt/getstream.dart' as animesalt_stream;
import '../provider/movies4u/index.dart';
import '../provider/provider_manager.dart';
import '../widgets/seasonlist.dart';
import '../utils/key_event_handler.dart';
import '../widgets/streaming_links_dialog.dart';
import '../widgets/episode_selection_dialog.dart';
import '../provider/extractors/stream_types.dart' as stream_types;
import '../provider/extractors/vcloud_extractor.dart';

class InfoScreen extends StatefulWidget {
  final String movieUrl;

  const InfoScreen({super.key, required this.movieUrl});

  @override
  State<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen> {
  static const kGoldColor = Color(0xFFFFD700);

  MovieInfo? _movieInfo;
  bool _isLoading = true;
  bool _isLoadingLinks = false;
  String _error = '';
  String _selectedQuality = '';
  String _selectedSeason = '';
  int _selectedDownloadIndex = 0;
  int _selectedQualityIndex = 0;
  int _selectedSeasonIndex = 0;
  bool _isQualitySelectorFocused = false;
  bool _isSeasonSelectorFocused = false;
  bool _isBackButtonFocused = false;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<SeasonListState> _seasonListKey =
      GlobalKey<SeasonListState>();
  final GlobalKey<SeasonListState> _qualityListKey =
      GlobalKey<SeasonListState>();

  // Provider Manager for multi-provider support
  final ProviderManager _providerManager = ProviderManager();
  String get _currentProvider => _providerManager.activeProvider;

  // Episode loading state
  List<Episode> _episodes = [];
  bool _isLoadingEpisodes = false;
  String _currentEpisodeUrl = '';

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
      // Load movie info based on active provider
      MovieInfo movieInfo;

      switch (_currentProvider) {
        case 'Hdhub':
          movieInfo = await HdhubInfoParser.fetchMovieInfo(widget.movieUrl);
          break;
        case 'Xdmovies':
          movieInfo = await XdmoviesInfo.fetchMovieInfo(widget.movieUrl);
          break;
        case 'Desiremovies':
          movieInfo = await DesireMoviesInfo.fetchMovieInfo(widget.movieUrl);
          break;
        case 'Moviesmod':
          movieInfo = await MoviesmodInfo.fetchMovieInfo(widget.movieUrl);
          break;
        case 'Zinkmovies':
          movieInfo = await zinkmovies_info.fetchMovieInfo(widget.movieUrl);
          break;
        case 'Animesalt':
          movieInfo = await animesalt_info.animesaltGetInfo(widget.movieUrl);
          break;
        case 'Movies4u':
          movieInfo = await Movies4uInfo.fetchMovieInfo(widget.movieUrl);
          break;
        case 'Drive':
        default:
          movieInfo = await MovieInfoParser.fetchMovieInfo(widget.movieUrl);
          break;
      }

      setState(() {
        _movieInfo = movieInfo;
        _isLoading = false;
        // Set default quality and season to first available
        final qualities = _getAvailableQualities();
        final seasons = _getAvailableSeasons();

        if (qualities.isNotEmpty) {
          _selectedQuality = qualities.first;
          _selectedQualityIndex = 0;
        }

        if (seasons.isNotEmpty) {
          _selectedSeason = seasons.first;
          _selectedSeasonIndex = 0;
        }

        // Auto-load episodes if both are selected
        if (_selectedQuality.isNotEmpty && _selectedSeason.isNotEmpty) {
          _loadEpisodesIfNeeded();
        }
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Process download URL for hdhub provider (only for gadgetsweb.xyz links)
  Future<String> _processDownloadUrl(String url) async {
    // Only process for Hdhub provider
    if (_currentProvider != 'Hdhub') {
      return url;
    }

    // Only call external API for gadgetsweb.xyz links
    if (url.contains('gadgetsweb.xyz') && url.contains('?id=')) {
      try {
        print('Processing gadgetsweb.xyz URL with external API: $url');

        // Use getRedirectLinks which calls the external API for gadgetsweb
        final processedUrl = await getRedirectLinks(url);
        print('Got processed URL from API: $processedUrl');

        return processedUrl;
      } catch (e) {
        print('Error processing gadgetsweb URL: $e');
        return url;
      }
    }

    // For all other links, return as-is (HubCloudExtractor will handle them)
    return url;
  }

  List<DownloadLink> _getFilteredDownloads() {
    if (_movieInfo == null) return [];

    var filtered = _movieInfo!.downloadLinks;

    // Filter by quality
    if (_selectedQuality.isNotEmpty) {
      filtered = filtered.where((link) {
        return link.quality.toLowerCase().contains(
          _selectedQuality.toLowerCase(),
        );
      }).toList();
    }

    // Filter by season
    if (_selectedSeason.isNotEmpty) {
      filtered = filtered.where((link) {
        return link.season == _selectedSeason;
      }).toList();
    }

    // Remove duplicates based on quality + season + url combination
    final seen = <String>{};
    filtered = filtered.where((link) {
      final uniqueKey = '${link.quality}_${link.season ?? ""}_${link.url}';
      final isDuplicate = seen.contains(uniqueKey);
      if (!isDuplicate) {
        seen.add(uniqueKey);
      }
      return !isDuplicate;
    }).toList();

    return filtered;
  }

  List<String> _getAvailableQualities() {
    if (_movieInfo == null) return [];

    final Set<String> qualities = {};
    for (var link in _movieInfo!.downloadLinks) {
      final match = RegExp(
        r'(480p|720p|1080p|2160p|4k)',
      ).firstMatch(link.quality);
      if (match != null) {
        qualities.add(match.group(0)!);
      }
    }
    return qualities.toList();
  }

  List<String> _getAvailableSeasons() {
    if (_movieInfo == null) return [];

    final Set<String> seasons = {};
    for (var link in _movieInfo!.downloadLinks) {
      if (link.season != null && link.season!.isNotEmpty) {
        seasons.add(link.season!);
      }
    }
    return seasons.toList();
  }

  void _navigateDownloads(int delta) {
    if (_isQualitySelectorFocused || _isSeasonSelectorFocused) return;

    // Navigate episodes if they're loaded, otherwise navigate downloads
    final itemCount = _episodes.isNotEmpty
        ? _episodes.length
        : _getFilteredDownloads().length;
    if (itemCount == 0) return;

    setState(() {
      _selectedDownloadIndex = (_selectedDownloadIndex + delta) % itemCount;
      if (_selectedDownloadIndex < 0) {
        _selectedDownloadIndex = itemCount - 1;
      }
    });
    _scrollToSelected();
  }

  void _navigateQualities(int delta) {
    if (!_isQualitySelectorFocused) {
      return; // Only navigate qualities when focused
    }

    final qualities = _getAvailableQualities();
    if (qualities.isEmpty) return;

    setState(() {
      _selectedQualityIndex =
          (_selectedQualityIndex + delta) % qualities.length;
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
    if (_selectedQualityIndex >= 0 &&
        _selectedQualityIndex < qualities.length) {
      setState(() {
        _selectedQuality = qualities[_selectedQualityIndex];
        _selectedDownloadIndex = 0;
      });
      _loadEpisodesIfNeeded();
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
      _loadEpisodesIfNeeded();
    }
  }

  Future<void> _loadEpisodesIfNeeded() async {
    // Only load episodes if both season and quality are selected
    if (_selectedSeason.isEmpty || _selectedQuality.isEmpty) {
      setState(() {
        _episodes = [];
        _currentEpisodeUrl = '';
      });
      return;
    }

    final downloads = _getFilteredDownloads();
    if (downloads.isEmpty) {
      setState(() {
        _episodes = [];
        _currentEpisodeUrl = '';
      });
      return;
    }

    // Use the first download link for this season/quality combo
    final downloadUrl = downloads.first.url;

    // Don't reload if we already have episodes for this URL
    if (_currentEpisodeUrl == downloadUrl && _episodes.isNotEmpty) {
      return;
    }

    setState(() {
      _isLoadingEpisodes = true;
      _currentEpisodeUrl = downloadUrl;
    });

    try {
      // Process the URL if it's a gadgetsweb.xyz link for Hdhub provider
      final processedUrl = await _processDownloadUrl(downloadUrl);
      print('Fetching episodes from processed URL: $processedUrl');

      // If the processed URL is a hubcloud link, don't try to fetch episodes
      // Hubcloud links don't contain episode lists, they ARE the final link
      if (processedUrl.contains('hubcloud')) {
        print('Processed URL is a hubcloud link, skipping episode fetch');
        setState(() {
          _episodes = [];
          _isLoadingEpisodes = false;
        });
        return;
      }

      // Fetch episodes based on provider
      List<Episode> episodes;
      
      switch (_currentProvider) {
        case 'Moviesmod':
          // For Moviesmod, fetch episode list from the stored URL
          final episodeData = await MoviesmodGetEpisodes.getEpisodeLinks(processedUrl);
          episodes = episodeData.map((ep) => Episode(
            title: ep['title']!,
            link: ep['link']!,
          )).toList();
          break;
        case 'Movies4u':
          episodes = await Movies4uGetEps.fetchEpisodes(processedUrl);
          break;
        default:
          episodes = await EpisodeParser.fetchEpisodes(processedUrl);
          break;
      }
      
      setState(() {
        _episodes = episodes;
        _isLoadingEpisodes = false;
        _selectedDownloadIndex = 0;
      });
    } catch (e) {
      print('Error loading episodes: $e');
      setState(() {
        _episodes = [];
        _isLoadingEpisodes = false;
      });
    }
  }

  void _navigateVertical(int delta) {
    setState(() {
      if (delta < 0) {
        // Up arrow
        if (!_isBackButtonFocused &&
            !_isQualitySelectorFocused &&
            !_isSeasonSelectorFocused &&
            _selectedDownloadIndex == 0) {
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
        } else if (!_isBackButtonFocused &&
            !_isQualitySelectorFocused &&
            !_isSeasonSelectorFocused) {
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
        final double targetPosition =
            400 + (_selectedDownloadIndex * itemHeight);

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
          // Navigate from quality to season (if seasons exist)
          final seasons = _getAvailableSeasons();
          if (seasons.length > 1) {
            setState(() {
              _isQualitySelectorFocused = false;
              _isSeasonSelectorFocused = true;
            });
          } else {
            _navigateQualities(-1);
          }
        } else if (_isSeasonSelectorFocused) {
          _navigateSeasons(-1);
        } else {
          _navigateDownloads(-1);
        }
      },
      onRightKey: () {
        if (_isSeasonSelectorFocused) {
          // Navigate from season to quality
          setState(() {
            _isSeasonSelectorFocused = false;
            _isQualitySelectorFocused = true;
          });
        } else if (_isQualitySelectorFocused) {
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
          _selectCurrentQuality();
          _qualityListKey.currentState?.openDropdown();
        } else if (_isSeasonSelectorFocused) {
          _selectCurrentSeason();
          // Open season dropdown if available
          _seasonListKey.currentState?.openDropdown();
        } else {
          // If episodes are loaded, play the selected episode
          if (_episodes.isNotEmpty &&
              _selectedDownloadIndex < _episodes.length) {
            // For Moviesmod, use moviesmodGetStream directly
            if (_currentProvider == 'Moviesmod') {
              final episode = _episodes[_selectedDownloadIndex];
              setState(() => _isLoadingLinks = true);
              
              moviesmodGetStream(episode.link).then((streams) {
                setState(() => _isLoadingLinks = false);
                if (streams.isNotEmpty) {
                  _showStreamingLinksDialog(streams, _selectedQuality);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No streams found'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }).catchError((e) {
                print('Error getting streams: $e');
                setState(() => _isLoadingLinks = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              });
            } else {
              _playEpisode(_episodes[_selectedDownloadIndex]);
            }
          } else {
            // Otherwise, open download link
            final downloads = _getFilteredDownloads();
            if (downloads.isNotEmpty) {
              _openDownloadLink(downloads[_selectedDownloadIndex]);
            }
          }
        }
      },
      onBackKey: () => Navigator.of(context).pop(),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (!didPop) {
            Navigator.of(context).pop();
          }
        },
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
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const SizedBox();
                      },
                      errorBuilder: (_, __, ___) => const SizedBox(),
                    ),
                  ),
                ),

              // Content
              _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.amber),
                    )
                  : _error.isNotEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 60,
                            color: Colors.orange,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _error,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
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

              // Loading Overlay for Links
              if (_isLoadingLinks)
                Positioned.fill(
                  child: Stack(
                    children: [
                      // Blur effect
                      BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                        child: Container(color: Colors.black.withOpacity(0.5)),
                      ),
                      // Loader
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                kGoldColor,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'FETCHING LINKS...',
                              style: TextStyle(
                                color: kGoldColor,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
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
                  color: _isBackButtonFocused
                      ? Colors.red
                      : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                  border: _isBackButtonFocused
                      ? Border.all(color: Colors.white, width: 2)
                      : Border.all(color: Colors.transparent, width: 2),
                ),
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
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
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: Colors.grey[900],
                              child: Center(
                                child: CircularProgressIndicator(
                                  value:
                                      loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                      : null,
                                  color: Colors.amber,
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                color: Colors.grey[900],
                                child: const Icon(
                                  Icons.movie,
                                  color: Colors.white54,
                                  size: 80,
                                ),
                              ),
                        )
                      : Container(
                          color: Colors.grey[900],
                          child: const Icon(
                            Icons.movie,
                            color: Colors.white54,
                            size: 80,
                          ),
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
                          _buildMetaBadge(
                            Icons.star,
                            _movieInfo!.imdbRating,
                            Colors.amber,
                          ),
                        if (_movieInfo!.quality.isNotEmpty)
                          _buildMetaBadge(
                            Icons.hd,
                            _movieInfo!.quality,
                            Colors.blue,
                          ),
                        if (_movieInfo!.language.isNotEmpty)
                          _buildMetaBadge(
                            Icons.language,
                            _movieInfo!.language,
                            Colors.green,
                          ),
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
                    key: _seasonListKey,
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
                      _loadEpisodesIfNeeded();
                    },
                  ),
                ),
                const SizedBox(width: 16),
              ],
              SizedBox(
                width: 240,
                child: SeasonList(
                  key: _qualityListKey,
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
                    _loadEpisodesIfNeeded();
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 30),

          // Show episodes if loaded, otherwise show download links
          _episodes.isNotEmpty ? _buildEpisodeList() : _buildDownloadLinks(),
          const SizedBox(height: 100), // Bottom padding
        ],
      ),
    );
  }

  Widget _buildMetaBadge(IconData icon, String text, Color color) {
    return Container(
      constraints: const BoxConstraints(
        maxWidth: 400,
      ), // Prevent super wide badges
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

    if (_isLoadingEpisodes) {
      return Container(
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        child: const Column(
          children: [
            CircularProgressIndicator(color: Colors.amber),
            SizedBox(height: 16),
            Text(
              'Loading episodes...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      );
    }

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
                    ? Colors.amber // Yellowish
                    : const Color(0xFF212121), // Dark grey
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? Colors.amber
                      : Colors.white.withOpacity(0.05),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: Row(
                children: [
                  // Quality Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
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
                        if (download.season != null ||
                            download.episodeInfo != null) ...[
                          Icon(
                            Icons.movie_creation_outlined,
                            size: 16,
                            color: isSelected
                                ? Colors.black54
                                : Colors.grey[500],
                          ),
                          const SizedBox(width: 8),
                          if (download.season != null)
                            Text(
                              download.season!,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.black87
                                    : Colors.grey[300],
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          if (download.season != null &&
                              download.episodeInfo != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: Text(
                                '•',
                                style: TextStyle(color: isSelected ? Colors.black26 : Colors.white24),
                              ),
                            ),
                          if (download.episodeInfo != null)
                            Expanded(
                              child: Text(
                                download.episodeInfo!,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.black54
                                      : Colors.grey[500],
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
                        color: isSelected ? Colors.black54 : Colors.grey[600],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        download.size,
                        style: TextStyle(
                          color: isSelected ? Colors.black87 : Colors.grey[400],
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
                      color: isSelected ? Colors.black87 : Colors.grey[500],
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

  Widget _buildEpisodeList() {
    if (_isLoadingEpisodes) {
      return Container(
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        child: const Column(
          children: [
            CircularProgressIndicator(color: Colors.amber),
            SizedBox(height: 16),
            Text(
              'Loading episodes...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (_episodes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(Icons.movie, size: 48, color: Colors.grey[800]),
            const SizedBox(height: 16),
            Text(
              'No episodes found',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _episodes.asMap().entries.map((entry) {
        final index = entry.key;
        final episode = entry.value;
        final isSelected = index == _selectedDownloadIndex;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () {
              // For Moviesmod, use moviesmodGetStream directly
              if (_currentProvider == 'Moviesmod') {
                setState(() => _isLoadingLinks = true);
                
                moviesmodGetStream(episode.link).then((streams) {
                  setState(() => _isLoadingLinks = false);
                  if (streams.isNotEmpty) {
                    _showStreamingLinksDialog(streams, _selectedQuality);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No streams found'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }).catchError((e) {
                  print('Error getting streams: $e');
                  setState(() => _isLoadingLinks = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                });
              } else {
                _playEpisode(episode);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              transform: Matrix4.identity()..scale(isSelected ? 1.02 : 1.0),
              height: 72,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.amber
                    : const Color(0xFF212121),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? Colors.amber
                      : Colors.white.withOpacity(0.05),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: Row(
                children: [
                  // Episode icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.play_circle_fill,
                      color: isSelected ? Colors.black87 : Colors.grey[500],
                      size: 24,
                    ),
                  ),

                  const SizedBox(width: 16),

                  Expanded(
                    child: Text(
                      episode.title,
                      style: TextStyle(
                        color: isSelected ? Colors.black87 : Colors.grey[300],
                        fontSize: 16,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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

  Future<void> _playEpisode(Episode episode) async {
    setState(() {
      _isLoadingLinks = true;
    });

    try {
      // Collect all streams from all available links
      List<stream_types.Stream> allStreams = [];

      // If episode has multiple links, process all of them
      if (episode.links != null && episode.links!.isNotEmpty) {
        print(
          'Processing ${episode.links!.length} links for episode: ${episode.title}',
        );

        for (var episodeLink in episode.links!) {
          try {
            print('Processing ${episodeLink.server} link: ${episodeLink.url}');

            // Process the link
            final processedLink = await _processDownloadUrl(episodeLink.url);

            // Extract streams based on server type
            if (episodeLink.server == 'VCloud') {
              print('Extracting streams from VCloud: $processedLink');
              final vcloudStreams = await VCloudExtractor.extractStreams(
                processedLink,
              );
              if (vcloudStreams.isNotEmpty) {
                print('VCloud extracted ${vcloudStreams.length} streams');
                allStreams.addAll(vcloudStreams);
              }
            } else if (episodeLink.server == 'GDFlix') {
              print('Extracting streams from GDFlix: $processedLink');
              final gdflixStreams = await GdFlixExtractor.extractStreams(
                processedLink,
              );
              if (gdflixStreams.isNotEmpty) {
                print('GDFlix extracted ${gdflixStreams.length} streams');
                allStreams.addAll(gdflixStreams);
              }
            } else if (episodeLink.server == 'HubCloud') {
              print('Extracting streams from HubCloud: $processedLink');
              final result = await HubCloudExtractor.extractLinks(
                processedLink,
              );
              if (result.success && result.streams.isNotEmpty) {
                print('HubCloud extracted ${result.streams.length} streams');
                allStreams.addAll(result.streams);
              }
            }
          } catch (e) {
            print('Error extracting from ${episodeLink.server}: $e');
            // Continue to next link even if this one fails
          }
        }
      } else {
        // Fallback: Use primary link with HubCloud extractor (backward compatibility)
        print('Using primary link: ${episode.link}');
        final processedLink = await _processDownloadUrl(episode.link);
        final result = await HubCloudExtractor.extractLinks(processedLink);
        if (result.success && result.streams.isNotEmpty) {
          allStreams.addAll(result.streams);
        }
      }

      setState(() {
        _isLoadingLinks = false;
      });

      if (allStreams.isNotEmpty) {
        print('Total streams extracted: ${allStreams.length}');
        // Show dialog with all collected streaming links
        _showStreamingLinksDialog(allStreams, _selectedQuality);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No streaming links found from any source'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error playing episode: $e');
      setState(() {
        _isLoadingLinks = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _openDownloadLink(DownloadLink downloadLink) async {
    print('=== DOWNLOAD LINK DEBUG ===');
    print('Quality: ${downloadLink.quality}');
    print('Size: ${downloadLink.size}');
    print('URL: ${downloadLink.url}');
    print('========================');

    setState(() {
      _isLoadingLinks = true;
    });

    try {
      if (_currentProvider == 'Xdmovies') {
        final streams = await xdmoviesGetStream(downloadLink.url, downloadLink.quality);
        setState(() => _isLoadingLinks = false);
        if (streams.isNotEmpty) {
          _showStreamingLinksDialog(streams, downloadLink.quality);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No streams found'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (_currentProvider == 'Desiremovies') {
        final streams = await desireMoviesGetStream(downloadLink.url, downloadLink.quality);
        setState(() => _isLoadingLinks = false);
        if (streams.isNotEmpty) {
          _showStreamingLinksDialog(streams, downloadLink.quality);
        } else {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No streams found'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (_currentProvider == 'Moviesmod') {
        // Episodes are already loaded via _loadEpisodesIfNeeded()
        // This is called when clicking on an individual episode
        // Just get streams directly from the link
        final streams = await moviesmodGetStream(downloadLink.url);
        setState(() => _isLoadingLinks = false);
        if (streams.isNotEmpty) {
          _showStreamingLinksDialog(streams, downloadLink.quality);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No streams found'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (_currentProvider == 'Zinkmovies') {
        final streams = await zinkmovies_stream.getStream(downloadLink.url, downloadLink.quality);
        setState(() => _isLoadingLinks = false);
        if (streams.isNotEmpty) {
          _showStreamingLinksDialog(streams, downloadLink.quality);
        } else {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No streams found'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (_currentProvider == 'Animesalt') {
        final streams = await animesalt_stream.animesaltGetStream(downloadLink.url, downloadLink.quality);
        setState(() => _isLoadingLinks = false);
        if (streams.isNotEmpty) {
          _showStreamingLinksDialog(streams, downloadLink.quality);
        } else {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No streams found'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Step 1: Process the download URL
      print('Step 1: Processing download URL: ${downloadLink.url}');
      final processedUrl = await _processDownloadUrl(downloadLink.url);
      print('Processed URL: $processedUrl');

      // If the processed URL is a hubcloud, gdflix, or vcloud link, directly extract streams from it
      if (processedUrl.contains('hubcloud') ||
          processedUrl.contains('gdflix') ||
          processedUrl.contains('vcloud.zip') ||
          processedUrl.contains('vcloud.lol')) {
        print('Processed URL is a direct link, extracting streams');

        List<stream_types.Stream> allStreams = [];

        if (processedUrl.contains('vcloud.zip') || processedUrl.contains('vcloud.lol')) {
          print('Processing VCloud link');
          final vcloudStreams = await VCloudExtractor.extractStreams(
            processedUrl,
          );
          if (vcloudStreams.isNotEmpty) {
            allStreams.addAll(vcloudStreams);
          }
        } else if (processedUrl.contains('gdflix')) {
          print('Processing GDFlix link');
          final gdflixStreams = await GdFlixExtractor.extractStreams(
            processedUrl,
          );
          if (gdflixStreams.isNotEmpty) {
            allStreams.addAll(gdflixStreams);
          }
        } else if (processedUrl.contains('hubcloud')) {
          print('Processing HubCloud link');
          final result = await HubCloudExtractor.extractLinks(processedUrl);
          if (result.success && result.streams.isNotEmpty) {
            allStreams.addAll(result.streams);
          }
        }

        print('Extractor result - Streams count: ${allStreams.length}');

        setState(() {
          _isLoadingLinks = false;
        });

        if (allStreams.isNotEmpty) {
          _showStreamingLinksDialog(allStreams, downloadLink.quality);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No streaming links found'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Otherwise, fetch episodes from the processed URL
      print('Fetching episodes from processed URL: $processedUrl');
      
      // Fetch episodes based on provider
      List<Episode> episodes;
      
      switch (_currentProvider) {
        case 'Movies4u':
          episodes = await Movies4uGetEps.fetchEpisodes(processedUrl);
          break;
        default:
          episodes = await EpisodeParser.fetchEpisodes(processedUrl);
          break;
      }
      
      print('Found ${episodes.length} episodes');

      if (episodes.isEmpty) {
        setState(() {
          _isLoadingLinks = false;
        });
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
        setState(() {
          _isLoadingLinks = false;
        });

        selectedEpisode = await showDialog<Episode>(
          context: context,
          barrierDismissible: true,
          builder: (context) => EpisodeSelectionDialog(
            episodes: episodes,
            quality: downloadLink.quality,
          ),
        );

        if (selectedEpisode != null) {
          setState(() {
            _isLoadingLinks = true;
          });
        }
      }

      if (selectedEpisode == null) {
        // User cancelled selection or no selection made
        // No need to set isLoadingLinks to false as it was set to false before dialog
        return;
      }

      // Step 2: Process all links from the selected episode
      print(
        'Step 2: Processing selected episode with all available links: ${selectedEpisode.title}',
      );

      // Use the _playEpisode method which processes all links
      await _playEpisode(selectedEpisode);
    } catch (e) {
      print('Error in download link processing: $e');
      setState(() {
        _isLoadingLinks = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _showStreamingLinksDialog(
    List<stream_types.Stream> streams,
    String quality,
  ) {
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
