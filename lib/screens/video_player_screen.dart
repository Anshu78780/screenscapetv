import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tha_player/tha_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../provider/extractors/stream_types.dart' as stream_types;
import '../utils/vlc_launcher.dart';
import '../utils/key_event_handler.dart';
import 'dart:async';

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
  bool _showAudioTracks = false;
  bool _showServers = false;
  bool _isPlaying = false;
  bool _isLoading = true;
  bool _showControls = true;
  
  late String _currentVideoUrl;
  late String _currentServerName;
  late Map<String, String>? _currentHeaders;
  
  int _currentStreamIndex = 0;
  List<ThaAudioTrack> _audioTracks = [];
  String? _selectedAudioTrackId;
  int _selectedTrackIndex = 0;
  int _selectedServerIndex = 0;
  
  // 0: -30s, 1: Play/Pause, 2: +30s, 3: Audio, 4: Servers
  int _focusedControlIndex = 1; 
  
  final FocusNode _controlsFocusNode = FocusNode();
  final FocusNode _audioTracksFocusNode = FocusNode();
  
  Timer? _controlsTimer;

  @override
  void initState() {
    super.initState();
    _currentStreamIndex = widget.currentStreamIndex ?? 0;
    _currentVideoUrl = widget.videoUrl;
    _currentServerName = widget.server;
    _currentHeaders = widget.headers;
    
    WakelockPlus.enable();
    _initializePlayer();
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    WakelockPlus.disable();
    _controlsFocusNode.dispose();
    _audioTracksFocusNode.dispose();
    _playerController?.dispose();
    super.dispose();
  }
  
  void _resetControlsTimer() {
    _controlsTimer?.cancel();
    if (!_showControls) {
      setState(() => _showControls = true);
    }
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isPlaying && !_showAudioTracks && !_showServers) {
        setState(() => _showControls = false);
      }
    });
  }
  
  void _showControlsTemporarily() {
    setState(() => _showControls = true);
    _resetControlsTimer();
  }

  Future<void> _initializePlayer() async {
    try {
      final Map<String, String> requestHeaders = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        ...?_currentHeaders,
      };

      print('[VideoPlayer] Initializing player for: $_currentServerName');
      print('[VideoPlayer] Video URL: $_currentVideoUrl');

      final mediaSource = ThaMediaSource(
        _currentVideoUrl,
        headers: requestHeaders,
      );

      _playerController = ThaNativePlayerController.single(
        mediaSource,
        autoPlay: true,
      );

      setState(() {
        _hasError = false;
        _isLoading = true;
        _isPlaying = true; // Auto-play is enabled
      });

      // Load audio tracks immediately
      _loadAudioTracks();
      
      // Start controls timer
      _resetControlsTimer();
      
      // Stop showing loading after a delay
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _isLoading = false);
          // Try loading audio tracks again after video starts
          _loadAudioTracks();
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _switchServer(int index) async {
    if (widget.streams == null || index < 0 || index >= widget.streams!.length) return;
    
    // Close overlay
    setState(() {
      _showServers = false;
      _isLoading = true;
      _currentStreamIndex = index;
    });

    // Update current stream info
    final stream = widget.streams![index];
    _currentServerName = stream.server;
    _currentVideoUrl = stream.link;
    _currentHeaders = stream.headers;

    // Dispose old controller
    _playerController?.pause();
    await Future.delayed(const Duration(milliseconds: 100)); // Grace period
    _playerController?.dispose();
    _playerController = null;
    
    // Re-initialize
    await _initializePlayer();
  }

  Future<void> _loadAudioTracks() async {
    if (_playerController == null) return;
    
    try {
      final tracks = await _playerController!.getAudioTracks();
      if (mounted && tracks.isNotEmpty) {
        setState(() {
          _audioTracks = tracks;
          _selectedAudioTrackId = _playerController!.preferences.value.manualAudioTrackId;
        });
      }
    } catch (e) {
      print('Error loading audio tracks: $e');
    }
  }

  void _togglePlayPause() {
    if (_playerController == null) return;
    
    if (_isPlaying) {
      _playerController!.pause();
      setState(() => _isPlaying = false);
      _controlsTimer?.cancel();
    } else {
      _playerController!.play();
      setState(() => _isPlaying = true);
      _resetControlsTimer();
    }
    _showControlsTemporarily();
  }

  void _seekRelative(int seconds) async {
    if (_playerController == null) return;
    final state = _playerController!.playbackState.value;
    
    final newPos = state.position + Duration(seconds: seconds);
    final duration = state.duration;
    
    if (newPos.inSeconds < 0) {
      _playerController!.seekTo(Duration.zero);
    } else if (newPos > duration) {
      _playerController!.seekTo(duration);
    } else {
      _playerController!.seekTo(newPos);
    }
    _showControlsTemporarily();
  }
  
  void _toggleAudioTracks() {
    _loadAudioTracks();
    setState(() {
      _showAudioTracks = !_showAudioTracks;
      _showServers = false;
      if (_showAudioTracks) {
        _selectedTrackIndex = 0;
      }
    });
    _controlsTimer?.cancel();
  }

  void _toggleServers() {
    setState(() {
      _showServers = !_showServers;
      _showAudioTracks = false;
      if (_showServers) {
        _selectedServerIndex = _currentStreamIndex;
      }
    });
    _controlsTimer?.cancel();
  }
  
  void _selectAudioTrack(ThaAudioTrack track, int index) {
    final currentPrefs = _playerController!.preferences.value;
    _playerController!.preferences.value = currentPrefs.copyWith(
      manualAudioTrackId: track.id,
    );
    
    setState(() {
      _selectedAudioTrackId = track.id;
      _selectedTrackIndex = index;
      _showAudioTracks = false;
    });
    _showControlsTemporarily();
  }

  void _handleControlNavigation({required bool isRight}) {
    _showControlsTemporarily();
    setState(() {
      const totalButtons = 5;
      if (isRight) {
        _focusedControlIndex = (_focusedControlIndex + 1) % totalButtons;
      } else {
        _focusedControlIndex = (_focusedControlIndex - 1 + totalButtons) % totalButtons;
      }
    });
  }

  void _handleControlSelect() {
    _showControlsTemporarily();
    switch (_focusedControlIndex) {
      case 0: // -30s
        _seekRelative(-30);
        break;
      case 1: // Play/Pause
        _togglePlayPause();
        break;
      case 2: // +30s
        _seekRelative(30);
        break;
      case 3: // Audio Tracks
        _toggleAudioTracks();
        break;
      case 4: // Servers
        if (widget.streams != null && widget.streams!.isNotEmpty) {
          _toggleServers();
        }
        break;
    }
  }

  void _handleListNavigation({required bool isDown, required bool isServerList}) {
    setState(() {
      if (isServerList) {
        if (widget.streams == null) return;
        if (isDown) {
          _selectedServerIndex = (_selectedServerIndex + 1).clamp(0, widget.streams!.length - 1);
        } else {
          _selectedServerIndex = (_selectedServerIndex - 1).clamp(0, widget.streams!.length - 1);
        }
      } else {
        // Audio Track List
        if (isDown) {
          _selectedTrackIndex = (_selectedTrackIndex + 1).clamp(0, _audioTracks.length - 1);
        } else {
          _selectedTrackIndex = (_selectedTrackIndex - 1).clamp(0, _audioTracks.length - 1);
        }
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    } else {
      return "$twoDigitMinutes:$twoDigitSeconds";
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorScreen();
    }

    if (_playerController == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: CircularProgressIndicator(color: Colors.red),
        ),
      );
    }

    bool allowControlNav = !_showAudioTracks && !_showServers;

    return KeyEventHandler(
      onLeftKey: allowControlNav ? () => _handleControlNavigation(isRight: false) : null,
      onRightKey: allowControlNav ? () => _handleControlNavigation(isRight: true) : null,
      onUpKey: () {
        if (_showAudioTracks) {
          _handleListNavigation(isDown: false, isServerList: false);
        } else if (_showServers) {
          _handleListNavigation(isDown: false, isServerList: true);
        } else {
          _showControlsTemporarily();
        }
      },
      onDownKey: () {
         if (_showAudioTracks) {
          _handleListNavigation(isDown: true, isServerList: false);
        } else if (_showServers) {
          _handleListNavigation(isDown: true, isServerList: true);
        } else {
          _showControlsTemporarily();
        }
      },
      onEnterKey: () {
        if (_showAudioTracks) {
          if (_audioTracks.isNotEmpty) {
            _selectAudioTrack(_audioTracks[_selectedTrackIndex], _selectedTrackIndex);
          }
        } else if (_showServers) {
          _switchServer(_selectedServerIndex);
        } else {
          _handleControlSelect();
        }
      },
      onBackKey: () {
        if (_showAudioTracks) {
          setState(() => _showAudioTracks = false);
        } else if (_showServers) {
          setState(() => _showServers = false);
        } else {
          Navigator.pop(context);
        }
      },
      onEscapeKey: () {
        if (_showAudioTracks) {
          setState(() => _showAudioTracks = false);
        } else if (_showServers) {
          setState(() => _showServers = false);
        } else {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Video player
            ThaModernPlayer(
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

            // Tap to toggle controls
            Positioned.fill(
              child: GestureDetector(
                onTap: () => _togglePlayPause(), // Tap toggles play/pause and shows controls
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ),
            
            // Loading indicator
            if (_isLoading)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: Colors.red,
                        strokeWidth: 3,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Loading video...',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Bottom controls bar
            if (!_showAudioTracks && !_showServers && _showControls)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildBottomControls(),
              ),
            
            // Audio tracks picker overlay
            if (_showAudioTracks)
              _buildOverlay(
                title: 'Audio Tracks',
                icon: Icons.audiotrack,
                itemCount: _audioTracks.length,
                isEmpty: _audioTracks.isEmpty,
                emptyMessage: 'No audio tracks available',
                itemBuilder: _buildAudioTrackItem,
                onClose: () => setState(() => _showAudioTracks = false),
              ),

             // Server picker overlay
            if (_showServers)
              _buildOverlay(
                title: 'Select Server',
                icon: Icons.dns_rounded,
                itemCount: widget.streams?.length ?? 0,
                isEmpty: widget.streams?.isEmpty ?? true,
                emptyMessage: 'No other servers available',
                itemBuilder: _buildServerItem,
                onClose: () => setState(() => _showServers = false),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
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
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
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
                  ElevatedButton.icon(
                    icon: const Icon(Icons.arrow_back),
                    label: const Text("Go Back"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.open_in_new),
                    label: const Text("Open in VLC"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[900],
                    ),
                    onPressed: () {
                      VlcLauncher.launchVlc(_currentVideoUrl, widget.title);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return ValueListenableBuilder<ThaPlaybackState?>(
      valueListenable: _playerController!.playbackState,
      builder: (context, state, child) {
        final position = state?.position ?? Duration.zero;
        final duration = state?.duration ?? Duration.zero;
        final maxDuration = duration.inSeconds.toDouble();
        final currentValue = position.inSeconds.toDouble().clamp(0.0, maxDuration > 0 ? maxDuration : 0.0);
        
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withOpacity(0.95),
                Colors.black.withOpacity(0.7),
                Colors.transparent,
              ],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Seek Bar
              Row(
                children: [
                  Text(
                    _formatDuration(position),
                    style: const TextStyle(
                      color: Color(0xFFFF6B00),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: const Color(0xFFFF6B00),
                        inactiveTrackColor: Colors.white24,
                        thumbColor: const Color(0xFFFF6B00),
                        overlayColor: const Color(0xFFFF6B00).withOpacity(0.3),
                        trackHeight: 4.0,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
                      ),
                      child: Slider(
                        min: 0.0,
                        max: maxDuration > 0 ? maxDuration : 1.0,
                        value: currentValue,
                        onChanged: (value) {
                          _showControlsTemporarily();
                          _playerController?.seekTo(Duration(seconds: value.toInt()));
                        },
                      ),
                    ),
                  ),
                  Text(
                    _formatDuration(duration),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              // Controls row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // -30s
                  _buildVlcControlButton(
                    icon: Icons.replay_30,
                    isFocused: _focusedControlIndex == 0,
                    onTap: () => _seekRelative(-30),
                  ),
                  const SizedBox(width: 16),

                  // Play/Pause button
                  _buildVlcControlButton(
                    icon: _isPlaying ? Icons.pause : Icons.play_arrow,
                    isFocused: _focusedControlIndex == 1,
                    onTap: _togglePlayPause,
                    isLarge: true,
                  ),
                  
                  const SizedBox(width: 16),

                  // +30s
                  _buildVlcControlButton(
                    icon: Icons.forward_30,
                    isFocused: _focusedControlIndex == 2,
                    onTap: () => _seekRelative(30),
                  ),
                  
                  const SizedBox(width: 24),
                  
                  // Audio tracks button
                  _buildVlcControlButton(
                    icon: Icons.audiotrack,
                    isFocused: _focusedControlIndex == 3,
                    onTap: _toggleAudioTracks,
                  ),

                  const SizedBox(width: 16),

                  // Servers button
                  _buildVlcControlButton(
                    icon: Icons.dns_rounded,
                    isFocused: _focusedControlIndex == 4,
                    onTap: () {
                      if (widget.streams != null && widget.streams!.isNotEmpty) {
                        _toggleServers();
                      }
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 14),
              
              // Bottom info bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Title
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Server info
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B00).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: const Color(0xFFFF6B00).withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _currentServerName,
                      style: const TextStyle(
                        color: Color(0xFFFF6B00),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildVlcControlButton({
    required IconData icon,
    required bool isFocused,
    required VoidCallback onTap,
    bool isLarge = false,
  }) {
    final size = isLarge ? 56.0 : 44.0;
    final iconSize = isLarge ? 32.0 : 24.0;
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isFocused 
              ? const Color(0xFFFF6B00) // VLC orange
              : Colors.white.withOpacity(0.12),
          shape: BoxShape.circle,
          border: isFocused 
              ? Border.all(
                  color: const Color(0xFFFF6B00),
                  width: 3,
                )
              : Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
          boxShadow: isFocused
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF6B00).withOpacity(0.6),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: iconSize,
        ),
      ),
    );
  }

  Widget _buildAudioTrackItem(BuildContext context, int index) {
      final track = _audioTracks[index];
      final isSelected = track.id == _selectedAudioTrackId;
      final isFocused = index == _selectedTrackIndex;
      
      String displayName = track.label ?? '';
      if (displayName.isEmpty) {
        if (track.language != null && track.language!.isNotEmpty) {
          displayName = track.language!;
        } else {
          displayName = 'Track ${track.id}';
        }
      } else if (track.language != null && track.language!.isNotEmpty) {
        // Show language text if it's different from label (case-insensitive)
        if (displayName.toLowerCase() != track.language!.toLowerCase()) {
           displayName = '$displayName [${track.language}]';
        }
      }

      return GestureDetector(
        onTap: () => _selectAudioTrack(track, index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isFocused
                ? const Color(0xFFFF6B00).withOpacity(0.25)
                : isSelected
                    ? Colors.white.withOpacity(0.08)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isFocused
                  ? const Color(0xFFFF6B00)
                  : isSelected
                      ? Colors.white.withOpacity(0.25)
                      : Colors.transparent,
              width: isFocused ? 2 : 1,
            ),
            boxShadow: isFocused
                ? [
                    BoxShadow(
                      color: const Color(0xFFFF6B00).withOpacity(0.4),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isSelected ? const Color(0xFFFF6B00) : Colors.white.withOpacity(0.5),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  displayName,
                  style: TextStyle(
                    color: isFocused || isSelected ? Colors.white : Colors.white70,
                    fontSize: 14,
                    fontWeight: isFocused ? FontWeight.w600 : (isSelected ? FontWeight.w500 : FontWeight.normal),
                  ),
                ),
              ),
              if (isFocused)
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF6B00),
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      );
  }

  Widget _buildServerItem(BuildContext context, int index) {
      final stream = widget.streams![index];
      final isSelected = index == _currentStreamIndex;
      final isFocused = index == _selectedServerIndex;
      
      return GestureDetector(
        onTap: () => _switchServer(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isFocused
                ? const Color(0xFFFF6B00).withOpacity(0.25)
                : isSelected
                    ? Colors.white.withOpacity(0.08)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isFocused
                  ? const Color(0xFFFF6B00)
                  : isSelected
                      ? Colors.white.withOpacity(0.25)
                      : Colors.transparent,
              width: isFocused ? 2 : 1,
            ),
             boxShadow: isFocused
                ? [
                    BoxShadow(
                      color: const Color(0xFFFF6B00).withOpacity(0.4),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isSelected ? const Color(0xFFFF6B00) : Colors.white.withOpacity(0.5),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      stream.server,
                      style: TextStyle(
                        color: isFocused || isSelected ? Colors.white : Colors.white70,
                        fontSize: 14,
                        fontWeight: isFocused ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    Text(
                      stream.type.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
  }
  
  Widget _buildOverlay({
    required String title,
    required IconData icon,
    required int itemCount,
    required bool isEmpty,
    required String emptyMessage,
    required Widget Function(BuildContext, int) itemBuilder,
    required VoidCallback onClose,
  }) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: onClose,
        child: Container(
          color: Colors.black.withOpacity(0.85),
          child: Center(
            child: GestureDetector(
              onTap: () {}, // Prevent closing when tapping inside
              child: Container(
                constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
                margin: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A), // VLC dark gray
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFF6B00), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B00).withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F1F1F),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(10),
                          topRight: Radius.circular(10),
                        ),
                        border: const Border(
                          bottom: BorderSide(color: Color(0xFFFF6B00), width: 2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(icon, color: const Color(0xFFFF6B00), size: 24),
                          const SizedBox(width: 10),
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B00).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '$itemCount',
                              style: const TextStyle(
                                color: Color(0xFFFF6B00),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // List
                    Flexible(
                      child: isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(40),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.do_not_disturb_on, color: Colors.white30, size: 48),
                                  const SizedBox(height: 16),
                                  Text(
                                    emptyMessage,
                                    style: const TextStyle(color: Colors.white60),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: itemCount,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              itemBuilder: itemBuilder,
                            ),
                    ),
                    
                    // Footer hint
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F1F1F),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(10),
                          bottomRight: Radius.circular(10),
                        ),
                        border: const Border(
                          top: BorderSide(color: Color(0xFFFF6B00), width: 1),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildKeyHint('↑↓', 'Navigate'),
                          const SizedBox(width: 16),
                          _buildKeyHint('Enter', 'Select'),
                          const SizedBox(width: 16),
                          _buildKeyHint('Back', 'Close'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildKeyHint(String key, String action) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Text(
            key,
            style: const TextStyle(
              color: Color(0xFFFF6B00),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          action,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
