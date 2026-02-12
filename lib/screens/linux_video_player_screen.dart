 import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import '../provider/extractors/stream_types.dart' as stream_types;
import '../utils/key_event_handler.dart';
import '../utils/subtitle_service.dart';

class LinuxVideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;
  final String server;
  final Map<String, String>? headers;
  final List<stream_types.Stream>? streams;
  final int? currentStreamIndex;

  const LinuxVideoPlayerScreen({
    super.key,
    required this.videoUrl,
    required this.title,
    required this.server,
    this.headers,
    this.streams,
    this.currentStreamIndex,
  });

  @override
  State<LinuxVideoPlayerScreen> createState() => _LinuxVideoPlayerScreenState();
}

class _LinuxVideoPlayerScreenState extends State<LinuxVideoPlayerScreen> {
  late final Player player;
  late final VideoController controller;
  
  bool _hasError = false;
  String _errorMessage = '';
  bool _showControls = true;
  bool _isPlaying = false;
  bool _isBuffering = true;
  bool _isPlayerReady = false;
  
  late String _currentVideoUrl;
  late String _currentServerName;
  late Map<String, String>? _currentHeaders;
  
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  
  // Audio track selection
  bool _showAudioMenu = false;
  List<AudioTrack> _audioTracks = [];
  int _selectedAudioIndex = 0;
  int _focusedAudioTrackIndex = 0;
  bool _isLoadingTracks = false;
  final ScrollController _audioScrollController = ScrollController();
  
  // Server selection
  bool _showServerMenu = false;
  int _focusedServerIndex = 0;
  final ScrollController _serverScrollController = ScrollController();
  
  // Subtitle selection
  bool _showSubtitleMenu = false;
  List<SubtitleTrack> _subtitleTracks = [];
  int _selectedSubtitleIndex = -1; // -1 means no subtitle
  int _focusedSubtitleTrackIndex = 0;
  bool _isLoadingSubtitles = false;
  final ScrollController _subtitleScrollController = ScrollController();
  
  // Focus management
  int _focusedButtonIndex = 0;
  int _focusedControlIndex = 1; // 0=backward, 1=play/pause, 2=forward, 3=audio, 4=subtitle, 5=server
  final int _totalControls = 6;
  
  // Auto-hide controls
  Timer? _hideControlsTimer;
  bool _isFullscreen = false;
  bool _isNfProvider = false;
  bool _hasShownNfWarning = false;

