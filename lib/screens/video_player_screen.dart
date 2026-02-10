import 'dart:async';
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
  bool _isLoading = true;
  bool _hasLoadedTracks = false;
  
  // UI State
  bool _showControls = true;
  bool _showAudioTracks = false;
  Timer? _hideTimer;
  
  // Navigation State
  // Row 0: Timeline/SeekBar
  // Row 1: Buttons [Audio, -30s, Play/Pause, +30s]
  int _focusRow = 1;
  int _focusCol = 2; // Start on Play/Pause
  
  static const int _controlAudio = 0;
  static const int _controlRewind = 1;
  static const int _controlPlay = 2;
  static const int _controlForward = 3;
  static const int _maxCols = 4;
  
  // Theme
  static const Color _vlcOrange = Colors.deepOrange;
  
  // Audio Tracks
  List<ThaAudioTrack> _audioTracks = [];
  String? _selectedAudioTrackId;
  int _selectedAudioListIndex = 0;
  
  late String _currentVideoUrl;
  late String _currentServerName;
  late Map<String, String>? _currentHeaders;

  @override
  void initState() {
    super.initState();
    _currentVideoUrl = widget.videoUrl;
    _currentServerName = widget.server;
    _currentHeaders = widget.headers;
    
    WakelockPlus.enable();
    _initializePlayer();
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _playerController?.playbackState.removeListener(_onPlaybackStateChanged);
    WakelockPlus.disable();
    _playerController?.dispose();
    super.dispose();
  }

  void _onPlaybackStateChanged() {
    if (_playerController == null || !mounted) return;
    
    final state = _playerController!.playbackState.value;
    
    // Load audio tracks when player starts playing for the first time
    if (state.isPlaying && !_hasLoadedTracks) {
      _hasLoadedTracks = true;
      // Give a small delay to ensure tracks are fully available
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _loadAudioTracks();
        }
      });
    }
    
    // Hide loading spinner when player starts
    if (state.isPlaying && _isLoading) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _initializePlayer() async {
    try {
      final Map<String, String> requestHeaders = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        ...?_currentHeaders,
      };

      print('[VideoPlayer] Initializing for: $_currentServerName');

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
        _hasLoadedTracks = false;
      });

      // Add listener to detect when player is ready
      _playerController!.playbackState.addListener(_onPlaybackStateChanged);
      
      // Fallback: Try loading tracks after a delay if not loaded yet
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && !_hasLoadedTracks) {
          print('[VideoPlayer] Fallback: Loading audio tracks after delay');
          _hasLoadedTracks = true;
          _loadAudioTracks();
          setState(() => _isLoading = false);
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
    
    print('[VideoPlayer] Attempting to load audio tracks...');
    
    try {
      final tracks = await _playerController!.getAudioTracks();
      print('[VideoPlayer] Found ${tracks.length} audio tracks');
      
      if (mounted) {
        setState(() {
          _audioTracks = tracks;
          if (tracks.isNotEmpty) {
            _selectedAudioTrackId = _playerController!.preferences.value.manualAudioTrackId;
            print('[VideoPlayer] Selected audio track: $_selectedAudioTrackId');
          } else {
            print('[VideoPlayer] No audio tracks available');
          }
        });
      }
    } catch (e) {
      print('[VideoPlayer] Error loading audio tracks: $e');
      
      // Retry once after a delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _audioTracks.isEmpty) {
          print('[VideoPlayer] Retrying audio track load...');
          _loadAudioTracks();
        }
      });
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (_showAudioTracks) return; // Don't hide if audio menu is open
    
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _showControls) {
        setState(() => _showControls = false);
      }
    });
  }

  void _resetControls() {
    setState(() {
      _showControls = true;
    });
    _startHideTimer();
  }

  void _togglePlayPause() {
    if (_playerController == null) return;
    final state = _playerController!.playbackState.value;
    if (state.isPlaying) {
      _playerController!.pause();
    } else {
      _playerController!.play();
    }
    _resetControls();
  }

  void _seekRelative(int seconds) {
    if (_playerController == null) return;
    final state = _playerController!.playbackState.value;
    final newPos = state.position + Duration(seconds: seconds);
    final dur = state.duration;
    
    // Clamp
    if (newPos < Duration.zero) {
      _playerController!.seekTo(Duration.zero);
    } else if (newPos > dur) {
      _playerController!.seekTo(dur);
    } else {
      _playerController!.seekTo(newPos);
    }
    _resetControls();
  }

  void _onSelectAudioTrack(ThaAudioTrack track) {
    _playerController!.selectAudioTrack(track.id);
    setState(() {
      _selectedAudioTrackId = track.id;
      _showAudioTracks = false;
    });
    _resetControls();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Audio: ${track.label ?? track.language ?? track.id}'),
        backgroundColor: _vlcOrange,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // --- Key Handling ---

  void _handleLeft() {
    if (_showAudioTracks) return; // Audio Menu handled separately if needed, currently pure ListView
    
    if (!_showControls) {
      _resetControls(); // Show controls
      _seekRelative(-10); // And regular seek
      return;
    }
    
    _resetControls();
    
    if (_focusRow == 0) {
      // Timeline focus: seek small amount
      _seekRelative(-10);
    } else {
      // Buttons focus
      setState(() {
        _focusCol = (_focusCol - 1 + _maxCols) % _maxCols;
      });
    }
  }

  void _handleRight() {
    if (_showAudioTracks) return;

    if (!_showControls) {
      _resetControls();
      _seekRelative(30); // Quick skip forward
      return;
    }

    _resetControls();

    if (_focusRow == 0) {
      // Timeline focus: seek small amount
      _seekRelative(10);
    } else {
      // Buttons focus
      setState(() {
        _focusCol = (_focusCol + 1) % _maxCols;
      });
    }
  }

  void _handleUp() {
    _resetControls();
    if (_showAudioTracks) {
       setState(() {
         _selectedAudioListIndex = (_selectedAudioListIndex - 1).clamp(0, _audioTracks.length - 1);
       });
       return;
    }
    
    if (_focusRow == 1) {
      setState(() => _focusRow = 0);
    }
  }

  void _handleDown() {
    _resetControls();
    if (_showAudioTracks) {
       setState(() {
         _selectedAudioListIndex = (_selectedAudioListIndex + 1).clamp(0, _audioTracks.length - 1);
       });
       return;
    }
    
    if (_focusRow == 0) {
      setState(() => _focusRow = 1);
    }
  }

  void _handleEnter() {
    _resetControls();
    if (_showAudioTracks) {
      if (_audioTracks.isNotEmpty) {
        _onSelectAudioTrack(_audioTracks[_selectedAudioListIndex]);
      }
      return;
    }

    if (_focusRow == 0) {
      // Seek bar enter -> Toggle play/pause or just show controls? 
      // Usually enter on seekbar doesn't do much, maybe Play/Pause is safer
      _togglePlayPause();
    } else {
      // Buttons
      switch (_focusCol) {
        case _controlAudio:
          setState(() {
             _showAudioTracks = true;
             _selectedAudioListIndex = 0;
          });
          break;
        case _controlRewind:
          _seekRelative(-30);
          break;
        case _controlPlay:
          _togglePlayPause();
          break;
        case _controlForward:
          _seekRelative(30);
          break;
      }
    }
  }

  void _handleBack() {
    if (_showAudioTracks) {
      setState(() => _showAudioTracks = false);
      _resetControls();
    } else {
      Navigator.pop(context);
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    if (d.inHours > 0) {
      return "${twoDigits(d.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorScreen();
    }

    if (_playerController == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: _vlcOrange)),
      );
    }

    return KeyEventHandler(
      onLeftKey: _handleLeft,
      onRightKey: _handleRight,
      onUpKey: _handleUp,
      onDownKey: _handleDown,
      onEnterKey: _handleEnter,
      onBackKey: _handleBack,
      onEscapeKey: _handleBack,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Video Surface
            ThaModernPlayer(
              controller: _playerController!,
              onError: (msg) {
                setState(() {
                  _hasError = true;
                  _errorMessage = msg ?? 'Unknown Error';
                });
              },
            ),

            // Invisible Overlay to block taps if needed, or detect taps to show controls
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  if (_showControls) {
                    setState(() => _showControls = false);
                  } else {
                    _resetControls();
                  }
                },
                behavior: HitTestBehavior.translucent,
                child: Container(color: Colors.transparent),
              ),
            ),
            
            // UI Overlay
            if (_showControls && !_showAudioTracks)
              _buildControlsOverlay(),
              
            // Audio Selection Overlay
            if (_showAudioTracks)
              _buildAudioTracksOverlay(),
              
            // Loading Overlay
            if (_isLoading)
               const Center(
                 child: CircularProgressIndicator(color: _vlcOrange),
               ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return ValueListenableBuilder<ThaPlaybackState>(
      valueListenable: _playerController!.playbackState,
      builder: (context, state, child) {
        final duration = state.duration;
        final position = state.position;
        final isPlaying = state.isPlaying;

        // Ensure slider values are valid
        final maxMs = duration.inMilliseconds.toDouble();
        final currentMs = position.inMilliseconds.toDouble().clamp(0.0, maxMs);

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black54,
                Colors.transparent, 
                Colors.transparent, 
                Colors.black87
              ],
              stops: [0.0, 0.2, 0.6, 1.0],
            ),
          ),
          child: Column(
            children: [
              // Top Bar
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white, 
                          fontSize: 18, 
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              
              const Spacer(),
              
              // Bottom Controls
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- Row 0: Seek Bar ---
                    Row(
                      children: [
                        Text(
                          _formatDuration(position),
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 4,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                              // Highlight color if focused
                              thumbColor: _focusRow == 0 ? _vlcOrange : Colors.white,
                              activeTrackColor: _focusRow == 0 ? _vlcOrange : Colors.white70,
                              inactiveTrackColor: Colors.white24,
                            ),
                            child: Slider(
                              value: currentMs,
                              min: 0.0,
                              max: maxMs > 0 ? maxMs : 1.0,
                              onChanged: (val) {
                                _startHideTimer(); // Reset timer on drag
                                _playerController!.seekTo(Duration(milliseconds: val.toInt()));
                              },
                            ),
                          ),
                        ),
                        Text(
                          _formatDuration(duration),
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // --- Row 1: Buttons ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildButton(
                          index: _controlAudio,
                          icon: Icons.audiotrack, 
                          label: "Audio",
                        ),
                        const SizedBox(width: 20),
                        _buildButton(
                          index: _controlRewind,
                          icon: Icons.replay_30, 
                          label: "-30s",
                        ),
                        const SizedBox(width: 20),
                        _buildMainPlayButton(isPlaying),
                        const SizedBox(width: 20),
                        _buildButton(
                          index: _controlForward,
                          icon: Icons.forward_30, 
                          label: "+30s",
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildButton({required int index, required IconData icon, required String label}) {
    final isFocused = (_focusRow == 1 && _focusCol == index);
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _focusRow = 1;
          _focusCol = index;
        });
        _handleEnter();
      },
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isFocused ? _vlcOrange : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: isFocused ? Colors.white : Colors.white38, 
                width: 2
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 4),
          if (isFocused)
            Text(
              label, 
              style: const TextStyle(color: _vlcOrange, fontSize: 10, fontWeight: FontWeight.bold)
            )
          else
             const SizedBox(height: 14), // Placeholder to prevent jump
        ],
      ),
    );
  }
  
  Widget _buildMainPlayButton(bool isPlaying) {
    final isFocused = (_focusRow == 1 && _focusCol == _controlPlay);
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _focusRow = 1;
          _focusCol = _controlPlay;
        });
        _togglePlayPause();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isFocused ? _vlcOrange : Colors.white10,
          shape: BoxShape.circle,
          border: Border.all(
            color: isFocused ? Colors.white : Colors.white54,
            width: isFocused ? 3 : 2,
          ),
          boxShadow: isFocused ? [
            const BoxShadow(color: _vlcOrange, blurRadius: 12)
          ] : null,
        ),
        child: Icon(
          isPlaying ? Icons.pause : Icons.play_arrow,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildAudioTracksOverlay() {
    return Container(
      color: Colors.black87,
      alignment: Alignment.center,
      child: Container(
        width: 350,
        constraints: const BoxConstraints(maxHeight: 500),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _vlcOrange, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: _vlcOrange.withOpacity(0.1),
              child: const Text(
                'Audio Tracks',
                style: TextStyle(
                  color: _vlcOrange, 
                  fontSize: 18, 
                  fontWeight: FontWeight.bold
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const Divider(height: 1, color: Colors.white24),
            Flexible(
              child: _audioTracks.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text("No audio tracks found.", style: TextStyle(color: Colors.white54)),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _audioTracks.length,
                  itemBuilder: (context, index) {
                    final track = _audioTracks[index];
                    final isSelected = track.id == _selectedAudioTrackId;
                    final isFocused = index == _selectedAudioListIndex;
                    
                    return Container(
                      color: isFocused ? _vlcOrange.withOpacity(0.7) : Colors.transparent,
                      child: ListTile(
                        leading: isSelected 
                            ? const Icon(Icons.check, color: Colors.white)
                            : const SizedBox(width: 24),
                        title: Text(
                          track.label ?? track.language ?? 'Track ${track.id}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        dense: true,
                        onTap: () => _onSelectAudioTrack(track),
                      ),
                    );
                  },
                ),
            ),
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
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.withOpacity(0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text("Playback Error", style: TextStyle(color: Colors.white, fontSize: 18)),
              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage, 
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[700]),
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Go Back"),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: _vlcOrange),
                    onPressed: () => VlcLauncher.launchVlc(_currentVideoUrl, widget.title),
                    child: const Text("Open VLC"),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
