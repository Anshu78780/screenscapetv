import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:tha_player/tha_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../provider/extractors/stream_types.dart' as stream_types;
import '../utils/vlc_launcher.dart';
import '../utils/key_event_handler.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;
  final String server;
  final Map<String, String>? headers;
  final List<stream_types.Stream>? streams;
  final int? currentStreamIndex;

  const VideoPlayerScreen({
    super.key,
    required this.videoUrl,
    required this.title,
    required this.server,
    this.headers,
    this.streams,
    this.currentStreamIndex,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  ThaNativePlayerController? _playerController;
  
  bool _hasError = false;
  String _errorMessage = '';
  
  late String _currentVideoUrl;
  late String _currentServerName;
  late Map<String, String>? _currentHeaders;
  
  // Focus management for error dialog buttons
  int _focusedButtonIndex = 0;
  final FocusNode _goBackFocusNode = FocusNode();
  final FocusNode _vlcFocusNode = FocusNode();
  
  // Player controls
  final GlobalKey _playerKey = GlobalKey();
  Timer? _controlsHideTimer;
  bool _showControls = true;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  
  // Audio track selection
  bool _showAudioMenu = false;
  List<ThaAudioTrack> _audioTracks = [];
  int _selectedAudioIndex = 0;
  int _focusedAudioTrackIndex = 0;
  bool _isLoadingTracks = false;
  final ScrollController _audioScrollController = ScrollController();
  
  // Control focus management
  int _focusedControlIndex = 2; // 0=backward, 1=play/pause, 2=forward, 3=audio
  final int _totalControls = 4;

  @override
  void initState() {
    super.initState();
    _currentVideoUrl = widget.videoUrl;
    _currentServerName = widget.server;
    _currentHeaders = widget.headers;
    
    WakelockPlus.enable();
    _initializePlayer();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _playerController?.dispose();
    _goBackFocusNode.dispose();
    _vlcFocusNode.dispose();
    _controlsHideTimer?.cancel();
    _audioScrollController.dispose();
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    try {
      final Map<String, String> requestHeaders = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        ...?_currentHeaders,
      };

      print('[VideoPlayer] Initializing player for: $_currentServerName');

      final mediaSource = ThaMediaSource(
        _currentVideoUrl,
        headers: requestHeaders,
      );

      _playerController = ThaNativePlayerController.single(
        mediaSource,
        autoPlay: true,
      );

      await Future.delayed(const Duration(milliseconds: 300));

      if (mounted && _playerController != null) {
        await _playerController!.play();
        _isPlaying = true;
        
        // Listen to playback state
        _playerController!.playbackState.addListener(_onPlaybackStateChanged);
      }

      setState(() => _hasError = false);
      
      // Load audio tracks after a delay to ensure player is ready
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _loadAudioTracks();
        }
      });
      
      _resetControlsHideTimer();
    } catch (e) {
      print('[VideoPlayer] Initialization error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _focusedButtonIndex = 0;
        });
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _goBackFocusNode.requestFocus();
        });
      }
    }
  }
  
  void _onPlaybackStateChanged() {
    if (_playerController == null) return;
    final state = _playerController!.playbackState.value;
    
    if (mounted) {
      setState(() {
        _currentPosition = state.position;
        _totalDuration = state.duration;
       _isPlaying = state.isPlaying;
      });
    }
  }
  
  void _resetControlsHideTimer() {
    _controlsHideTimer?.cancel();
    if (!_showAudioMenu) {
      setState(() => _showControls = true);
      _controlsHideTimer = Timer(const Duration(seconds: 4), () {
        if (mounted && !_showAudioMenu) {
          setState(() => _showControls = false);
        }
      });
    }
  }
  
  void _togglePlayPause() {
    if (_playerController == null) return;
    
    if (_isPlaying) {
      _playerController!.pause();
    } else {
      _playerController!.play();
    }
    _resetControlsHideTimer();
  }
  
  void _seekForward() {
    if (_playerController == null) return;
    final newPosition = _currentPosition + const Duration(seconds: 10);
    if (newPosition <= _totalDuration) {
      _playerController!.seekTo(newPosition);
    }
    _resetControlsHideTimer();
  }
  
  void _seekBackward() {
    if (_playerController == null) return;
    final newPosition = _currentPosition - const Duration(seconds: 10);
    if (newPosition >= Duration.zero) {
      _playerController!.seekTo(newPosition);
    } else {
      _playerController!.seekTo(Duration.zero);
    }
    _resetControlsHideTimer();
  }
  
  void _navigateControls(int delta) {
    setState(() {
      _focusedControlIndex = (_focusedControlIndex + delta) % _totalControls;
      if (_focusedControlIndex < 0) _focusedControlIndex = _totalControls - 1;
    });
    _resetControlsHideTimer();
  }
  
  void _activateFocusedControl() {
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
  
  void _navigateButtons(int delta) {
    setState(() {
      _focusedButtonIndex = (_focusedButtonIndex + delta).clamp(0, 1);
      if (_focusedButtonIndex == 0) {
        _goBackFocusNode.requestFocus();
      } else {
        _vlcFocusNode.requestFocus();
      }
    });
  }
  
  void _activateFocusedButton() {
    if (_focusedButtonIndex == 0) {
      Navigator.pop(context);
    } else {
      VlcLauncher.launchVlc(_currentVideoUrl, widget.title);
    }
  }
  
  Future<void> _loadAudioTracks() async {
    if (_playerController == null) return;
    
    setState(() => _isLoadingTracks = true);
    
    try {
      // Try up to 3 times with delays
      for (int attempt = 0; attempt < 3; attempt++) {
        final tracks = await _playerController!.getAudioTracks();
        
        if (tracks.isNotEmpty) {
          if (mounted) {
            setState(() {
              _audioTracks = tracks;
              _isLoadingTracks = false;
              _selectedAudioIndex = 0;
            });
            print('[VideoPlayer] Loaded ${tracks.length} audio tracks');
          }
          return;
        }
        
        // Wait before retry
        if (attempt < 2) {
          await Future.delayed(Duration(seconds: 1 + attempt));
        }
      }
      
      // No tracks found after retries
      if (mounted) {
        setState(() {
          _audioTracks = [];
          _isLoadingTracks = false;
        });
        print('[VideoPlayer] No audio tracks found after retries');
      }
    } catch (e) {
      print('[VideoPlayer] Error loading audio tracks: $e');
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
        _controlsHideTimer?.cancel();
        
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
        _resetControlsHideTimer();
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
      final itemHeight = 56.0; // Approximate height of each track item
      final targetOffset = _focusedAudioTrackIndex * itemHeight;
      _audioScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }
  
  Future<void> _selectAudioTrack() async {
    if (_audioTracks.isEmpty || _playerController == null) return;
    
    final track = _audioTracks[_focusedAudioTrackIndex];
    
    try {
      await _playerController!.selectAudioTrack(track.id);
      setState(() {
        _selectedAudioIndex = _focusedAudioTrackIndex;
        _showAudioMenu = false;
      });
      print('[VideoPlayer] Selected audio track: ${track.label}');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Audio: ${track.label}'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.black87,
          ),
        );
      }
    } catch (e) {
      print('[VideoPlayer] Error selecting audio track: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return KeyEventHandler(
        onLeftKey: () => _navigateButtons(-1),
        onRightKey: () => _navigateButtons(1),
        onEnterKey: _activateFocusedButton,
        onBackKey: () => Navigator.pop(context),
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    "Playback Error",
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Looks like the player can't play this stream.\nTry another server or open in VLC.",
                    style: TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  if (_errorMessage.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Focus(
                        focusNode: _goBackFocusNode,
                        onKeyEvent: (node, event) {
                          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
                            Navigator.pop(context);
                            return KeyEventResult.handled;
                          }
                          return KeyEventResult.ignored;
                        },
                        child: Builder(
                          builder: (context) {
                            final isFocused = _focusedButtonIndex == 0;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              transform: Matrix4.identity()..scale(isFocused ? 1.1 : 1.0),
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.arrow_back),
                                label: const Text("Go Back"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isFocused ? Colors.grey[600] : Colors.grey[800],
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                  side: isFocused ? const BorderSide(color: Colors.white, width: 2) : null,
                                ),
                                onPressed: () => Navigator.pop(context),
                              ),
                            );
                          },
                        ),
                      ),
                      Focus(
                        focusNode: _vlcFocusNode,
                        onKeyEvent: (node, event) {
                          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
                            VlcLauncher.launchVlc(_currentVideoUrl, widget.title);
                            return KeyEventResult.handled;
                          }
                          return KeyEventResult.ignored;
                        },
                        child: Builder(
                          builder: (context) {
                            final isFocused = _focusedButtonIndex == 1;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              transform: Matrix4.identity()..scale(isFocused ? 1.1 : 1.0),
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.open_in_new),
                                label: const Text("Open in VLC"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isFocused ? Colors.orange[700] : Colors.orange[900],
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                  side: isFocused ? const BorderSide(color: Colors.white, width: 2) : null,
                                ),
                                onPressed: () => VlcLauncher.launchVlc(_currentVideoUrl, widget.title),
                              ),
                            );
                          },
                        ),
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

    if (_playerController == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: CircularProgressIndicator(color: Colors.red),
        ),
      );
    }

    return KeyEventHandler(
      onLeftKey: () {
        if (_showAudioMenu) return;
        _navigateControls(-1);
      },
      onRightKey: () {
        if (_showAudioMenu) return;
        _navigateControls(1);
      },
      onUpKey: () {
        if (_showAudioMenu) {
          _navigateAudioTracks(-1);
        } else {
          _resetControlsHideTimer();
        }
      },
      onDownKey: () {
        if (_showAudioMenu) {
          _navigateAudioTracks(1);
        } else {
          _resetControlsHideTimer();
        }
      },
      onEnterKey: () {
        if (_showAudioMenu) {
          _selectAudioTrack();
        } else {
          _activateFocusedControl();
        }
      },
      onBackKey: () {
        if (_showAudioMenu) {
          setState(() => _showAudioMenu = false);
          _resetControlsHideTimer();
        } else {
          Navigator.pop(context);
        }
      },
      child: RawKeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        autofocus: true,
        onKey: (event) {
          if (event is RawKeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.space) {
              _togglePlayPause();
            }
            _resetControlsHideTimer();
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: GestureDetector(
            onTap: () => _resetControlsHideTimer(),
            child: Stack(
              children: [
                // Video Player
                Positioned.fill(
                  child: Container(
                    color: Colors.black,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: ThaModernPlayer(
                          key: _playerKey,
                          controller: _playerController!,
                          onError: (error) {
                            if (mounted) {
                              setState(() {
                                _hasError = true;
                                _errorMessage = error ?? 'Unknown playback error';
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Custom Controls Overlay
                if (_showControls && !_showAudioMenu)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.4),
                            Colors.black.withOpacity(0.8),
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Seek bar
                          Row(
                            children: [
                              Text(
                                _formatDuration(_currentPosition),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: _totalDuration > Duration.zero
                                        ? (_currentPosition.inMilliseconds / _totalDuration.inMilliseconds).clamp(0.0, 1.0)
                                        : 0.0,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.orange,
                                        borderRadius: BorderRadius.circular(3),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.orange.withOpacity(0.6),
                                            blurRadius: 8,
                                            spreadRadius: 0,
                                          )
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                _formatDuration(_totalDuration),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          
                          // Control buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildControlButton(
                                icon: Icons.replay_10,
                                label: 'Rewind',
                                isFocused: _focusedControlIndex == 0,
                                onTap: _seekBackward,
                              ),
                              const SizedBox(width: 32),
                              _buildControlButton(
                                icon: _isPlaying ? Icons.pause : Icons.play_arrow,
                                label: _isPlaying ? 'Pause' : 'Play',
                                isFocused: _focusedControlIndex == 1,
                                onTap: _togglePlayPause,
                                isLarge: true,
                              ),
                              const SizedBox(width: 32),
                              _buildControlButton(
                                icon: Icons.forward_10,
                                label: 'Skip',
                                isFocused: _focusedControlIndex == 2,
                                onTap: _seekForward,
                              ),
                              const SizedBox(width: 32),
                              _buildControlButton(
                                icon: Icons.audiotrack,
                                label: 'Audio',
                                isFocused: _focusedControlIndex == 3,
                                onTap: _toggleAudioMenu,
                              ),
                            ],
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
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.audiotrack, color: Colors.orange, size: 24),
                                  ),
                                  const SizedBox(width: 16),
                                  const Text(
                                    'Audio Tracks',
                                    style: TextStyle(
                                      color: Colors.white, 
                                      fontSize: 18, 
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (_isLoadingTracks)
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              
                              if (_audioTracks.isEmpty && !_isLoadingTracks)
                                const Padding(
                                  padding: EdgeInsets.all(24.0),
                                  child: Text(
                                    'No audio tracks available',
                                    style: TextStyle(color: Colors.white60),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              else
                                Flexible(
                                  child: ListView.separated(
                                    controller: _audioScrollController,
                                    shrinkWrap: true,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    itemCount: _audioTracks.length,
                                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                                    itemBuilder: (context, index) {
                                      final track = _audioTracks[index];
                                      final isFocused = index == _focusedAudioTrackIndex;
                                      final isSelected = index == _selectedAudioIndex;
                                      
                                      return AnimatedContainer(
                                        duration: const Duration(milliseconds: 150),
                                        transform: Matrix4.identity()..scale(isFocused ? 1.02 : 1.0),
                                        decoration: BoxDecoration(
                                          color: isFocused ? Colors.orange.withOpacity(0.15) : Colors.white.withOpacity(0.05),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isFocused ? Colors.orange.withOpacity(0.5) : Colors.transparent,
                                            width: 1,
                                          ),
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () {
                                              setState(() => _focusedAudioTrackIndex = index);
                                              _selectAudioTrack();
                                            },
                                            borderRadius: BorderRadius.circular(8),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                              child: Row(
                                                children: [
                                                  if (isSelected)
                                                    const Icon(Icons.check_circle, color: Colors.orange, size: 20)
                                                  else
                                                    Icon(Icons.circle_outlined, color: isFocused ? Colors.orange.withOpacity(0.5) : Colors.white24, size: 20),
                                                  
                                                  const SizedBox(width: 16),
                                                  
                                                  Expanded(
                                                    child: Text(
                                                      track.label ?? 'Track ${index + 1}',
                                                      style: TextStyle(
                                                        color: isFocused ? Colors.white : Colors.white70,
                                                        fontSize: 15,
                                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                                      ),
                                                    ),
                                                  ),
                                                  
                                                  if (track.language != null)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: Colors.black26,
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        track.language!.toUpperCase(),
                                                        style: TextStyle(
                                                          color: isFocused ? Colors.orange : Colors.white54,
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
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
        ),
      ),
    );
  }
  
  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isFocused,
    required VoidCallback onTap,
    bool isLarge = false,
  }) {
    final size = isLarge ? 64.0 : 48.0;
    final iconSize = isLarge ? 40.0 : 28.0;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.identity()..scale(isFocused ? 1.15 : 1.0),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(size / 2),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFocused ? Colors.orange[800] : Colors.black45,
                  border: Border.all(
                    color: isFocused ? Colors.white : Colors.white24,
                    width: isFocused ? 2 : 1,
                  ),
                  boxShadow: isFocused
                      ? [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.6),
                            blurRadius: 12,
                            spreadRadius: 2,
                          )
                        ]
                      : [],
                ),
                child: Icon(
                  icon,
                  color: isFocused ? Colors.white : Colors.white70,
                  size: iconSize,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Reserve space for label to avoid layout jumps
        SizedBox(
          height: 16,
          child: AnimatedOpacity(
            opacity: isFocused ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.orangeAccent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