  @override
  void initState() {
    super.initState();
    _currentVideoUrl = widget.videoUrl;
    _currentServerName = widget.server;
    _currentHeaders = widget.headers;
    
    WakelockPlus.enable();
    _initializePlayer();
    _startHideControlsTimer();
    
    // Check for NF provider after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfNfProvider();
    });
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    WakelockPlus.disable();
    _audioScrollController.dispose();
    _serverScrollController.dispose();
    _subtitleScrollController.dispose();
    player.dispose();
    super.dispose();
  }

  void _checkIfNfProvider() {
    // Check if this is an nf provider stream
    final isNfUrl = _currentVideoUrl.contains('net22.cc') || 
                    _currentVideoUrl.contains('net51.cc') ||
                    (_currentVideoUrl.contains('net') && _currentVideoUrl.contains('.cc'));
    final isNfHeaders = _currentHeaders?.values.any((value) => 
                        value.contains('ott=nf')) ?? false;
    
    _isNfProvider = isNfUrl || isNfHeaders;
    
    print('[LinuxVideoPlayer] NF Provider check: isNfUrl=$isNfUrl, isNfHeaders=$isNfHeaders, _isNfProvider=$_isNfProvider');
    print('[LinuxVideoPlayer] URL: $_currentVideoUrl');
    print('[LinuxVideoPlayer] Headers: $_currentHeaders');
    
    if (_isNfProvider && !_hasShownNfWarning && mounted) {
      _hasShownNfWarning = true;
      print('[LinuxVideoPlayer] Showing NF warning dialog');
      _showNfWarningDialog();
    }
  }

  void _showNfWarningDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;
        
        return AlertDialog(
          backgroundColor: colorScheme.surfaceContainerHigh,
          icon: Icon(Icons.warning_amber_rounded, color: colorScheme.error, size: 32),
          title: const Text('Desktop Limitation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This stream from NF provider may not play properly on desktop due to technical limitations with authentication headers.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                color: colorScheme.secondaryContainer.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: colorScheme.outlineVariant.withOpacity(0.5),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: colorScheme.primary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Works perfectly on Android',
                          style: textTheme.labelLarge?.copyWith(
                            color: colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Continue Anyway'),
            ),
            FilledButton.icon(
              onPressed: () async {
                final url = Uri.parse('https://screenscape.fun');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
                if (mounted) {
                  Navigator.of(context).pop();
                }
              },
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Download Android App'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _initializePlayer() async {
    try {
      print('[LinuxVideoPlayer] Initializing player for: $_currentServerName');

      // Create player instance
      player = Player();
      controller = VideoController(player);

      // Listen to player state changes
      player.stream.playing.listen((playing) {
        if (mounted) {
          setState(() {
            _isPlaying = playing;
            // Mark player as ready when it starts playing
            if (playing && !_isPlayerReady) {
              _isPlayerReady = true;
              _isBuffering = false;
              print('[LinuxVideoPlayer] Player started playing');
            }
          });
        }
      });

      player.stream.position.listen((position) {
        if (mounted) {
          setState(() => _currentPosition = position);
        }
      });

      player.stream.duration.listen((duration) {
        if (mounted) {
          setState(() {
            _totalDuration = duration;
            // Also mark as ready if we get a valid duration
            if (duration > Duration.zero && !_isPlayerReady) {
              _isPlayerReady = true;
              _isBuffering = false;
              print('[LinuxVideoPlayer] Duration detected: $duration');
            }
          });
        }
      });

      player.stream.buffering.listen((buffering) {
        if (mounted) {
          setState(() => _isBuffering = buffering);
        }
      });

      player.stream.error.listen((error) {
        if (mounted && error.isNotEmpty) {
          print('[LinuxVideoPlayer] Error: $error');
          
          // Don't immediately show error if player is playing
          // (codec errors may occur but audio still works)
          if (!_isPlaying) {
            // Delay error display to see if playback starts anyway
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted && !_isPlaying && !_isPlayerReady) {
                setState(() {
                  _hasError = true;
                  _errorMessage = error;
                });
              }
            });
          }
        }
      });

      // Listen to audio tracks
      player.stream.tracks.listen((tracks) {
        if (mounted) {
          setState(() {
            _audioTracks = tracks.audio;
            _subtitleTracks = tracks.subtitle;
            if (_audioTracks.isNotEmpty && !_isLoadingTracks) {
              print('[LinuxVideoPlayer] Loaded ${_audioTracks.length} audio tracks');
            }
            if (_subtitleTracks.isNotEmpty && !_isLoadingSubtitles) {
              print('[LinuxVideoPlayer] Loaded ${_subtitleTracks.length} subtitle tracks');
            }
          });
        }
      });

      // Open and play media
      final Map<String, String> requestHeaders = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': '*/*',
        'Accept-Language': 'en-US,en;q=0.9',
        'Connection': 'keep-alive',
      };
      
      // Add custom headers if provided
      if (_currentHeaders != null && _currentHeaders!.isNotEmpty) {
        requestHeaders.addAll(_currentHeaders!);
        print('[LinuxVideoPlayer] Custom headers: ${_currentHeaders!.keys.join(', ')}');
      }
      
      print('[LinuxVideoPlayer] Video URL: $_currentVideoUrl');
      print('[LinuxVideoPlayer] Request headers: ${requestHeaders.keys.join(', ')}');

      await player.open(
        Media(
          _currentVideoUrl,
          httpHeaders: requestHeaders,
        ),
        play: true,
      );

      // Don't immediately clear buffering - wait for playback to start
      setState(() {
        _hasError = false;
      });
      
      // Set a timeout to clear loading if nothing happens
      Future.delayed(const Duration(seconds: 10), () {
        if (mounted && !_isPlayerReady) {
          print('[LinuxVideoPlayer] Timeout: Forcing player ready state');
          setState(() {
            _isPlayerReady = true;
            _isBuffering = false;
          });
        }
      });
      
      // Load audio tracks after a delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _loadAudioTracks();
        }
      });
    } catch (e) {
      print('[LinuxVideoPlayer] Initialization error: $e');
      print('[LinuxVideoPlayer] Video URL was: $_currentVideoUrl');
      print('[LinuxVideoPlayer] Headers were: $_currentHeaders');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to load video: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _playNextStream() async {
    if (widget.streams == null || widget.currentStreamIndex == null) return;
    
    final nextIndex = (widget.currentStreamIndex! + 1) % widget.streams!.length;
    final nextStream = widget.streams![nextIndex];
    
    await _switchStream(nextStream, nextIndex);
  }

  Future<void> _switchStream(stream_types.Stream stream, int index) async {
    setState(() {
      _currentVideoUrl = stream.link;
      _currentServerName = stream.server;
      _currentHeaders = stream.headers;
    });
    
    try {
      final Map<String, String> requestHeaders = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': '*/*',
        'Accept-Language': 'en-US,en;q=0.9',
        'Connection': 'keep-alive',
      };
      
      // Add custom headers if provided
      if (_currentHeaders != null && _currentHeaders!.isNotEmpty) {
        requestHeaders.addAll(_currentHeaders!);
        print('[LinuxVideoPlayer] Switching stream with headers: ${_currentHeaders!.keys.join(', ')}');
      }

      await player.open(
        Media(
          _currentVideoUrl,
          httpHeaders: requestHeaders,
        ),
        play: true,
      );

      if (mounted) {
        setState(() {
          _hasError = false;
          _isBuffering = false;
          _isPlayerReady = true;
        });
        _showSnackBar('Switched to $_currentServerName');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _togglePlayPause() {
    player.playOrPause();
  }

  void _seekBackward() {
    final newPosition = _currentPosition - const Duration(seconds: 10);
    player.seek(newPosition < Duration.zero ? Duration.zero : newPosition);
  }

  void _seekForward() {
    final newPosition = _currentPosition + const Duration(seconds: 10);
    player.seek(newPosition > _totalDuration ? _totalDuration : newPosition);
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade900,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _seekToPosition(double position) {
    if (_totalDuration.inMilliseconds > 0) {
      final seekPosition = Duration(
        milliseconds: (position * _totalDuration.inMilliseconds).round(),
      );
      player.seek(seekPosition);
      _resetHideControlsTimer();
    }
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && _showControls && !_showAudioMenu && !_showServerMenu && !_showSubtitleMenu) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _resetHideControlsTimer() {
    if (_showControls) {
      _startHideControlsTimer();
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startHideControlsTimer();
    } else {
      _hideControlsTimer?.cancel();
    }
  }

  Future<void> _toggleFullscreen() async {
    try {
      _isFullscreen = !_isFullscreen;
      if (_isFullscreen) {
        await windowManager.setFullScreen(true);
      } else {
        await windowManager.setFullScreen(false);
      }
    } catch (e) {
      print('[LinuxVideoPlayer] Fullscreen toggle error: $e');
    }
  }

  void _handleControlNavigation(bool moveRight) {
    setState(() {
      if (moveRight) {
        _focusedControlIndex = (_focusedControlIndex + 1) % _totalControls;
      } else {
        _focusedControlIndex = (_focusedControlIndex - 1 + _totalControls) % _totalControls;
      }
    });
    _resetHideControlsTimer();
  }

  void _executeControlAction() {
    switch (_focusedControlIndex) {
      case 0:
        _seekBackward();
        break;
      case 1:
        _togglePlayPause();
        break;
      case 2:
        _seekForward();
        break;
      case 3:
        _toggleAudioMenu();
        break;
      case 4:
        _toggleSubtitleMenu();
        break;
      case 5:
        _toggleServerMenu();
        break;
    }
    _resetHideControlsTimer();
  }

  Future<void> _loadAudioTracks() async {
    setState(() => _isLoadingTracks = true);
    
    try {
      // Wait a bit for tracks to be available
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        final tracks = player.state.tracks.audio;
        setState(() {
          _audioTracks = tracks;
          _isLoadingTracks = false;
          if (tracks.isNotEmpty) {
            print('[LinuxVideoPlayer] Found ${tracks.length} audio tracks');
          }
        });
      }
    } catch (e) {
      print('[LinuxVideoPlayer] Error loading audio tracks: $e');
      if (mounted) {
        setState(() {
          _audioTracks = [];
          _isLoadingTracks = false;
        });
      }
    }
  }

  void _toggleAudioMenu() {
    if (!_showAudioMenu) {
      // Opening menu
      _hideControlsTimer?.cancel();
      setState(() {
        _showAudioMenu = true;
        _focusedAudioTrackIndex = _selectedAudioIndex;
        
        // Reload tracks if empty
        if (_audioTracks.isEmpty && !_isLoadingTracks) {
          _loadAudioTracks();
        }
      });
      
      // Scroll to selected item after menu opens
      if (_audioTracks.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_audioScrollController.hasClients) {
            final itemHeight = 56.0;
            final targetOffset = _selectedAudioIndex * itemHeight;
            _audioScrollController.animateTo(
              targetOffset,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } else {
      // Closing menu
      setState(() {
        _showAudioMenu = false;
      });
      _startHideControlsTimer();
    }
  }

  void _navigateAudioTracks(int delta) {
    if (_audioTracks.isEmpty) return;
    setState(() {
      _focusedAudioTrackIndex = (_focusedAudioTrackIndex + delta).clamp(0, _audioTracks.length - 1);
    });
    
    // Auto-scroll to focused item
    if (_audioScrollController.hasClients) {
      final itemHeight = 56.0;
      final targetOffset = _focusedAudioTrackIndex * itemHeight;
      _audioScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _selectAudioTrack() async {
    if (_audioTracks.isEmpty) return;
    
    final track = _audioTracks[_focusedAudioTrackIndex];
    
    try {
      await player.setAudioTrack(track);
      setState(() {
        _selectedAudioIndex = _focusedAudioTrackIndex;
        _showAudioMenu = false;
      });
      
      final trackLabel = track.title ?? track.language ?? 'Track ${_focusedAudioTrackIndex + 1}';
      print('[LinuxVideoPlayer] Selected audio track: $trackLabel');
      
      if (mounted) {
        _showSnackBar('Audio: $trackLabel');
      }
    } catch (e) {
      print('[LinuxVideoPlayer] Error selecting audio track: $e');
      _showSnackBar('Failed to switch audio track');
    }
  }

  void _toggleServerMenu() {
    if (widget.streams == null || widget.streams!.isEmpty) {
      _showSnackBar('No servers available');
      return;
    }

    if (!_showServerMenu) {
      // Opening menu
      _hideControlsTimer?.cancel();
      setState(() {
        _showServerMenu = true;
        _focusedServerIndex = widget.currentStreamIndex ?? 0;
      });
      
      // Scroll to selected item after menu opens
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_serverScrollController.hasClients && widget.streams!.isNotEmpty) {
          final itemHeight = 56.0;
          final targetOffset = _focusedServerIndex * itemHeight;
          _serverScrollController.animateTo(
            targetOffset,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } else {
      // Closing menu
      setState(() {
        _showServerMenu = false;
      });
      _startHideControlsTimer();
    }
  }

  void _navigateServers(int delta) {
    if (widget.streams == null || widget.streams!.isEmpty) return;
    setState(() {
      _focusedServerIndex = (_focusedServerIndex + delta).clamp(0, widget.streams!.length - 1);
    });
    
    // Auto-scroll to focused item
    if (_serverScrollController.hasClients) {
      final itemHeight = 56.0;
      final targetOffset = _focusedServerIndex * itemHeight;
      _serverScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _selectServer() async {
    if (widget.streams == null || widget.streams!.isEmpty) return;
    
    final stream = widget.streams![_focusedServerIndex];
    
    try {
      await _switchStream(stream, _focusedServerIndex);
      setState(() {
        _showServerMenu = false;
      });
    } catch (e) {
      print('[LinuxVideoPlayer] Error switching server: $e');
      _showSnackBar('Failed to switch server');
    }
  }

  void _toggleSubtitleMenu() {
    if (!_showSubtitleMenu) {
      // Opening menu
      _hideControlsTimer?.cancel();
      setState(() {
        _showSubtitleMenu = true;
        _focusedSubtitleTrackIndex = _selectedSubtitleIndex >= 0 ? _selectedSubtitleIndex : 0;
      });
      
      // Scroll to selected item after menu opens
      if (_subtitleTracks.isNotEmpty && _selectedSubtitleIndex >= 0) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_subtitleScrollController.hasClients) {
            final itemHeight = 56.0;
            final targetOffset = (_selectedSubtitleIndex + 1) * itemHeight; // +1 for "Add Subtitle" option
            _subtitleScrollController.animateTo(
              targetOffset,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } else {
      // Closing menu
      setState(() {
        _showSubtitleMenu = false;
      });
      _startHideControlsTimer();
    }
  }

  void _navigateSubtitleTracks(int delta) {
    // Total items: "Search Online" + "Add Subtitle" + subtitle tracks + "No Subtitle"
    final totalItems = _subtitleTracks.length + 3;
    setState(() {
      _focusedSubtitleTrackIndex = (_focusedSubtitleTrackIndex + delta).clamp(0, totalItems - 1);
    });
    
    // Auto-scroll to focused item
    if (_subtitleScrollController.hasClients) {
      final itemHeight = 56.0;
      final targetOffset = _focusedSubtitleTrackIndex * itemHeight;
      _subtitleScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _selectSubtitleTrack() async {
    // Index 0: Search Online
    if (_focusedSubtitleTrackIndex == 0) {
      await _searchSubtitlesOnline();
      return;
    }

    // Index 1: Add Subtitle button
    if (_focusedSubtitleTrackIndex == 1) {
      await _addSubtitleFile();
      return;
    }
    
    // Last index: No Subtitle option
    final totalItems = _subtitleTracks.length + 3;
    if (_focusedSubtitleTrackIndex == totalItems - 1) {
      await _removeSubtitle();
      return;
    }
    
    // Subtitle track selection (adjust index by -2 for Search/Add buttons)
    if (_subtitleTracks.isEmpty) return;
    
    final trackIndex = _focusedSubtitleTrackIndex - 2;
    if (trackIndex < 0 || trackIndex >= _subtitleTracks.length) return;
    
    final track = _subtitleTracks[trackIndex];
    
    try {
      await player.setSubtitleTrack(track);
      setState(() {
        _selectedSubtitleIndex = trackIndex;
        _showSubtitleMenu = false;
      });
      
      final trackLabel = track.title ?? track.language ?? 'Track ${trackIndex + 1}';
      print('[LinuxVideoPlayer] Selected subtitle track: $trackLabel');
      
      if (mounted) {
        _showSnackBar('Subtitle: $trackLabel');
      }
    } catch (e) {
      print('[LinuxVideoPlayer] Error selecting subtitle track: $e');
      _showSnackBar('Failed to switch subtitle track');
    }
  }

  Future<void> _searchSubtitlesOnline() async {
    setState(() => _showSubtitleMenu = false);
    
    final result = await showDialog<OpenSubtitleResult>(
      context: context,
      builder: (context) => const SubtitleSearchDialog(),
    );

    if (result != null && result.subDownloadLink.isNotEmpty) {
      try {
        String url = result.subDownloadLink;
        if (url.endsWith('.gz')) {
          url = url.substring(0, url.length - 3);
        }
        
        print('[LinuxVideoPlayer] Adding online subtitle: $url');
        await player.setSubtitleTrack(SubtitleTrack.uri(url));
        
        setState(() {
          _selectedSubtitleIndex = _subtitleTracks.length; // Will be the new track
        });
        
        if (mounted) {
          _showSnackBar('Added: ${result.movieName} [${result.subLanguageId}]');
        }
        
        // Refresh tracks
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            final tracks = player.state.tracks.subtitle;
            setState(() {
              _subtitleTracks = tracks;
            });
          }
        });
      } catch (e) {
        print('[LinuxVideoPlayer] Error adding online subtitle: $e');
        if (mounted) {
          _showSnackBar('Failed to load subtitle');
        }
      }
    }
  }

  Future<void> _addSubtitleFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['srt', 'vtt', 'ass', 'ssa'],
        dialogTitle: 'Select Subtitle File',
      );
      
      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        print('[LinuxVideoPlayer] Adding subtitle file: $filePath');
        
        // Add subtitle track to player
        await player.setSubtitleTrack(
          SubtitleTrack.uri(filePath),
        );
        
        setState(() {
          _selectedSubtitleIndex = _subtitleTracks.length; // New track will be added
          _showSubtitleMenu = false;
        });
        
        if (mounted) {
          _showSnackBar('Subtitle added: ${result.files.single.name}');
        }
        
        // Refresh subtitle tracks
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            final tracks = player.state.tracks.subtitle;
            setState(() {
              _subtitleTracks = tracks;
              print('[LinuxVideoPlayer] Updated subtitle tracks: ${tracks.length}');
            });
          }
        });
      }
    } catch (e) {
      print('[LinuxVideoPlayer] Error adding subtitle: $e');
      if (mounted) {
        _showSnackBar('Failed to add subtitle file');
      }
    }
  }

  Future<void> _removeSubtitle() async {
    try {
      await player.setSubtitleTrack(SubtitleTrack.no());
      setState(() {
        _selectedSubtitleIndex = -1;
        _showSubtitleMenu = false;
      });
      
      if (mounted) {
        _showSnackBar('Subtitle disabled');
      }
    } catch (e) {
      print('[LinuxVideoPlayer] Error removing subtitle: $e');
      _showSnackBar('Failed to remove subtitle');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorDialog();
    }

    return KeyEventHandler(
      onUpKey: () {
        if (_showAudioMenu) {
          _navigateAudioTracks(-1);
        } else if (_showServerMenu) {
          _navigateServers(-1);
        } else if (_showSubtitleMenu) {
          _navigateSubtitleTracks(-1);
        } else {
          _toggleControls();
        }
        _resetHideControlsTimer();
      },
      onDownKey: () {
        if (_showAudioMenu) {
          _navigateAudioTracks(1);
        } else if (_showServerMenu) {
          _navigateServers(1);
        } else if (_showSubtitleMenu) {
          _navigateSubtitleTracks(1);
        } else {
          _toggleControls();
        }
        _resetHideControlsTimer();
      },
      onLeftKey: () {
        if (_showAudioMenu || _showServerMenu || _showSubtitleMenu) return;
        _handleControlNavigation(false);
      },
      onRightKey: () {
        if (_showAudioMenu || _showServerMenu || _showSubtitleMenu) return;
        _handleControlNavigation(true);
      },
      onBackKey: () {
        if (_showAudioMenu) {
          setState(() => _showAudioMenu = false);
          _startHideControlsTimer();
        } else if (_showServerMenu) {
          setState(() => _showServerMenu = false);
          _startHideControlsTimer();
        } else if (_showSubtitleMenu) {
          setState(() => _showSubtitleMenu = false);
          _startHideControlsTimer();
        } else {
          Navigator.of(context).pop();
        }
      },
      onEnterKey: () {
        if (_showAudioMenu) {
          _selectAudioTrack();
        } else if (_showServerMenu) {
          _selectServer();
        } else if (_showSubtitleMenu) {
          _selectSubtitleTrack();
        } else {
          _executeControlAction();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Video display with double-click to fullscreen
            GestureDetector(
              onDoubleTap: _toggleFullscreen,
              onTap: _toggleControls,
              child: Container(
                color: Colors.black,
                child: Center(
                  child: Video(
                    controller: controller,
                    controls: NoVideoControls,
                  ),
                ),
              ),
            ),

            // Loading indicator
            if (_isBuffering || !_isPlayerReady)
              Container(
                color: Colors.black.withOpacity(0.7),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.primary,
                        strokeWidth: 4,
                        strokeCap: StrokeCap.round,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isPlayerReady ? 'Buffering...' : 'Loading video...',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Custom controls overlay
            if (_showControls && !_showAudioMenu && !_showServerMenu && !_showSubtitleMenu)
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withOpacity(0.85),
                      ],
                      stops: const [0.0, 0.15, 0.7, 1.0],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top bar with title
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                          child: Row(
                            children: [
                              InkWell(
                                onTap: () => Navigator.of(context).pop(),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: const Icon(
                                    Icons.arrow_back_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.title,
                                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        shadows: [
                                          Shadow(
                                            blurRadius: 8,
                                            color: Colors.black.withOpacity(0.5),
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (_currentServerName.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          _currentServerName.toUpperCase(),
                                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                            color: Colors.white.withOpacity(0.9),
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Bottom controls
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(48, 0, 48, 48),
                          child: Column(
                            children: [
                              // Progress bar
                              Row(
                                children: [
                                  Text(
                                    _formatDuration(_currentPosition),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w500,
                                      fontFeatures: [FontFeature.tabularFigures()],
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        trackHeight: 2,
                                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                                        activeTrackColor: Colors.white,
                                        inactiveTrackColor: Colors.white24,
                                        thumbColor: Colors.white,
                                        overlayColor: Colors.white.withOpacity(0.1),
                                        trackShape: const RectangularSliderTrackShape(),
                                      ),
                                      child: Slider(
                                        value: _totalDuration.inMilliseconds > 0
                                            ? _currentPosition.inMilliseconds.toDouble().clamp(0.0, _totalDuration.inMilliseconds.toDouble())
                                            : 0.0,
                                        min: 0.0,
                                        max: _totalDuration.inMilliseconds > 0 
                                            ? _totalDuration.inMilliseconds.toDouble() 
                                            : 1.0,
                                        onChanged: (value) {
                                          _seekToPosition(value / (_totalDuration.inMilliseconds > 0 ? _totalDuration.inMilliseconds : 1));
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Text(
                                    _formatDuration(_totalDuration),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w500,
                                      fontFeatures: [FontFeature.tabularFigures()],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),

                              // Control buttons
                              SizedBox(
                                width: double.infinity,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Center: Playback Controls
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _buildControlButton(
                                          icon: Icons.replay_10_rounded,
                                          label: 'Back 10s',
                                          isSelected: _focusedControlIndex == 0,
                                          onTap: _seekBackward,
                                        ),
                                        const SizedBox(width: 32),
                                        _buildControlButton(
                                          icon: _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                          label: _isPlaying ? 'Pause' : 'Play',
                                          isSelected: _focusedControlIndex == 1,
                                          onTap: _togglePlayPause,
                                          isPrimary: true,
                                        ),
                                        const SizedBox(width: 32),
                                        _buildControlButton(
                                          icon: Icons.forward_10_rounded,
                                          label: 'Forward 10s',
                                          isSelected: _focusedControlIndex == 2,
                                          onTap: _seekForward,
                                        ),
                                      ],
                                    ),

                                    // Left: Servers
                                    Positioned(
                                      left: 0,
                                      child: _buildControlButton(
                                        icon: Icons.dns_rounded,
                                        label: 'Servers',
                                        isSelected: _focusedControlIndex == 5,
                                        onTap: _toggleServerMenu,
                                      ),
                                    ),

                                    // Right: Audio & Subtitles
                                    Positioned(
                                      right: 0,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _buildControlButton(
                                            icon: Icons.audiotrack_rounded,
                                            label: 'Audio',
                                            isSelected: _focusedControlIndex == 3,
                                            onTap: _toggleAudioMenu,
                                          ),
                                          const SizedBox(width: 24),
                                          _buildControlButton(
                                            icon: Icons.subtitles_rounded,
                                            label: 'Subtitles',
                                            isSelected: _focusedControlIndex == 4,
                                            onTap: _toggleSubtitleMenu,
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
                    ],
                  ),
                ),
              ),
            
            // Server Selection Menu
            if (_showServerMenu)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
                    child: Card(
                      margin: const EdgeInsets.all(24),
                      elevation: 0,
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.dns_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 24,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Select Server',
                                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '${widget.streams?.length ?? 0} servers available',
                                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                          color: Theme.of(context).colorScheme.secondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => setState(() => _showServerMenu = false),
                                  icon: const Icon(Icons.close_rounded),
                                ),
                              ],
                            ),
                            const Divider(height: 32),
                            if (widget.streams == null || widget.streams!.isEmpty)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32.0),
                                  child: Text('No servers available'),
                                ),
                              )
                            else
                              Flexible(
                                child: ListView.builder(
                                  controller: _serverScrollController,
                                  shrinkWrap: true,
                                  itemCount: widget.streams!.length,
                                  itemBuilder: (context, index) {
                                    final stream = widget.streams![index];
                                    final isSelected = index == _focusedServerIndex;
                                    final isCurrent = index == (widget.currentStreamIndex ?? 0);
                                    final colorScheme = Theme.of(context).colorScheme;
                                    
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 4),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        color: isSelected ? colorScheme.secondaryContainer : Colors.transparent,
                                        border: isSelected 
                                            ? Border.all(color: colorScheme.primary.withOpacity(0.3)) 
                                            : null,
                                      ),
                                      child: ListTile(
                                        dense: true,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                        onTap: () {
                                          setState(() => _focusedServerIndex = index);
                                          _selectServer();
                                        },
                                        leading: isCurrent
                                            ? Icon(Icons.play_circle_filled_rounded, color: colorScheme.primary)
                                            : Icon(Icons.circle_outlined, size: 12, color: colorScheme.outline),
                                        title: Text(
                                          stream.server,
                                          style: TextStyle(
                                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                            color: isSelected ? colorScheme.onSecondaryContainer : colorScheme.onSurface,
                                          ),
                                        ),
                                        subtitle: stream.type.isNotEmpty 
                                            ? Text(stream.type.toUpperCase())
                                            : null,
                                        trailing: isSelected 
                                            ? Icon(Icons.keyboard_return, size: 16, color: colorScheme.onSecondaryContainer)
                                            : null,
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            
            // Subtitle Menu
            if (_showSubtitleMenu)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
                    child: Card(
                      margin: const EdgeInsets.all(24),
                      elevation: 0,
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.closed_caption_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 24,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    'Subtitles',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (_isLoadingSubtitles)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 16),
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  ),
                                IconButton(
                                  onPressed: () => setState(() => _showSubtitleMenu = false),
                                  icon: const Icon(Icons.close_rounded),
                                ),
                              ],
                            ),
                            const Divider(height: 32),
                            Flexible(
                              child: ListView.builder(
                                controller: _subtitleScrollController,
                                shrinkWrap: true,
                                itemCount: _subtitleTracks.length + 3,
                                itemBuilder: (context, index) {
                                  final isFocused = index == _focusedSubtitleTrackIndex;
                                  final colorScheme = Theme.of(context).colorScheme;
                                  
                                  Widget? leadingIcon;
                                  String label = '';
                                  VoidCallback? onTap;
                                  bool isActive = false;

                                  if (index == 0) {
                                    leadingIcon = const Icon(Icons.search_rounded);
                                    label = 'Search Subtitles Online';
                                    onTap = _searchSubtitlesOnline;
                                  } else if (index == 1) {
                                    leadingIcon = const Icon(Icons.add_rounded);
                                    label = 'Add Subtitle File';
                                    onTap = _addSubtitleFile;
                                  } else if (index == _subtitleTracks.length + 2) {
                                    leadingIcon = const Icon(Icons.not_interested_rounded);
                                    label = 'No Subtitle';
                                    onTap = _removeSubtitle;
                                    isActive = _selectedSubtitleIndex == -1;
                                  } else {
                                    final trackIndex = index - 2;
                                    final track = _subtitleTracks[trackIndex];
                                    label = track.title ?? track.language ?? 'Track ${trackIndex + 1}';
                                    if (track.language != null) label += ' [${track.language!.toUpperCase()}]';
                                    onTap = () {
                                      setState(() => _focusedSubtitleTrackIndex = index);
                                      _selectSubtitleTrack();
                                    };
                                    isActive = trackIndex == _selectedSubtitleIndex;
                                  }

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 4),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: isFocused ? colorScheme.secondaryContainer : Colors.transparent,
                                    ),
                                    child: ListTile(
                                      dense: true,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                      onTap: onTap,
                                      leading: isActive 
                                          ? Icon(Icons.check_circle_rounded, color: colorScheme.primary)
                                          : (leadingIcon ?? const Icon(Icons.subtitles, size: 20)),
                                      title: Text(
                                        label,
                                        style: TextStyle(
                                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                          color: isFocused ? colorScheme.onSecondaryContainer : colorScheme.onSurface,
                                        ),
                                      ),
                                      trailing: isFocused 
                                          ? Icon(Icons.keyboard_return, size: 16, color: colorScheme.onSecondaryContainer)
                                          : null,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            
            // Audio Track Menu
            if (_showAudioMenu)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
                    child: Card(
                      margin: const EdgeInsets.all(24),
                      elevation: 0,
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.audiotrack_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 24,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    'Audio Tracks',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (_isLoadingTracks)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 16),
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  ),
                                IconButton(
                                  onPressed: () => setState(() => _showAudioMenu = false),
                                  icon: const Icon(Icons.close_rounded),
                                ),
                              ],
                            ),
                            const Divider(height: 32),
                            if (_audioTracks.isEmpty && !_isLoadingTracks)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32.0),
                                  child: Text('No audio tracks available'),
                                ),
                              )
                            else
                              Flexible(
                                child: ListView.builder(
                                  controller: _audioScrollController,
                                  shrinkWrap: true,
                                  itemCount: _audioTracks.length,
                                  itemBuilder: (context, index) {
                                    final track = _audioTracks[index];
                                    final isFocused = index == _focusedAudioTrackIndex;
                                    final isSelected = index == _selectedAudioIndex;
                                    final colorScheme = Theme.of(context).colorScheme;
                                    
                                    String label = track.title ?? track.language ?? 'Track ${index + 1}';
                                    if (track.language != null) label += ' [${track.language!.toUpperCase()}]';

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 4),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        color: isFocused ? colorScheme.secondaryContainer : Colors.transparent,
                                      ),
                                      child: ListTile(
                                        dense: true,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                        onTap: () {
                                          setState(() => _focusedAudioTrackIndex = index);
                                          _selectAudioTrack();
                                        },
                                        leading: isSelected
                                            ? Icon(Icons.check_circle_rounded, color: colorScheme.primary)
                                            : const Icon(Icons.music_note_rounded, size: 20),
                                        title: Text(
                                          label,
                                          style: TextStyle(
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                            color: isFocused ? colorScheme.onSecondaryContainer : colorScheme.onSurface,
                                          ),
                                        ),
                                        trailing: isFocused 
                                            ? Icon(Icons.keyboard_return, size: 16, color: colorScheme.onSecondaryContainer)
                                            : null,
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.all(isPrimary ? 20 : 16),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            shape: BoxShape.circle,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.25),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ]
                : [],
          ),
          child: Icon(
            icon,
            color: isSelected ? Colors.black : Colors.white.withOpacity(isPrimary ? 1.0 : 0.8),
            size: isPrimary ? 42 : 26,
            shadows: isSelected ? [] : [
               Shadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorDialog() {
    return KeyEventHandler(
      onLeftKey: () {
        setState(() => _focusedButtonIndex = 0);
      },
      onRightKey: () {
        setState(() => _focusedButtonIndex = 1);
      },
      onBackKey: () => Navigator.of(context).pop(),
      onEnterKey: () {
        if (_focusedButtonIndex == 0) {
          Navigator.of(context).pop();
        } else if (_focusedButtonIndex == 1) {
          _playNextStream();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainer,
            margin: const EdgeInsets.all(40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(
                color: Theme.of(context).colorScheme.error.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: Theme.of(context).colorScheme.error,
                    size: 48,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Playback Error',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage.isEmpty
                        ? 'Failed to play the video'
                        : _errorMessage,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Note: Some providers may require specific headers or cookies\nthat are not fully supported by this player.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.secondary,
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildErrorButton(
                        label: 'Go Back',
                        icon: Icons.arrow_back_rounded,
                        isSelected: _focusedButtonIndex == 0,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 16),
                      if (widget.streams != null && 
                          widget.currentStreamIndex != null &&
                          widget.currentStreamIndex! < (widget.streams!.length - 1))
                        _buildErrorButton(
                          label: 'Try Next',
                          icon: Icons.skip_next_rounded,
                          isSelected: _focusedButtonIndex == 1,
                          onTap: _playNextStream,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return FilledButton.icon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: isSelected 
            ? colorScheme.error 
            : colorScheme.surfaceContainerHighest,
        foregroundColor: isSelected 
            ? colorScheme.onError 
            : colorScheme.onSurfaceVariant,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        side: isSelected 
            ? BorderSide(color: colorScheme.onError.withOpacity(0.5), width: 2)
            : BorderSide.none,
      ),
      icon: Icon(icon, size: 20),
      label: Text(label),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
}

class SubtitleSearchDialog extends StatefulWidget {
  const SubtitleSearchDialog({super.key});

  @override
  State<SubtitleSearchDialog> createState() => _SubtitleSearchDialogState();
}

class _SubtitleSearchDialogState extends State<SubtitleSearchDialog> {
  final TextEditingController _queryController = TextEditingController();
  final TextEditingController _seasonController = TextEditingController();
  final TextEditingController _episodeController = TextEditingController();
  
  String _selectedLanguageId = 'eng';
  List<OpenSubtitleResult> _searchResults = [];
  bool _isLoading = false;
  String _error = '';

  final List<Map<String, String>> _languages = [
    {'name': 'English', 'id': 'eng'},
    {'name': 'Spanish', 'id': 'spa'},
    {'name': 'French', 'id': 'fre'},
    {'name': 'German', 'id': 'ger'},
    {'name': 'Italian', 'id': 'ita'},
    {'name': 'Portuguese', 'id': 'por'},
    {'name': 'Russian', 'id': 'rus'},
    {'name': 'Chinese', 'id': 'chi'},
    {'name': 'Japanese', 'id': 'jpn'},
    {'name': 'Korean', 'id': 'kor'},
    {'name': 'Arabic', 'id': 'ara'},
    {'name': 'Hindi', 'id': 'hin'},
    {'name': 'Dutch', 'id': 'dut'},
    {'name': 'Swedish', 'id': 'swe'},
    {'name': 'Polish', 'id': 'pol'},
    {'name': 'Turkish', 'id': 'tur'},
    {'name': 'Danish', 'id': 'dan'},
    {'name': 'Norwegian', 'id': 'nor'},
    {'name': 'Finnish', 'id': 'fin'},
    {'name': 'Vietnamese', 'id': 'vie'},
    {'name': 'Indonesian', 'id': 'ind'},
  ];

  @override
  void dispose() {
    _queryController.dispose();
    _seasonController.dispose();
    _episodeController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _isLoading = true;
      _error = '';
      _searchResults = [];
    });

    try {
      final results = await SubtitleService.search(
        query: _queryController.text,
        season: _seasonController.text,
        episode: _episodeController.text,
        languageId: _selectedLanguageId,
      );

      if (mounted) {
        setState(() {
          _searchResults = results;
          if (results.isEmpty) {
            _error = 'No results found';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Dialog(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                   Icon(Icons.search_rounded, color: colorScheme.primary),
                   const SizedBox(width: 16),
                   Text(
                     'Search Subtitles',
                     style: Theme.of(context).textTheme.headlineSmall,
                   ),
                   const Spacer(),
                   IconButton(
                     onPressed: () => Navigator.of(context).pop(),
                     icon: const Icon(Icons.close_rounded),
                   ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Inputs
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _queryController,
                      decoration: const InputDecoration(
                        labelText: 'Name or IMDB ID',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                      onSubmitted: (_) => _search(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _selectedLanguageId,
                      decoration: const InputDecoration(
                        labelText: 'Language',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                      menuMaxHeight: 400,
                      items: _languages.map((lang) {
                        return DropdownMenuItem(
                          value: lang['id'],
                          child: Text(lang['name']!, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _selectedLanguageId = value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _seasonController,
                      decoration: const InputDecoration(
                        labelText: 'Season',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                      keyboardType: TextInputType.number,
                      onSubmitted: (_) => _search(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _episodeController,
                      decoration: const InputDecoration(
                        labelText: 'Episode',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                      keyboardType: TextInputType.number,
                      onSubmitted: (_) => _search(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _search,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: _isLoading 
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.search_rounded),
                    label: const Text('Search'),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              const Divider(),
              
              // Results
              Expanded(
                child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline_rounded, color: colorScheme.error, size: 48),
                            const SizedBox(height: 16),
                            Text(_error, style: TextStyle(color: colorScheme.error)),
                          ],
                        ),
                      )
                    : _searchResults.isEmpty
                      ? Center(
                          child: Text(
                            'Enter details to search',
                            style: TextStyle(color: colorScheme.onSurfaceVariant),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _searchResults.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final result = _searchResults[index];
                            final seasonText = (int.tryParse(result.seriesSeason) ?? 0) > 0 ? 'S${result.seriesSeason}' : '';
                            final episodeText = (int.tryParse(result.seriesEpisode) ?? 0) > 0 ? 'E${result.seriesEpisode}' : '';
                            final seInfo = [seasonText, episodeText].where((t) => t.isNotEmpty).join(' ');
                            
                            return ListTile(
                              title: Text(result.movieName, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text('${result.infoReleaseGroup} • ${result.userNickName}', maxLines: 1),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (seInfo.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      margin: const EdgeInsets.only(bottom: 4),
                                      decoration: BoxDecoration(
                                        color: colorScheme.secondary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        seInfo,
                                        style: TextStyle(color: colorScheme.secondary, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  const Icon(Icons.download_rounded, size: 20),
                                ],
                              ),
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor: colorScheme.primaryContainer,
                                child: Text(
                                  result.iso639.toUpperCase(),
                                  style: TextStyle(color: colorScheme.onPrimaryContainer, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                              onTap: () => Navigator.of(context).pop(result),
                            );
                          },
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
 
