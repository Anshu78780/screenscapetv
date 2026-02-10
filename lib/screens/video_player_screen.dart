import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _showAudioTracks = false;
  bool _isPlaying = false;
  bool _isLoading = true;
  bool _showControls = true;
  
  late String _currentVideoUrl;
  late String _currentServerName;
  late Map<String, String>? _currentHeaders;
  
  List<ThaAudioTrack> _audioTracks = [];
  String? _selectedAudioTrackId;
  int _selectedTrackIndex = 0;
  int _focusedControlIndex = 0; // 0: play/pause, 1: audio tracks
  
  final FocusNode _controlsFocusNode = FocusNode();
  final FocusNode _audioTracksFocusNode = FocusNode();

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
    _controlsFocusNode.dispose();
    _audioTracksFocusNode.dispose();
    _playerController?.dispose();
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    try {
      final Map<String, String> requestHeaders = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        ...?_currentHeaders,
      };

      print('[VideoPlayer] Initializing player for: $_currentServerName');
      print('[VideoPlayer] Video URL: $_currentVideoUrl');
      print('[VideoPlayer] Headers: $requestHeaders');

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
    } else {
      _playerController!.play();
      setState(() => _isPlaying = true);
    }
  }
  
  void _toggleAudioTracks() {
    // Always try to load audio tracks when opening
    _loadAudioTracks();
    
    setState(() {
      _showAudioTracks = !_showAudioTracks;
      if (_showAudioTracks) {
        _selectedTrackIndex = 0;
      }
    });
  }
  
  void _selectAudioTrack(ThaAudioTrack track, int index) {
    // Update preferences to set the audio track
    final currentPrefs = _playerController!.preferences.value;
    _playerController!.preferences.value = currentPrefs.copyWith(
      manualAudioTrackId: track.id,
    );
    
    setState(() {
      _selectedAudioTrackId = track.id;
      _selectedTrackIndex = index;
      _showAudioTracks = false;
    });
  }

  void _handleControlNavigation({required bool isRight}) {
    setState(() {
      // Always have 2 controls: play/pause (0) and audio (1)
      if (isRight) {
        _focusedControlIndex = (_focusedControlIndex + 1) % 2;
      } else {
        _focusedControlIndex = (_focusedControlIndex - 1);
        if (_focusedControlIndex < 0) _focusedControlIndex = 1;
      }
    });
  }

  void _handleControlSelect() {
    if (_focusedControlIndex == 0) {
      _togglePlayPause();
    } else if (_focusedControlIndex == 1) {
      _toggleAudioTracks();
    }
  }

  void _handleAudioTrackNavigation({required bool isDown}) {
    setState(() {
      if (isDown) {
        _selectedTrackIndex = (_selectedTrackIndex + 1).clamp(0, _audioTracks.length - 1);
      } else {
        _selectedTrackIndex = (_selectedTrackIndex - 1).clamp(0, _audioTracks.length - 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
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

    if (_playerController == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: CircularProgressIndicator(color: Colors.red),
        ),
      );
    }

    return KeyEventHandler(
      onLeftKey: _showAudioTracks ? null : () => _handleControlNavigation(isRight: false),
      onRightKey: _showAudioTracks ? null : () => _handleControlNavigation(isRight: true),
      onUpKey: _showAudioTracks ? () => _handleAudioTrackNavigation(isDown: false) : null,
      onDownKey: _showAudioTracks ? () => _handleAudioTrackNavigation(isDown: true) : null,
      onEnterKey: () {
        if (_showAudioTracks) {
          if (_audioTracks.isNotEmpty) {
            _selectAudioTrack(_audioTracks[_selectedTrackIndex], _selectedTrackIndex);
          }
        } else {
          _handleControlSelect();
        }
      },
      onBackKey: () {
        if (_showAudioTracks) {
          setState(() => _showAudioTracks = false);
        } else {
          Navigator.pop(context);
        }
      },
      onEscapeKey: () {
        if (_showAudioTracks) {
          setState(() => _showAudioTracks = false);
        } else {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Video player with built-in controls (we'll cover them with our custom UI)
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

            // Overlay to hide built-in controls and show only our custom ones
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  // Tap to toggle controls visibility if needed
                },
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
            if (!_showAudioTracks && _showControls)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildBottomControls(),
              ),
            
            // Audio tracks picker overlay
            if (_showAudioTracks)
              _buildAudioTracksOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.9),
            Colors.black.withOpacity(0.7),
            Colors.transparent,
          ],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          Text(
            widget.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          
          // Controls row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Play/Pause button
              _buildControlButton(
                icon: _isPlaying ? Icons.pause : Icons.play_arrow,
                label: _isPlaying ? 'Pause' : 'Play',
                isFocused: _focusedControlIndex == 0,
                onTap: _togglePlayPause,
              ),
              
              const SizedBox(width: 24),
              
              // Audio tracks button (always visible)
              _buildControlButton(
                icon: Icons.audiotrack,
                label: 'Audio',
                isFocused: _focusedControlIndex == 1,
                onTap: _toggleAudioTracks,
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Navigation hint
          Text(
            '← → Navigate  •  Enter Select  •  Back Exit',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isFocused,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isFocused 
              ? Colors.red
              : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isFocused ? Colors.red : Colors.white.withOpacity(0.3),
            width: isFocused ? 3 : 1,
          ),
          boxShadow: isFocused
              ? [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.5),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: isFocused ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAudioTracksOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _showAudioTracks = false),
        child: Container(
          color: Colors.black87,
          child: Center(
            child: GestureDetector(
              onTap: () {}, // Prevent closing when tapping inside
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
                margin: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.3),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.white12),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.audiotrack, color: Colors.red, size: 28),
                          const SizedBox(width: 12),
                          const Text(
                            'Audio Tracks',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_audioTracks.length} available',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Tracks list
                    Flexible(
                      child: _audioTracks.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(40),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.music_off, color: Colors.white30, size: 48),
                                  SizedBox(height: 16),
                                  Text(
                                    'No audio tracks available',
                                    style: TextStyle(color: Colors.white60),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: _audioTracks.length,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              itemBuilder: (context, index) {
                                final track = _audioTracks[index];
                                final isSelected = track.id == _selectedAudioTrackId;
                                final isFocused = index == _selectedTrackIndex;
                                
                                return GestureDetector(
                                  onTap: () => _selectAudioTrack(track, index),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: isFocused
                                          ? Colors.red.withOpacity(0.2)
                                          : isSelected
                                              ? Colors.white.withOpacity(0.1)
                                              : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isFocused
                                            ? Colors.red
                                            : isSelected
                                                ? Colors.white.withOpacity(0.3)
                                                : Colors.transparent,
                                        width: isFocused ? 2 : 1,
                                      ),
                                      boxShadow: isFocused
                                          ? [
                                              BoxShadow(
                                                color: Colors.red.withOpacity(0.4),
                                                blurRadius: 8,
                                                spreadRadius: 1,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                          color: isSelected ? Colors.red : Colors.white54,
                                          size: 22,
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Text(
                                            track.label ?? track.language ?? 'Track ${track.id}',
                                            style: TextStyle(
                                              color: isFocused || isSelected ? Colors.white : Colors.white70,
                                              fontSize: 15,
                                              fontWeight: isFocused ? FontWeight.bold : (isSelected ? FontWeight.w600 : FontWeight.normal),
                                            ),
                                          ),
                                        ),
                                        if (isFocused)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'FOCUSED',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    
                    // Footer hint
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Colors.white12),
                        ),
                      ),
                      child: const Text(
                        '↑↓ Navigate  •  Enter Select  •  Back/ESC Close',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
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
}
