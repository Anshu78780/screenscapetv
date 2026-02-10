import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'dart:async';

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;
  final String server;
  final Map<String, String>? headers;

  const VideoPlayerScreen({
    super.key,
    required this.videoUrl,
    required this.title,
    required this.server,
    this.headers,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late BetterPlayerController _betterPlayerController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // State
  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isBuffering = true;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  // Controls UI
  bool _showControls = true;
  Timer? _hideControlsTimer;
  bool _showSettings = false;
  bool _showTracks = false;

  // Focus Management
  final FocusNode _backgroundFocusNode = FocusNode();
  final FocusNode _playPauseFocusNode = FocusNode();
  final FocusNode _rewindFocusNode = FocusNode();
  final FocusNode _forwardFocusNode = FocusNode();
  final FocusNode _progressBarFocusNode = FocusNode(); 
  final FocusNode _settingsFocusNode = FocusNode();
  
  List<BetterPlayerAsmsAudioTrack>? _audioTracks;
  BetterPlayerAsmsAudioTrack? _selectedAudioTrack;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _initializePlayer();
    _startHideControlsTimer();
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _backgroundFocusNode.dispose();
    _playPauseFocusNode.dispose();
    _rewindFocusNode.dispose();
    _forwardFocusNode.dispose();
    _progressBarFocusNode.dispose();
    _settingsFocusNode.dispose();
    WakelockPlus.disable();
    _betterPlayerController.dispose();
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    try {
      BetterPlayerConfiguration betterPlayerConfiguration = BetterPlayerConfiguration(
        aspectRatio: 16 / 9,
        fit: BoxFit.contain,
        autoPlay: true,
        looping: false,
        fullScreenByDefault: false,
        allowedScreenSleep: false,
        controlsConfiguration: const BetterPlayerControlsConfiguration(
          showControls: false, // We use custom controls
        ),
        eventListener: _onPlayerEvent,
      );

      // Merge custom headers with default User-Agent
      final Map<String, String> requestHeaders = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        ...?widget.headers, // Spread operator to include headers from Stream (if provided)
      };

      print('[VideoPlayer] Initializing player for: ${widget.server}');
      print('[VideoPlayer] Video URL: ${widget.videoUrl}');
      print('[VideoPlayer] Headers: $requestHeaders');

      BetterPlayerDataSource dataSource = BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        widget.videoUrl,
        headers: requestHeaders,
        useAsmsTracks: true,
        useAsmsSubtitles: true,
        notificationConfiguration: BetterPlayerNotificationConfiguration(
          showNotification: true,
          title: widget.title,
          author: widget.server,
        ),
      );

      _betterPlayerController = BetterPlayerController(betterPlayerConfiguration);
      await _betterPlayerController.setupDataSource(dataSource);
      
      _betterPlayerController.videoPlayerController?.addListener(_onVideoControllerUpdate);
      
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isBuffering = false;
        });
      }
    }
  }

  void _onPlayerEvent(BetterPlayerEvent event) {
    if (!mounted) return;
    switch (event.betterPlayerEventType) {
      case BetterPlayerEventType.initialized:
        setState(() {
          _isInitialized = true;
          _isBuffering = false;
        });
        _backgroundFocusNode.requestFocus();
        // Defer audio track loading — ASMS tracks may not be populated immediately
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          final tracks = _betterPlayerController.betterPlayerAsmsAudioTracks;
          setState(() {
            _audioTracks = tracks != null && tracks.isNotEmpty ? tracks : null;
            _selectedAudioTrack = _betterPlayerController.betterPlayerAsmsAudioTrack;
          });
        });
        break;
      case BetterPlayerEventType.bufferingStart:
        setState(() => _isBuffering = true);
        break;
      case BetterPlayerEventType.bufferingEnd:
        setState(() => _isBuffering = false);
        break;
      case BetterPlayerEventType.exception:
        setState(() {
          _hasError = true;
          _errorMessage = "Playback error occurred";
        });
        break;
      default:
        break;
    }
  }

  void _onVideoControllerUpdate() {
    if (!mounted) return;
    final controller = _betterPlayerController.videoPlayerController;
    if (controller == null) return;

    final isPlaying = controller.value.isPlaying;
    final position = controller.value.position;
    final duration = controller.value.duration;

    if (isPlaying != _isPlaying || 
        position.inSeconds != _position.inSeconds ||
        duration != _duration) {
      setState(() {
        _isPlaying = isPlaying;
        _position = position;
        _duration = duration ?? Duration.zero;
      });
    }
  }

  void _toggleControls() {
    if (_showControls) {
      _hideControls();
    } else {
      _showControlsAndResetTimer();
    }
  }

  void _showControlsAndResetTimer() {
    if (!mounted) return;
    setState(() {
      _showControls = true;
    });
    // When showing controls from hidden state, focus Play/Pause or valid control
    if (!_playPauseFocusNode.hasFocus && 
        !_rewindFocusNode.hasFocus && 
        !_forwardFocusNode.hasFocus &&
        !_settingsFocusNode.hasFocus) {
       _playPauseFocusNode.requestFocus();
    }
    
    _startHideControlsTimer();
  }

  void _hideControls() {
    if (mounted) {
      setState(() {
        _showControls = false;
        _showSettings = false;
        _showTracks = false;
      });
      // Return focus to background for shortcuts
      _backgroundFocusNode.requestFocus();
    }
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (_isPlaying && !_showSettings && !_showTracks && mounted) {
        _hideControls();
      }
    });
  }

  KeyEventResult _handleBackgroundKeyPress(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Wake up controls on any major key press
    final isNavKey = [
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.select,
    ].contains(event.logicalKey);

    if (!_showControls && isNavKey) {
      _showControlsAndResetTimer();
      return KeyEventResult.handled;
    }
    
    // Shortcuts when controls are hidden
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        _rewind();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        _forward();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.space:
      case LogicalKeyboardKey.mediaPlayPause:
        _togglePlay();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
      case LogicalKeyboardKey.goBack:
        Navigator.pop(context);
        return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _togglePlay() {
    if (_isPlaying) {
      _betterPlayerController.pause();
    } else {
      _betterPlayerController.play();
    }
    _showControlsAndResetTimer();
  }

  void _rewind() {
    final newPos = _position - const Duration(seconds: 10);
    _betterPlayerController.seekTo(newPos < Duration.zero ? Duration.zero : newPos);
    _showControlsAndResetTimer();
  }

  void _forward() {
    final newPos = _position + const Duration(seconds: 10);
    final max = _duration;
    _betterPlayerController.seekTo(newPos > max ? max : newPos);
    _showControlsAndResetTimer();
  }
  
  void _toggleSettings() {
    setState(() {
      _showSettings = !_showSettings;
      _showTracks = false;
    });
  }
  
  void _toggleTracks() {
      // Always re-query tracks when opening the menu
      final tracks = _betterPlayerController.betterPlayerAsmsAudioTracks;
      final current = _betterPlayerController.betterPlayerAsmsAudioTrack;
      setState(() {
           _audioTracks = tracks != null && tracks.isNotEmpty ? tracks : null;
           _selectedAudioTrack = current ?? _selectedAudioTrack;
           _showTracks = !_showTracks;
           _showSettings = false;
      });
  }
  
  void _changeAudioTrack(BetterPlayerAsmsAudioTrack track) {
      _betterPlayerController.setAudioTrack(track);
      setState(() {
          _selectedAudioTrack = track;
          _showTracks = false;
      });
      _showControlsAndResetTimer();
      // Show snackbar or toast
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Audio changed to ${track.label ?? track.language ?? 'Unknown'}"),
          duration: const Duration(seconds: 2),
      ));
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text("Playback Error", style: TextStyle(color: Colors.white)),
              Text(_errorMessage, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Go Back"),
              )
            ],
          ),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Video Layer
          Center(
            child: _isInitialized
                ? BetterPlayer(controller: _betterPlayerController)
                : const SizedBox(),
          ),

          // 2. Gesture Layer (Tap to toggle, Double tap to seek)
          Positioned.fill(
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _toggleControls,
                    onDoubleTap: _rewind,
                    child: Container(color: Colors.transparent),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _toggleControls,
                    onDoubleTap: _forward,
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ],
            ),
          ),

          // 3. Loading Layer
          if (!_isInitialized || _isBuffering)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.red),
              ),
            ),

          // 4. Background Focus Trap (When controls hidden)
          if (!_showControls)
            Positioned.fill(
              child: Focus(
                focusNode: _backgroundFocusNode,
                autofocus: true,
                onKeyEvent: _handleBackgroundKeyPress,
                child: Container(color: Colors.transparent),
              ),
            ),

          // 5. Controls Layer
          if (_showControls && _isInitialized)
            _buildControlsOverlay(),
        ],
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.black87, Colors.transparent, Colors.black87],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Top Bar
            GestureDetector(
              onTap: _showControlsAndResetTimer,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
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
                            widget.server,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            Expanded(child: _showSettings || _showTracks ? _buildSettingsPanel() : Container()),
            
            // Bottom Controls
            GestureDetector(
              onTap: _showControlsAndResetTimer,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Progress
                    Row(
                      children: [
                        Text(_formatDuration(_position),
                            style: const TextStyle(color: Colors.white)),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                               thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                               trackHeight: 2,
                               activeTrackColor: Colors.red,
                               thumbColor: Colors.red,
                               inactiveTrackColor: Colors.white24,
                            ),
                            child: Slider(
                              value: _position.inMilliseconds.toDouble(),
                              min: 0,
                              max: _duration.inMilliseconds.toDouble() > 0 
                                  ? _duration.inMilliseconds.toDouble() 
                                  : 0.0,
                              onChanged: (val) {
                                _betterPlayerController.seekTo(Duration(milliseconds: val.toInt()));
                                _startHideControlsTimer();
                              },
                            ),
                          ),
                        ),
                        Text(_formatDuration(_duration),
                            style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Buttons with Focus
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildControlButton(
                          icon: Icons.replay_10, 
                          focusNode: _rewindFocusNode,
                          onPressed: _rewind,
                        ),
                        const SizedBox(width: 24),
                        _buildControlButton(
                          icon: _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                          focusNode: _playPauseFocusNode,
                          onPressed: _togglePlay,
                          size: 64,
                        ),
                        const SizedBox(width: 24),
                        _buildControlButton(
                          icon: Icons.forward_10,
                          focusNode: _forwardFocusNode,
                          onPressed: _forward,
                        ),
                        const SizedBox(width: 48),
                        // Settings / Tracks
                        _buildControlButton(
                          icon: Icons.audiotrack,
                          focusNode: _settingsFocusNode,
                          onPressed: _toggleTracks,
                          size: 32,
                          tooltip: "Audio Tracks",
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
    );
  }

  Widget _buildControlButton({
    required IconData icon, 
    required FocusNode focusNode, 
    required VoidCallback onPressed,
    double size = 48,
    String? tooltip,
  }) {
    return Focus(
      focusNode: focusNode,
      onFocusChange: (focused) {
          if (focused) _startHideControlsTimer();
          if (mounted) setState(() {}); 
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.enter || 
              event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.space) {
            onPressed();
            return KeyEventResult.handled;
          }
          // Back/Escape closes controls
          if (event.logicalKey == LogicalKeyboardKey.escape ||
              event.logicalKey == LogicalKeyboardKey.goBack) {
            if (_showTracks || _showSettings) {
              setState(() { _showTracks = false; _showSettings = false; });
            } else {
              Navigator.pop(context);
            }
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          decoration: BoxDecoration(
             color: focusNode.hasFocus ? Colors.white.withOpacity(0.2) : Colors.transparent,
             shape: BoxShape.circle,
             border: focusNode.hasFocus ? Border.all(color: Colors.red, width: 2) : null,
          ),
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: focusNode.hasFocus ? Colors.red : Colors.white, size: size),
        ),
      ),
    );
  }
  
  Widget _buildSettingsPanel() {
      if (_showTracks) {
          if (_audioTracks == null || _audioTracks!.isEmpty) {
              return Center(
                child: Container(
                  width: 300,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Text(
                    "No audio tracks available",
                    style: TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
          }
          return Center(
             child: Container(
                width: 300,
                decoration: BoxDecoration(
                   color: Colors.black87,
                   borderRadius: BorderRadius.circular(8),
                   border: Border.all(color: Colors.white24)
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                       const Text("Select Audio", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                       const SizedBox(height: 12),
                       ..._audioTracks!.asMap().entries.map((entry) {
                           final index = entry.key;
                           final track = entry.value;
                           final isSelected = track.id == _selectedAudioTrack?.id;
                           return _buildTrackTile(track, isSelected, index == 0);
                       }),
                   ],
                ),
             ),
          );
      }
      return Container();
  }

  Widget _buildTrackTile(BetterPlayerAsmsAudioTrack track, bool isSelected, bool autoFocusFirst) {
    return Builder(builder: (context) {
      return Focus(
        autofocus: isSelected || autoFocusFirst,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.select) {
              _changeAudioTrack(track);
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.escape ||
                event.logicalKey == LogicalKeyboardKey.goBack) {
              setState(() => _showTracks = false);
              _settingsFocusNode.requestFocus();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        onFocusChange: (_) { if (mounted) setState(() {}); },
        child: Builder(builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          return GestureDetector(
            onTap: () => _changeAudioTrack(track),
            child: Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: hasFocus
                    ? Colors.red.withOpacity(0.3)
                    : isSelected
                        ? Colors.white.withOpacity(0.1)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: hasFocus ? Border.all(color: Colors.red, width: 1.5) : null,
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isSelected ? Colors.red : Colors.white54,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      track.label ?? track.language ?? "Track ${track.id}",
                      style: TextStyle(
                        color: isSelected ? Colors.red : Colors.white,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      );
    });
  }

  String _formatDuration(Duration d) {
    final hh = d.inHours.toString().padLeft(2, '0');
    final mm = (d.inMinutes % 60).toString().padLeft(2, '0');
    final ss = (d.inSeconds % 60).toString().padLeft(2, '0');
    return d.inHours > 0 ? "$hh:$mm:$ss" : "$mm:$ss";
  }
}
