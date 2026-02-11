import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
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
  int _focusedButtonIndex = 0; // 0 = Go Back, 1 = Open in VLC
  final FocusNode _goBackFocusNode = FocusNode();
  final FocusNode _vlcFocusNode = FocusNode();
  
  // Virtual cursor for player navigation
  Offset _cursorPosition = const Offset(100, 100);
  final double _cursorSpeed = 15.0;
  bool _showCursor = true;
  final GlobalKey _playerKey = GlobalKey();
  Timer? _cursorHideTimer;

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
    _cursorHideTimer?.cancel();
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

      // Create controller without auto-play first
      _playerController = ThaNativePlayerController.single(
        mediaSource,
        autoPlay: true,
      );

      // Wait for controller to be fully initialized
      await Future.delayed(const Duration(milliseconds: 300));

      if (mounted && _playerController != null) {
        // Now start playback after audio subsystem is ready
        await _playerController!.play();
        print('[VideoPlayer] Playback started successfully');
      }

      setState(() {
        _hasError = false;
      });
    } catch (e) {
      print('[VideoPlayer] Initialization error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _focusedButtonIndex = 0; // Reset focus to first button
        });
        // Request focus on the first button after error
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _goBackFocusNode.requestFocus();
        });
      }
    }
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
  
  void _moveCursor(double dx, double dy) {
    setState(() {
      final size = MediaQuery.of(context).size;
      _cursorPosition = Offset(
        (_cursorPosition.dx + dx).clamp(0.0, size.width),
        (_cursorPosition.dy + dy).clamp(0.0, size.height),
      );
      _showCursor = true;
    });
    _resetCursorHideTimer();
  }
  
  void _resetCursorHideTimer() {
    _cursorHideTimer?.cancel();
    _cursorHideTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() {
          _showCursor = false;
        });
      }
    });
  }
  
  void _simulateClickAtCursor() {
    // Flash the cursor to show click
    setState(() => _showCursor = false);
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _showCursor = true);
    });
    
    // Reset hide timer after click
    _resetCursorHideTimer();
    
    // Inject a synthetic tap event at cursor position
    final binding = GestureBinding.instance;
    
    // Create and dispatch pointer down event
    final pointerDown = PointerDownEvent(
      position: _cursorPosition,
      pointer: 1,
      buttons: kPrimaryButton,
    );
    
    binding.handlePointerEvent(pointerDown);
    
    // Dispatch pointer up event after a short delay
    Future.delayed(const Duration(milliseconds: 50), () {
      final pointerUp = PointerUpEvent(
        position: _cursorPosition,
        pointer: 1,
      );
      binding.handlePointerEvent(pointerUp);
    });
    
    print('[Cursor] Simulated click at: $_cursorPosition');
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
                            transform: Matrix4.identity()
                              ..scale(isFocused ? 1.1 : 1.0),
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.arrow_back),
                              label: const Text("Go Back"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isFocused 
                                    ? Colors.grey[600] 
                                    : Colors.grey[800],
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                                side: isFocused
                                    ? const BorderSide(color: Colors.white, width: 2)
                                    : null,
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
                            transform: Matrix4.identity()
                              ..scale(isFocused ? 1.1 : 1.0),
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.open_in_new),
                              label: const Text("Open in VLC"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isFocused
                                    ? Colors.orange[700]
                                    : Colors.orange[900],
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                                side: isFocused
                                    ? const BorderSide(color: Colors.white, width: 2)
                                    : null,
                              ),
                              onPressed: () {
                                VlcLauncher.launchVlc(_currentVideoUrl, widget.title);
                              },
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
      onLeftKey: () => _moveCursor(-_cursorSpeed, 0),
      onRightKey: () => _moveCursor(_cursorSpeed, 0),
      onUpKey: () => _moveCursor(0, -_cursorSpeed),
      onDownKey: () => _moveCursor(0, _cursorSpeed),
      onEnterKey: _simulateClickAtCursor,
      onBackKey: () => Navigator.pop(context),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: MouseRegion(
          onHover: (event) {
            setState(() {
              _cursorPosition = event.position;
              _showCursor = true;
            });
            _resetCursorHideTimer();
          },
          child: GestureDetector(
            onTapDown: (details) {
              setState(() {
                _cursorPosition = details.globalPosition;
                _showCursor = true;
              });
              _resetCursorHideTimer();
            },
            child: Stack(
              children: [
                // Video Player
                Positioned.fill(
                  child: ThaModernPlayer(
                    key: _playerKey,
                    controller: _playerController!,
                    onError: (error) {
                      if (mounted) {
                        setState(() {
                          _hasError = true;
                          _errorMessage = error ?? 'Unknown playback error';
                          _focusedButtonIndex = 0;
                        });
                        // Request focus on the first button after error
                        Future.delayed(const Duration(milliseconds: 100), () {
                          if (mounted) _goBackFocusNode.requestFocus();
                        });
                      }
                    },
                  ),
                ),
                
                // Virtual Cursor Overlay
                if (_showCursor)
                  Positioned(
                    left: _cursorPosition.dx - 16,
                    top: _cursorPosition.dy - 16,
                    child: IgnorePointer(
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.9),
                          border: Border.all(
                            color: Colors.red,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.circle,
                            size: 8,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ),
                  ),
                
                // Instructions overlay (bottom-center) - shown with cursor
                if (_showCursor)
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: const Text(
                            '↑↓←→ Move Cursor  •  Enter/OK Click  •  Back Exit',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
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
}
