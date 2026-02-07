import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'dart:async';

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;
  final String server;

  const VideoPlayerScreen({
    super.key,
    required this.videoUrl,
    required this.title,
    required this.server,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late BetterPlayerController _betterPlayerController;
  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';
  
  // Controls state
  bool _showControls = true;
  Timer? _hideControlsTimer;
  Timer? _seekTimer;
  bool _isSeekingForward = false;
  bool _isSeekingBackward = false;
  String _controlFeedback = '';
  Timer? _feedbackTimer;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    WakelockPlus.enable(); // Keep screen on during playback
    _resetHideControlsTimer();
    
    // Request focus for keyboard/remote input
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _resetHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _showControlsTemporarily() {
    setState(() {
      _showControls = true;
    });
    _resetHideControlsTimer();
  }

  void _showFeedback(String message) {
    setState(() {
      _controlFeedback = message;
    });
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _controlFeedback = '';
        });
      }
    });
  }

  void _togglePlayPause() {
    if (_betterPlayerController.isPlaying() ?? false) {
      _betterPlayerController.pause();
      _showFeedback('Paused');
    } else {
      _betterPlayerController.play();
      _showFeedback('Playing');
    }
    _showControlsTemporarily();
  }

  void _seekForward({int seconds = 10}) {
    final currentPosition = _betterPlayerController.videoPlayerController?.value.position;
    if (currentPosition != null) {
      final newPosition = currentPosition + Duration(seconds: seconds);
      _betterPlayerController.seekTo(newPosition);
      _showFeedback('+$seconds sec');
    }
    _showControlsTemporarily();
  }

  void _seekBackward({int seconds = 10}) {
    final currentPosition = _betterPlayerController.videoPlayerController?.value.position;
    if (currentPosition != null) {
      final newPosition = currentPosition - Duration(seconds: seconds);
      _betterPlayerController.seekTo(newPosition >= Duration.zero ? newPosition : Duration.zero);
      _showFeedback('-$seconds sec');
    }
    _showControlsTemporarily();
  }

  void _startContinuousSeekForward() {
    _isSeekingForward = true;
    _seekTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_isSeekingForward) {
        _seekForward(seconds: 5);
      }
    });
  }

  void _startContinuousSeekBackward() {
    _isSeekingBackward = true;
    _seekTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_isSeekingBackward) {
        _seekBackward(seconds: 5);
      }
    });
  }

  void _stopContinuousSeek() {
    _isSeekingForward = false;
    _isSeekingBackward = false;
    _seekTimer?.cancel();
    _seekTimer = null;
  }

  void _changeSpeed() {
    final currentSpeed = _betterPlayerController.videoPlayerController?.value.speed ?? 1.0;
    double newSpeed;
    
    if (currentSpeed == 1.0) {
      newSpeed = 1.25;
    } else if (currentSpeed == 1.25) {
      newSpeed = 1.5;
    } else if (currentSpeed == 1.5) {
      newSpeed = 2.0;
    } else {
      newSpeed = 1.0;
    }
    
    _betterPlayerController.setSpeed(newSpeed);
    _showFeedback('Speed: ${newSpeed}x');
    _showControlsTemporarily();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!_isInitialized || _hasError) return KeyEventResult.ignored;

    if (event is KeyDownEvent) {
      switch (event.logicalKey) {
        // Play/Pause - Space, Enter, Select, Media Play/Pause
        case LogicalKeyboardKey.space:
        case LogicalKeyboardKey.enter:
        case LogicalKeyboardKey.select:
        case LogicalKeyboardKey.mediaPlayPause:
          _togglePlayPause();
          return KeyEventResult.handled;

        // Seek Forward - Right Arrow, Fast Forward
        case LogicalKeyboardKey.arrowRight:
        case LogicalKeyboardKey.mediaFastForward:
          _startContinuousSeekForward();
          return KeyEventResult.handled;

        // Seek Backward - Left Arrow, Rewind
        case LogicalKeyboardKey.arrowLeft:
        case LogicalKeyboardKey.mediaRewind:
          _startContinuousSeekBackward();
          return KeyEventResult.handled;

        // Speed control - Up Arrow
        case LogicalKeyboardKey.arrowUp:
          _changeSpeed();
          return KeyEventResult.handled;

        // Show/Hide controls - Down Arrow
        case LogicalKeyboardKey.arrowDown:
          setState(() {
            _showControls = !_showControls;
          });
          if (_showControls) {
            _resetHideControlsTimer();
          }
          return KeyEventResult.handled;

        // Back - Exit player
        case LogicalKeyboardKey.escape:
        case LogicalKeyboardKey.goBack:
        case LogicalKeyboardKey.browserBack:
          _betterPlayerController.pause();
          Navigator.of(context).pop();
          return KeyEventResult.handled;

        default:
          return KeyEventResult.ignored;
      }
    } else if (event is KeyUpEvent) {
      // Stop continuous seeking when key is released
      if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
          event.logicalKey == LogicalKeyboardKey.mediaFastForward ||
          event.logicalKey == LogicalKeyboardKey.arrowLeft ||
          event.logicalKey == LogicalKeyboardKey.mediaRewind) {
        _stopContinuousSeek();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  Future<void> _initializePlayer() async {
    try {
      final betterPlayerDataSource = BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        widget.videoUrl,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': '*/*',
          'Accept-Language': 'en-US,en;q=0.5',
        },
        notificationConfiguration: BetterPlayerNotificationConfiguration(
          showNotification: true,
          title: widget.title,
          author: widget.server,
        ),
      );

      _betterPlayerController = BetterPlayerController(
        BetterPlayerConfiguration(
          autoPlay: true,
          looping: false,
          fullScreenByDefault: false,
          fit: BoxFit.contain,
          aspectRatio: 16 / 9,
          controlsConfiguration: const BetterPlayerControlsConfiguration(
            showControls: false, // Disable default controls - we use custom ones
            enableFullscreen: false,
          ),
          autoDetectFullscreenDeviceOrientation: true,
          autoDetectFullscreenAspectRatio: true,
          deviceOrientationsOnFullScreen: [
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
            DeviceOrientation.portraitUp,
          ],
          deviceOrientationsAfterFullScreen: [
            DeviceOrientation.portraitUp,
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ],
          errorBuilder: (context, errorMessage) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Playback Error',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      errorMessage ?? 'Failed to load video',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Go Back'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        betterPlayerDataSource: betterPlayerDataSource,
      );

      // Add event listener for errors and state changes
      _betterPlayerController.addEventsListener((event) {
        if (event.betterPlayerEventType == BetterPlayerEventType.exception) {
          setState(() {
            _hasError = true;
            _errorMessage = 'An error occurred during playback';
          });
        } else if (event.betterPlayerEventType == BetterPlayerEventType.initialized) {
          setState(() {
            _isInitialized = true;
          });
        } else if (event.betterPlayerEventType == BetterPlayerEventType.play ||
                   event.betterPlayerEventType == BetterPlayerEventType.pause) {
          // Rebuild UI on play/pause
          if (mounted) setState(() {});
        }
      });

      // Add periodic timer to update progress UI
      Timer.periodic(const Duration(milliseconds: 500), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_isInitialized && !_hasError && _showControls) {
          setState(() {});
        }
      });

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to initialize player: $e';
      });
    }
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _seekTimer?.cancel();
    _feedbackTimer?.cancel();
    _focusNode.dispose();
    WakelockPlus.disable(); // Release wake lock
    _betterPlayerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      autofocus: true,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (!didPop) {
              _betterPlayerController.pause();
              Navigator.of(context).pop();
            }
          },
          child: GestureDetector(
            onTap: () {
              setState(() {
                _showControls = !_showControls;
              });
              if (_showControls) {
                _resetHideControlsTimer();
              }
            },
            behavior: HitTestBehavior.opaque,
            child: _hasError
                ? _buildErrorScreen()
                : _isInitialized
                    ? _buildPlayer()
                    : _buildLoadingScreen(),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayer() {
    final isPlaying = _betterPlayerController.isPlaying() ?? false;
    final currentPosition = _betterPlayerController.videoPlayerController?.value.position ?? Duration.zero;
    final totalDuration = _betterPlayerController.videoPlayerController?.value.duration ?? Duration.zero;
    final currentSpeed = _betterPlayerController.videoPlayerController?.value.speed ?? 1.0;

    return Stack(
      children: [
        // Video player
        Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: BetterPlayer(
              controller: _betterPlayerController,
            ),
          ),
        ),
        
        // Custom controls overlay
        if (_showControls) ...[
          // Top gradient with title and back button
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button
                    GestureDetector(
                      onTap: () {
                        _betterPlayerController.pause();
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.red, width: 2),
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Title and server info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: Colors.black,
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                'Server: ${widget.server}',
                                style: TextStyle(
                                  color: Colors.grey[300],
                                  fontSize: 14,
                                  shadows: const [
                                    Shadow(
                                      color: Colors.black,
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                              if (currentSpeed != 1.0) ...[
                                const SizedBox(width: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${currentSpeed}x',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Bottom controls with progress bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Progress bar
                    Row(
                      children: [
                        Text(
                          _formatDuration(currentPosition),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 4,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                              activeTrackColor: Colors.red,
                              inactiveTrackColor: Colors.white30,
                              thumbColor: Colors.red,
                              overlayColor: Colors.red.withOpacity(0.3),
                            ),
                            child: Slider(
                              value: totalDuration.inMilliseconds > 0
                                  ? currentPosition.inMilliseconds.toDouble()
                                  : 0,
                              min: 0,
                              max: totalDuration.inMilliseconds.toDouble(),
                              onChanged: (value) {
                                _betterPlayerController.seekTo(Duration(milliseconds: value.toInt()));
                                _resetHideControlsTimer();
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDuration(totalDuration),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
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
                          label: 'Rewind',
                          onPressed: () => _seekBackward(),
                        ),
                        const SizedBox(width: 24),
                        _buildControlButton(
                          icon: isPlaying ? Icons.pause : Icons.play_arrow,
                          label: isPlaying ? 'Pause' : 'Play',
                          onPressed: _togglePlayPause,
                          isLarge: true,
                        ),
                        const SizedBox(width: 24),
                        _buildControlButton(
                          icon: Icons.forward_10,
                          label: 'Forward',
                          onPressed: () => _seekForward(),
                        ),
                        const SizedBox(width: 24),
                        _buildControlButton(
                          icon: Icons.speed,
                          label: '${currentSpeed}x',
                          onPressed: _changeSpeed,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Help text
                    Text(
                      'Space/Enter: Play/Pause  •  ← →: Seek  •  ↑: Speed  •  ↓: Controls  •  Back/Esc: Exit',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        
        // Center feedback (for pause/play/seek feedback)
        if (_controlFeedback.isNotEmpty)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red, width: 2),
              ),
              child: Text(
                _controlFeedback,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
        // Seeking indicators
        if (_isSeekingBackward)
          Positioned(
            left: 40,
            top: 0,
            bottom: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red, width: 3),
                ),
                child: const Icon(
                  Icons.fast_rewind,
                  color: Colors.red,
                  size: 48,
                ),
              ),
            ),
          ),
        
        if (_isSeekingForward)
          Positioned(
            right: 40,
            top: 0,
            bottom: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red, width: 3),
                ),
                child: const Icon(
                  Icons.fast_forward,
                  color: Colors.red,
                  size: 48,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isLarge = false,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.all(isLarge ? 16 : 12),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.2),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.red, width: 2),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: isLarge ? 40 : 28,
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

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading video...',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.server,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(40),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withOpacity(0.3), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 24),
            const Text(
              'Playback Error',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Server: ${widget.server}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
