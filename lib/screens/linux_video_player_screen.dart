import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';
import 'package:url_launcher/url_launcher.dart';
import '../provider/extractors/stream_types.dart' as stream_types;
import '../utils/key_event_handler.dart';

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
  
  // Focus management
  int _focusedButtonIndex = 0;
  int _focusedControlIndex = 1; // 0=backward, 1=play/pause, 2=forward, 3=audio
  final int _totalControls = 4;
  
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
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Colors.orange.shade900.withOpacity(0.5),
            width: 2,
          ),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade400, size: 32),
            const SizedBox(width: 12),
            const Text(
              'Desktop Limitation',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This stream from NF provider may not play properly on desktop due to technical limitations with authentication headers.',
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade900.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.green.shade700.withOpacity(0.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade400, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Works perfectly on Android',
                      style: TextStyle(
                        color: Colors.green.shade300,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Continue Anyway',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final url = Uri.parse('https://screenscape.fun');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Download Android App'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
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
            if (_audioTracks.isNotEmpty && !_isLoadingTracks) {
              print('[LinuxVideoPlayer] Loaded ${_audioTracks.length} audio tracks');
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

  Future<void> _playPreviousStream() async {
    if (widget.streams == null || widget.currentStreamIndex == null) return;
    
    final previousIndex = widget.currentStreamIndex! - 1;
    if (previousIndex < 0) return;
    
    final previousStream = widget.streams![previousIndex];
    await _switchStream(previousStream, previousIndex);
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
      if (mounted && _showControls && !_showAudioMenu) {
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

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorDialog();
    }

    return KeyEventHandler(
      onUpKey: () {
        if (_showAudioMenu) {
          _navigateAudioTracks(-1);
        } else {
          _toggleControls();
        }
      },
      onDownKey: () {
        if (_showAudioMenu) {
          _navigateAudioTracks(1);
        } else {
          _toggleControls();
        }
      },
      onLeftKey: () {
        if (_showAudioMenu) return;
        _handleControlNavigation(false);
      },
      onRightKey: () {
        if (_showAudioMenu) return;
        _handleControlNavigation(true);
      },
      onBackKey: () {
        if (_showAudioMenu) {
          setState(() => _showAudioMenu = false);
        } else {
          Navigator.of(context).pop();
        }
      },
      onEnterKey: () {
        if (_showAudioMenu) {
          _selectAudioTrack();
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
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isPlayerReady ? 'Buffering...' : 'Loading video...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Custom controls overlay
            if (_showControls && !_showAudioMenu)
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
                        Colors.black.withOpacity(0.7),
                      ],
                      stops: const [0.0, 0.2, 0.8, 1.0],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top bar with title
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Icon(
                                Icons.live_tv_rounded,
                                color: Colors.red.shade400,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      _currentServerName,
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 14,
                                      ),
                                    ),
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
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              // Progress bar
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Row(
                                  children: [
                                    Text(
                                      _formatDuration(_currentPosition),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: GestureDetector(
                                        onTapDown: (details) {
                                          final box = context.findRenderObject() as RenderBox?;
                                          if (box != null) {
                                            final localPosition = box.globalToLocal(details.globalPosition);
                                            final progressBarWidth = box.size.width - 40; // Account for padding
                                            final relativePosition = (localPosition.dx - 10) / progressBarWidth;
                                            _seekToPosition(relativePosition.clamp(0.0, 1.0));
                                          }
                                        },
                                        child: Container(
                                          height: 20,
                                          alignment: Alignment.center,
                                          child: LinearProgressIndicator(
                                            value: _totalDuration.inMilliseconds > 0
                                                ? _currentPosition.inMilliseconds / 
                                                  _totalDuration.inMilliseconds
                                                : 0.0,
                                            backgroundColor: Colors.grey[800],
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              Colors.red.shade600,
                                            ),
                                            minHeight: 4,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      _formatDuration(_totalDuration),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Control buttons
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildControlButton(
                                    icon: Icons.replay_10,
                                    label: 'Back 10s',
                                    isSelected: _focusedControlIndex == 0,
                                    onTap: _seekBackward,
                                  ),
                                  const SizedBox(width: 30),
                                  _buildControlButton(
                                    icon: _isPlaying ? Icons.pause : Icons.play_arrow,
                                    label: _isPlaying ? 'Pause' : 'Play',
                                    isSelected: _focusedControlIndex == 1,
                                    onTap: _togglePlayPause,
                                    isPrimary: true,
                                  ),
                                  const SizedBox(width: 30),
                                  _buildControlButton(
                                    icon: Icons.forward_10,
                                    label: 'Forward 10s',
                                    isSelected: _focusedControlIndex == 2,
                                    onTap: _seekForward,
                                  ),
                                  const SizedBox(width: 30),
                                  _buildControlButton(
                                    icon: Icons.audiotrack,
                                    label: 'Audio',
                                    isSelected: _focusedControlIndex == 3,
                                    onTap: _toggleAudioMenu,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Audio Track Menu
            if (_showAudioMenu)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.9),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 420, maxHeight: 400),
                      margin: const EdgeInsets.all(24),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 24,
                            spreadRadius: 4,
                          )
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.audiotrack, color: Colors.orange, size: 24),
                              ),
                              const SizedBox(width: 16),
                              const Text(
                                'Audio Tracks',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              if (_isLoadingTracks)
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          
                          if (_audioTracks.isEmpty && !_isLoadingTracks)
                            const Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Text(
                                'No audio tracks available',
                                style: TextStyle(color: Colors.white54),
                                textAlign: TextAlign.center,
                              ),
                            )
                          else
                            Flexible(
                              child: ListView.separated(
                                controller: _audioScrollController,
                                shrinkWrap: true,
                                itemCount: _audioTracks.length,
                                separatorBuilder: (context, index) => const Divider(
                                  color: Colors.white12,
                                  height: 1,
                                ),
                                itemBuilder: (context, index) {
                                  final track = _audioTracks[index];
                                  final isFocused = index == _focusedAudioTrackIndex;
                                  final isSelected = index == _selectedAudioIndex;
                                  final trackLabel = track.title ?? track.language ?? 'Track ${index + 1}';
                                  
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() => _focusedAudioTrackIndex = index);
                                      _selectAudioTrack();
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isFocused
                                            ? Colors.orange.withOpacity(0.2)
                                            : Colors.transparent,
                                        border: Border.all(
                                          color: isFocused
                                              ? Colors.orange
                                              : Colors.transparent,
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isSelected
                                                ? Icons.check_circle
                                                : Icons.radio_button_unchecked,
                                            color: isSelected
                                                ? Colors.orange
                                                : Colors.white38,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  trackLabel,
                                                  style: TextStyle(
                                                    color: isFocused
                                                        ? Colors.white
                                                        : Colors.white70,
                                                    fontSize: 14,
                                                    fontWeight: isFocused
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                  ),
                                                ),
                                                if (track.language != null &&
                                                    track.language!.isNotEmpty)
                                                  Text(
                                                    track.language!.toUpperCase(),
                                                    style: const TextStyle(
                                                      color: Colors.white38,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(isPrimary ? 16 : 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.red.shade600
              : Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.grey[700]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.red.shade600.withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: isPrimary ? 40 : 32,
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
          child: Container(
            margin: const EdgeInsets.all(40),
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.red.shade900.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.red.shade400,
                  size: 60,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Playback Error',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _errorMessage.isEmpty
                      ? 'Failed to play the video'
                      : _errorMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Note: Some providers may require specific headers or cookies\nthat are not fully supported by this player.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildErrorButton(
                      label: 'Go Back',
                      icon: Icons.arrow_back,
                      isSelected: _focusedButtonIndex == 0,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 20),
                    if (widget.streams != null && 
                        widget.currentStreamIndex != null &&
                        widget.currentStreamIndex! < (widget.streams!.length - 1))
                      _buildErrorButton(
                        label: 'Try Next Server',
                        icon: Icons.skip_next,
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
    );
  }

  Widget _buildErrorButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.red.shade600 : Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
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
