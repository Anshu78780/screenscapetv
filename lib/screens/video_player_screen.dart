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
                            Colors.black.withOpacity(0.7),
                            Colors.black.withOpacity(0.9),
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
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
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: _totalDuration > Duration.zero
                                        ? (_currentPosition.inMilliseconds / _totalDuration.inMilliseconds).clamp(0.0, 1.0)
                                        : 0.0,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _formatDuration(_totalDuration),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Control buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildControlButton(
                                icon: Icons.replay_10,
                                label: '10s Back',
                                isFocused: _focusedControlIndex == 0,
                                onTap: _seekBackward,
                              ),
                              const SizedBox(width: 16),
                              _buildControlButton(
                                icon: _isPlaying ? Icons.pause : Icons.play_arrow,
                                label: _isPlaying ? 'Pause' : 'Play',
                                isFocused: _focusedControlIndex == 1,
                                onTap: _togglePlayPause,
                                isLarge: true,
                              ),
                              const SizedBox(width: 16),
                              _buildControlButton(
                                icon: Icons.forward_10,
                                label: '10s Forward',
                                isFocused: _focusedControlIndex == 2,
                                onTap: _seekForward,
                              ),
                              const SizedBox(width: 16),
                              _buildControlButton(
                                icon: Icons.audiotrack,
                                label: 'Audio',
                                isFocused: _focusedControlIndex == 3,
                                onTap: _toggleAudioMenu,
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 8),
                          
                          Text(
                            '←→ Navigate  •  Enter Select  •  Space Play/Pause  •  Back Exit',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 11,
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
                      color: Colors.black.withOpacity(0.85),
                      child: Center(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 400),
                          margin: const EdgeInsets.all(24),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.blue.withOpacity(0.5), width: 2),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.audiotrack, color: Colors.blue, size: 28),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Audio Tracks',
                                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                  const Spacer(),
                                  if (_isLoadingTracks)
                                    const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Divider(color: Colors.white24),
                              const SizedBox(height: 8),
                              
                              if (_audioTracks.isEmpty && !_isLoadingTracks)
                                const Padding(
                                  padding: EdgeInsets.all(24.0),
                                  child: Text(
                                    'No audio tracks available',
                                    style: TextStyle(color: Colors.white70),
                                    textAlign: TextAlign.center,
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
                                      
                                      return AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        margin: const EdgeInsets.symmetric(vertical: 4),
                                        transform: Matrix4.identity()..scale(isFocused ? 1.05 : 1.0),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () {
                                              setState(() => _focusedAudioTrackIndex = index);
                                              _selectAudioTrack();
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                              decoration: BoxDecoration(
                                                color: isFocused ? Colors.blue.withOpacity(0.3) : Colors.transparent,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: isFocused ? Colors.blue : Colors.transparent,
                                                  width: 2,
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                                    color: isSelected ? Colors.green : Colors.white54,
                                                    size: 20,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(
                                                      track.label ?? 'Track ${index + 1}',
                                                      style: TextStyle(
                                                        color: isFocused ? Colors.white : Colors.white70,
                                                        fontSize: 16,
                                                        fontWeight: isFocused ? FontWeight.bold : FontWeight.normal,
                                                      ),
                                                    ),
                                                  ),
                                                  if (track.language != null)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: Colors.blue.withOpacity(0.2),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        track.language!.toUpperCase(),
                                                        style: const TextStyle(
                                                          color: Colors.blue,
                                                          fontSize: 12,
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
                              
                              const SizedBox(height: 16),
                              const Divider(color: Colors.white24),
                              const SizedBox(height: 8),
                              const Text(
                                '↑↓ Navigate  •  Enter Select  •  Back Close',
                                style: TextStyle(color: Colors.white54, fontSize: 12),
                                textAlign: TextAlign.center,
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
    final size = isLarge ? 60.0 : 48.0;
    final iconSize = isLarge ? 32.0 : 24.0;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      transform: Matrix4.identity()..scale(isFocused ? 1.1 : 1.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(size / 2),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFocused ? Colors.red : Colors.white.withOpacity(0.2),
                  border: Border.all(
                    color: isFocused ? Colors.white : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: iconSize,
                ),
              ),
            ),
          ),
          if (isFocused) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
