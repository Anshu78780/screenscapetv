import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:tha_player/tha_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../provider/extractors/stream_types.dart' as stream_types;
import '../utils/vlc_launcher.dart';
import '../utils/key_event_handler.dart';
import '../utils/subtitle_service.dart';

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

  // Server Selection
  bool _showServerMenu = false;
  int _focusedServerIndex = 0;
  final ScrollController _serverScrollController = ScrollController();

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

  // Subtitle track selection
  bool _showSubtitleMenu = false;
  List<ThaSubtitleTrack> _subtitleTracks = [];
  int _selectedSubtitleIndex = -1; // -1 means no subtitle
  int _focusedSubtitleTrackIndex = 0;
  bool _isLoadingSubtitles = false;
  final ScrollController _subtitleScrollController = ScrollController();

  // Control focus management
  int _focusedControlIndex =
      1; // 0=backward, 1=play/pause, 2=forward, 3=audio, 4=subtitle, 5=server
  bool _isBackButtonFocused = false;

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
    _subtitleScrollController.dispose();
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    try {
      final Map<String, String> requestHeaders = {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
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

      // Load audio tracks and subtitles after a delay to ensure player is ready
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _loadAudioTracks();
          _loadSubtitleTracks();
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
    if (!_showAudioMenu && !_showSubtitleMenu) {
      setState(() => _showControls = true);
      _controlsHideTimer = Timer(const Duration(seconds: 4), () {
        if (mounted && !_showAudioMenu && !_showSubtitleMenu) {
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
      // Navigation order matches visual layout:
      // Left: Server(5) | Center: Backward(0) - Play(1) - Forward(2) | Right: Audio(3) - Subtitle(4)
      if (delta > 0) {
        // Moving right
        if (_focusedControlIndex == 5) {
          _focusedControlIndex = 0; // Server → Backward
        } else if (_focusedControlIndex == 2) {
          _focusedControlIndex = 3; // Forward → Audio
        } else if (_focusedControlIndex == 4) {
          _focusedControlIndex = 5; // Subtitle → Server (wrap)
        } else {
          _focusedControlIndex++;
        }
      } else {
        // Moving left
        if (_focusedControlIndex == 0) {
          _focusedControlIndex = 5; // Backward → Server
        } else if (_focusedControlIndex == 3) {
          _focusedControlIndex = 2; // Audio → Forward
        } else if (_focusedControlIndex == 5) {
          _focusedControlIndex = 4; // Server → Subtitle (wrap)
        } else {
          _focusedControlIndex--;
        }
      }
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
      case 4:
        _toggleSubtitleMenu();
        break;
      case 5:
        _toggleServerMenu();
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
    setState(() {
      int newIndex = _focusedAudioTrackIndex + delta;
      final maxIndex = _audioTracks.isEmpty ? -1 : _audioTracks.length - 1;
      if (newIndex < -1) newIndex = maxIndex;
      if (newIndex > maxIndex) newIndex = -1;
      _focusedAudioTrackIndex = newIndex;
    });

    // Auto-scroll to focused item
    if (_focusedAudioTrackIndex >= 0 && _audioScrollController.hasClients) {
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
    if (_focusedAudioTrackIndex < 0) return; // Close button focused

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

  Future<void> _loadSubtitleTracks() async {
    if (_playerController == null) return;

    setState(() => _isLoadingSubtitles = true);

    try {
      // Try up to 3 times with delays
      for (int attempt = 0; attempt < 3; attempt++) {
        final tracks = await _playerController!.getSubtitleTracks();

        if (tracks.isNotEmpty) {
          if (mounted) {
            setState(() {
              _subtitleTracks = tracks;
              _isLoadingSubtitles = false;
              _selectedSubtitleIndex = -1;
            });
            print('[VideoPlayer] Loaded ${tracks.length} subtitle tracks');
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
          _subtitleTracks = [];
          _isLoadingSubtitles = false;
        });
        print('[VideoPlayer] No subtitle tracks found after retries');
      }
    } catch (e) {
      print('[VideoPlayer] Error loading subtitle tracks: $e');
      if (mounted) {
        setState(() {
          _subtitleTracks = [];
          _isLoadingSubtitles = false;
        });
      }
    }
  }

  void _toggleSubtitleMenu() {
    if (!_showSubtitleMenu) {
      // Opening menu
      setState(() {
        _showSubtitleMenu = true;
        // Map selected index to ListView index
        // 0=Search, 1=Add, 2..N+1=Tracks, N+2=Off
        if (_selectedSubtitleIndex == -1) {
          // Focus "Off" option (last item)
          _focusedSubtitleTrackIndex = _subtitleTracks.length + 2;
        } else {
          // Focus specific track
          _focusedSubtitleTrackIndex = _selectedSubtitleIndex + 2;
        }

        _controlsHideTimer?.cancel();

        // Reload tracks if empty
        if (_subtitleTracks.isEmpty && !_isLoadingSubtitles) {
          _loadSubtitleTracks();
        }
      });

      // Scroll to selected item after menu opens
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_subtitleScrollController.hasClients) {
          final itemHeight = 56.0;
          final targetOffset = _focusedSubtitleTrackIndex * itemHeight;
          _subtitleScrollController.animateTo(
            targetOffset,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } else {
      // Closing menu
      setState(() {
        _showSubtitleMenu = false;
        _resetControlsHideTimer();
      });
    }
  }

  void _navigateSubtitleTracks(int delta) {
    // Total items: Search(0) + Add(1) + Tracks + Off(last)
    final totalItems = _subtitleTracks.length + 3;

    setState(() {
      int newIndex = _focusedSubtitleTrackIndex + delta;
      if (newIndex < -1) newIndex = totalItems - 1;
      if (newIndex >= totalItems) newIndex = -1;
      _focusedSubtitleTrackIndex = newIndex;
    });

    // Auto-scroll to focused item
    if (_focusedSubtitleTrackIndex >= 0 &&
        _subtitleScrollController.hasClients) {
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
    if (_playerController == null) return;

    try {
      final totalItems = _subtitleTracks.length + 3;

      // Index 0: Search
      if (_focusedSubtitleTrackIndex == 0) {
        await _searchSubtitlesOnline();
        return;
      }

      // Index 1: Add File
      if (_focusedSubtitleTrackIndex == 1) {
        await _addSubtitleFile();
        return;
      }

      // Last Index: Off
      if (_focusedSubtitleTrackIndex == totalItems - 1) {
        await _disableSubtitle();
        return;
      }

      // Tracks: Index 2 to totalItems - 2
      final trackIndex = _focusedSubtitleTrackIndex - 2;
      if (trackIndex < 0 || trackIndex >= _subtitleTracks.length) return;

      final track = _subtitleTracks[trackIndex];

      await _playerController!.selectSubtitleTrack(track.id);
      setState(() {
        _selectedSubtitleIndex = trackIndex;
        _showSubtitleMenu = false;
      });
      print('[VideoPlayer] Selected subtitle track: ${track.label}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Subtitle: ${track.label}'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.black87,
          ),
        );
      }
    } catch (e) {
      print('[VideoPlayer] Error selecting subtitle track: $e');
    }
  }

  Future<void> _disableSubtitle() async {
    if (_playerController == null) return;

    try {
      // Disable subtitles by passing empty string
      await _playerController!.selectSubtitleTrack("");
      setState(() {
        _selectedSubtitleIndex = -1;
        _showSubtitleMenu = false;
      });
      print('[VideoPlayer] Disabled subtitles');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subtitles: Off'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.black87,
          ),
        );
      }
    } catch (e) {
      print('[VideoPlayer] Error disabling subtitles: $e');
    }
  }

  Future<void> _searchSubtitlesOnline() async {
    setState(() => _showSubtitleMenu = false);

    final result = await showDialog<OpenSubtitleResult>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: const SubtitleSearchDialog(),
      ),
    );

    if (result != null && result.subDownloadLink.isNotEmpty) {
      try {
        // Remove .gz extension as player might not handle compressed subs directly
        final url = result.subDownloadLink.replaceAll('.gz', '');
        print('[VideoPlayer] Loading subtitle from: $url');

        await _playerController!.selectSubtitleTrack(url);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Subtitle loaded: ${result.movieName}'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.black87,
            ),
          );
        }
      } catch (e) {
        print('[VideoPlayer] Error loading subtitle: $e');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error loading subtitle: $e')));
        }
      }
    }
  }

  Future<void> _addSubtitleFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['srt', 'vtt', 'ass', 'ssa'],
      );

      if (result != null && result.files.single.path != null) {
        await _playerController!.selectSubtitleTrack(result.files.single.path!);
        setState(() => _showSubtitleMenu = false);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Subtitle file loaded'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.black87,
            ),
          );
        }
      }
    } catch (e) {
      print('[VideoPlayer] Error adding subtitle: $e');
    }
  }

  Future<void> _removeSubtitle() async {
    await _disableSubtitle();
  }

  void _toggleServerMenu() {
    if (widget.streams == null || widget.streams!.isEmpty) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No other servers available'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.black87,
          ),
        );
      }
      return;
    }

    setState(() {
      _showServerMenu = !_showServerMenu;
      if (_showServerMenu) {
        _focusedServerIndex = widget.currentStreamIndex ?? 0;
        _controlsHideTimer?.cancel();
      } else {
        _resetControlsHideTimer();
      }
    });
  }

  // Simplified server switching - just re-initializes (implementation might need full logic but this is a start)
  Future<void> _selectServer() async {
    if (_focusedServerIndex < 0) return; // Close button focused
    
    // Implementing server switching would require re-initializing the whole player with new URL
    // For now, we will just close the menu to avoid implementation complexity in this step
    setState(() => _showServerMenu = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Server switching not fully implemented yet in this view',
        ),
      ),
    );
  }

  void _navigateServers(int delta) {
    if (widget.streams == null || widget.streams!.isEmpty) return;
    setState(() {
      int newIndex = _focusedServerIndex + delta;
      final maxIndex = widget.streams!.length - 1;
      if (newIndex < -1) newIndex = maxIndex;
      if (newIndex > maxIndex) newIndex = -1;
      _focusedServerIndex = newIndex;
    });

    if (_focusedServerIndex >= 0 && _serverScrollController.hasClients) {
      const itemHeight = 56.0;
      final targetOffset = _focusedServerIndex * itemHeight;
      _serverScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
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
                          if (event is KeyDownEvent &&
                              event.logicalKey == LogicalKeyboardKey.enter) {
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
                                      ? const BorderSide(
                                          color: Colors.white,
                                          width: 2,
                                        )
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
                          if (event is KeyDownEvent &&
                              event.logicalKey == LogicalKeyboardKey.enter) {
                            VlcLauncher.launchVlc(
                              _currentVideoUrl,
                              widget.title,
                            );
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
                                      ? const BorderSide(
                                          color: Colors.white,
                                          width: 2,
                                        )
                                      : null,
                                ),
                                onPressed: () => VlcLauncher.launchVlc(
                                  _currentVideoUrl,
                                  widget.title,
                                ),
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
        body: const Center(child: CircularProgressIndicator(color: Colors.red)),
      );
    }

    return KeyEventHandler(
      onLeftKey: () {
        if (_showAudioMenu || _showSubtitleMenu || _showServerMenu) return;
        if (_isBackButtonFocused) return; // Can't navigate left/right on back button
        _navigateControls(-1);
      },
      onRightKey: () {
        if (_showAudioMenu || _showSubtitleMenu || _showServerMenu) return;
        if (_isBackButtonFocused) return; // Can't navigate left/right on back button
        _navigateControls(1);
      },
      onUpKey: () {
        if (_showAudioMenu) {
          _navigateAudioTracks(-1);
        } else if (_showSubtitleMenu) {
          _navigateSubtitleTracks(-1);
        } else if (_showServerMenu) {
          _navigateServers(-1);
        } else {
          // Navigate to back button
          setState(() => _isBackButtonFocused = true);
          _resetControlsHideTimer();
        }
      },
      onDownKey: () {
        if (_showAudioMenu) {
          _navigateAudioTracks(1);
        } else if (_showSubtitleMenu) {
          _navigateSubtitleTracks(1);
        } else if (_showServerMenu) {
          _navigateServers(1);
        } else if (_isBackButtonFocused) {
          // Navigate back to controls
          setState(() => _isBackButtonFocused = false);
          _resetControlsHideTimer();
        } else {
          _resetControlsHideTimer();
        }
      },
      onEnterKey: () {
        if (_showAudioMenu) {
          if (_focusedAudioTrackIndex == -1) {
            setState(() => _showAudioMenu = false);
            _resetControlsHideTimer();
          } else {
            _selectAudioTrack();
          }
        } else if (_showSubtitleMenu) {
          if (_focusedSubtitleTrackIndex == -1) {
            setState(() => _showSubtitleMenu = false);
            _resetControlsHideTimer();
          } else {
            _selectSubtitleTrack();
          }
        } else if (_showServerMenu) {
          if (_focusedServerIndex == -1) {
            setState(() => _showServerMenu = false);
            _resetControlsHideTimer();
          } else {
            _selectServer();
          }
        } else if (_isBackButtonFocused) {
          Navigator.pop(context);
        } else {
          _activateFocusedControl();
        }
      },
      onBackKey: () {
        if (_showAudioMenu) {
          setState(() => _showAudioMenu = false);
          _resetControlsHideTimer();
        } else if (_showSubtitleMenu) {
          setState(() => _showSubtitleMenu = false);
          _resetControlsHideTimer();
        } else if (_showServerMenu) {
          setState(() => _showServerMenu = false);
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
                                _errorMessage =
                                    error ?? 'Unknown playback error';
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                // Custom Controls Overlay
                if (_showControls &&
                    !_showAudioMenu &&
                    !_showSubtitleMenu &&
                    !_showServerMenu)
                  Positioned.fill(
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 24,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: _isBackButtonFocused
                                          ? Colors.white.withOpacity(0.2)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      border: _isBackButtonFocused
                                          ? Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            )
                                          : null,
                                    ),
                                    child: InkWell(
                                      onTap: () => Navigator.of(context).pop(),
                                      borderRadius: BorderRadius.circular(12),
                                      child: const Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: Icon(
                                          Icons.arrow_back_rounded,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.title,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 20,
                                            shadows: [
                                              Shadow(
                                                blurRadius: 8,
                                                color: Colors.black54,
                                                offset: Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (_currentServerName.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(
                                                0.15,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              _currentServerName.toUpperCase(),
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(
                                                  0.9,
                                                ),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 10,
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
                                          fontFeatures: [
                                            FontFeature.tabularFigures(),
                                          ],
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                      Expanded(
                                        child: SliderTheme(
                                          data: SliderTheme.of(context).copyWith(
                                            trackHeight: 2,
                                            thumbShape:
                                                const RoundSliderThumbShape(
                                                  enabledThumbRadius: 6,
                                                ),
                                            overlayShape:
                                                const RoundSliderOverlayShape(
                                                  overlayRadius: 16,
                                                ),
                                            activeTrackColor: Colors.white,
                                            inactiveTrackColor: Colors.white24,
                                            thumbColor: Colors.white,
                                            overlayColor: Colors.white
                                                .withOpacity(0.1),
                                            trackShape:
                                                const RectangularSliderTrackShape(),
                                          ),
                                          child: Slider(
                                            value:
                                                _totalDuration.inMilliseconds >
                                                    0
                                                ? _currentPosition
                                                      .inMilliseconds
                                                      .toDouble()
                                                      .clamp(
                                                        0.0,
                                                        _totalDuration
                                                            .inMilliseconds
                                                            .toDouble(),
                                                      )
                                                : 0.0,
                                            min: 0.0,
                                            max:
                                                _totalDuration.inMilliseconds >
                                                    0
                                                ? _totalDuration.inMilliseconds
                                                      .toDouble()
                                                : 1.0,
                                            onChanged: (value) {
                                              if (_playerController != null) {
                                                _playerController!.seekTo(
                                                  Duration(
                                                    milliseconds: value.toInt(),
                                                  ),
                                                );
                                                _resetControlsHideTimer();
                                              }
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
                                          fontFeatures: [
                                            FontFeature.tabularFigures(),
                                          ],
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
                                              isSelected:
                                                  _focusedControlIndex == 0,
                                              onTap: _seekBackward,
                                            ),
                                            const SizedBox(width: 32),
                                            _buildControlButton(
                                              icon: _isPlaying
                                                  ? Icons.pause_rounded
                                                  : Icons.play_arrow_rounded,
                                              label: _isPlaying
                                                  ? 'Pause'
                                                  : 'Play',
                                              isSelected:
                                                  _focusedControlIndex == 1,
                                              onTap: _togglePlayPause,
                                              isPrimary: true,
                                            ),
                                            const SizedBox(width: 32),
                                            _buildControlButton(
                                              icon: Icons.forward_10_rounded,
                                              label: 'Forward 10s',
                                              isSelected:
                                                  _focusedControlIndex == 2,
                                              onTap: _seekForward,
                                            ),
                                          ],
                                        ),

                                        // Left: Servers
                                        Positioned(
                                          left: 0,
                                          child: Opacity(
                                            opacity: (widget.streams == null || widget.streams!.isEmpty) ? 0.5 : 1.0, 
                                            child: _buildControlButton(
                                              icon: Icons.dns_rounded,
                                              label: 'Servers',
                                              isSelected:
                                                  _focusedControlIndex == 5,
                                              onTap: _toggleServerMenu,
                                            ),
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
                                                isSelected:
                                                    _focusedControlIndex == 3,
                                                onTap: _toggleAudioMenu,
                                              ),
                                              const SizedBox(width: 24),
                                              _buildControlButton(
                                                icon: Icons.subtitles_rounded,
                                                label: 'Subtitles',
                                                isSelected:
                                                    _focusedControlIndex == 4,
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

                // Server Menu
                if (_showServerMenu)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black54,
                      alignment: Alignment.center,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 400,
                          maxHeight: 500,
                        ),
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
                                    Container(
                                      decoration: BoxDecoration(
                                        color: _focusedServerIndex == -1
                                            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                        border: _focusedServerIndex == -1
                                            ? Border.all(
                                                color: Theme.of(context).colorScheme.primary,
                                                width: 2,
                                              )
                                            : null,
                                      ),
                                      child: IconButton(
                                        onPressed: () => setState(
                                          () => _showServerMenu = false,
                                        ),
                                        icon: const Icon(Icons.close_rounded),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                if (widget.streams == null ||
                                    widget.streams!.isEmpty)
                                  const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(32.0),
                                      child: Text('No servers available'),
                                    ),
                                  )
                                else
                                  Flexible(
                                    child: ListView.builder(
                                      padding: const EdgeInsets.only(top: 8),
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

                // Audio Track Menu
                if (_showAudioMenu)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black54,
                      alignment: Alignment.center,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 400,
                          maxHeight: 500,
                        ),
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
                                    Container(
                                      decoration: BoxDecoration(
                                        color: _focusedAudioTrackIndex == -1
                                            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                        border: _focusedAudioTrackIndex == -1
                                            ? Border.all(
                                                color: Theme.of(context).colorScheme.primary,
                                                width: 2,
                                              )
                                            : null,
                                      ),
                                      child: IconButton(
                                        onPressed: () => setState(
                                          () => _showAudioMenu = false,
                                        ),
                                        icon: const Icon(Icons.close_rounded),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
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
                                      padding: const EdgeInsets.only(top: 8),
                                      controller: _audioScrollController,
                                      shrinkWrap: true,
                                      itemCount: _audioTracks.length,
                                      itemBuilder: (context, index) {
                                        final track = _audioTracks[index];
                                        final isFocused = index == _focusedAudioTrackIndex;
                                        final isActive = index == _selectedAudioIndex;
                                        final colorScheme = Theme.of(context).colorScheme;

                                        String label = track.label ?? 'Track ${index + 1}';
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
                                            leading: isActive 
                                                ? Icon(Icons.check_circle_rounded, color: colorScheme.primary)
                                                : const Icon(Icons.audiotrack, size: 20),
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

                // Subtitle Track Menu
                if (_showSubtitleMenu)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black54,
                      alignment: Alignment.center,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 400,
                          maxHeight: 500,
                        ),
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
                                    Container(
                                      decoration: BoxDecoration(
                                        color: _focusedSubtitleTrackIndex == -1
                                            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                        border: _focusedSubtitleTrackIndex == -1
                                            ? Border.all(
                                                color: Theme.of(context).colorScheme.primary,
                                                width: 2,
                                              )
                                            : null,
                                      ),
                                      child: IconButton(
                                        onPressed: () => setState(
                                          () => _showSubtitleMenu = false,
                                        ),
                                        icon: const Icon(Icons.close_rounded),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                Flexible(
                                  child: ListView.builder(
                                    padding: const EdgeInsets.only(top: 8),
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
                                        label = track.label ?? 'Track ${trackIndex + 1}';
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
            color: isSelected
                ? Colors.black
                : Colors.white.withOpacity(isPrimary ? 1.0 : 0.8),
            size: isPrimary ? 42 : 26,
            shadows: isSelected
                ? []
                : [Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 4)],
          ),
        ),
      ),
    );
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

  // Focus management: -1=close, 0=query, 1=language, 2=season, 3=episode, 4=search button, 5+=results
  int _focusedElementIndex = 0;
  final ScrollController _resultsScrollController = ScrollController();

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
    _resultsScrollController.dispose();
    super.dispose();
  }

  void _navigateElements(int delta) {
    setState(() {
      final maxResultIndex = _searchResults.isEmpty ? 4 : 4 + _searchResults.length;
      int newIndex = _focusedElementIndex + delta;
      if (newIndex < -1) newIndex = maxResultIndex;
      if (newIndex > maxResultIndex) newIndex = -1;
      _focusedElementIndex = newIndex;
    });

    // Auto-scroll results if focused
    if (_focusedElementIndex > 4 && _resultsScrollController.hasClients) {
      final resultIndex = _focusedElementIndex - 5;
      final itemHeight = 72.0; // Approximate ListTile height
      final targetOffset = resultIndex * itemHeight;
      _resultsScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }

  void _activateFocusedElement() {
    if (_focusedElementIndex == -1) {
      Navigator.of(context).pop();
    } else if (_focusedElementIndex == 4) {
      if (!_isLoading) _search();
    } else if (_focusedElementIndex > 4) {
      final resultIndex = _focusedElementIndex - 5;
      if (resultIndex < _searchResults.length) {
        Navigator.of(context).pop(_searchResults[resultIndex]);
      }
    }
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

    return KeyEventHandler(
      onUpKey: () => _navigateElements(-1),
      onDownKey: () => _navigateElements(1),
      onEnterKey: _activateFocusedElement,
      onBackKey: () => Navigator.of(context).pop(),
      child: Dialog(
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
                  Container(
                    decoration: _focusedElementIndex == -1
                        ? BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: colorScheme.primary,
                              width: 2,
                            ),
                          )
                        : null,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
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
                    child: Container(
                      decoration: _focusedElementIndex == 0
                          ? BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: colorScheme.primary,
                                width: 2,
                              ),
                            )
                          : null,
                      child: TextField(
                        controller: _queryController,
                        decoration: const InputDecoration(
                          labelText: 'Name or IMDB ID',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                        ),
                        onSubmitted: (_) => _search(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Container(
                      decoration: _focusedElementIndex == 1
                          ? BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: colorScheme.primary,
                                width: 2,
                              ),
                            )
                          : null,
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedLanguageId,
                        decoration: const InputDecoration(
                          labelText: 'Language',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                        ),
                        menuMaxHeight: 400,
                        items: _languages.map((lang) {
                          return DropdownMenuItem(
                            value: lang['id'],
                            child: Text(
                              lang['name']!,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedLanguageId = value);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: _focusedElementIndex == 2
                          ? BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: colorScheme.primary,
                                width: 2,
                              ),
                            )
                          : null,
                      child: TextField(
                        controller: _seasonController,
                        decoration: const InputDecoration(
                          labelText: 'Season',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        onSubmitted: (_) => _search(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: _focusedElementIndex == 3
                          ? BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: colorScheme.primary,
                                width: 2,
                              ),
                            )
                          : null,
                      child: TextField(
                        controller: _episodeController,
                        decoration: const InputDecoration(
                          labelText: 'Episode',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        onSubmitted: (_) => _search(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: _focusedElementIndex == 4
                        ? BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: colorScheme.primary,
                              width: 2,
                            ),
                          )
                        : null,
                    child: FilledButton.icon(
                      onPressed: _isLoading ? null : _search,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.search_rounded),
                      label: const Text('Search'),
                    ),
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
                            Icon(
                              Icons.error_outline_rounded,
                              color: colorScheme.error,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _error,
                              style: TextStyle(color: colorScheme.error),
                            ),
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
                        controller: _resultsScrollController,
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final result = _searchResults[index];
                          final seasonText =
                              (int.tryParse(result.seriesSeason) ?? 0) > 0
                              ? 'S${result.seriesSeason}'
                              : '';
                          final episodeText =
                              (int.tryParse(result.seriesEpisode) ?? 0) > 0
                              ? 'E${result.seriesEpisode}'
                              : '';
                          final seInfo = [
                            seasonText,
                            episodeText,
                          ].where((t) => t.isNotEmpty).join(' ');

                          final isFocused = _focusedElementIndex == 5 + index;
                          return Container(
                            decoration: isFocused
                                ? BoxDecoration(
                                    color: colorScheme.primaryContainer.withOpacity(0.3),
                                    border: Border.all(
                                      color: colorScheme.primary,
                                      width: 2,
                                    ),
                                  )
                                : null,
                            child: ListTile(
                              title: Text(
                                result.movieName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${result.infoReleaseGroup} • ${result.userNickName}',
                                maxLines: 1,
                              ),
                              trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (seInfo.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    margin: const EdgeInsets.only(bottom: 4),
                                    decoration: BoxDecoration(
                                      color: colorScheme.secondary.withOpacity(
                                        0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      seInfo,
                                      style: TextStyle(
                                        color: colorScheme.secondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
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
                                style: TextStyle(
                                  color: colorScheme.onPrimaryContainer,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            onTap: () => Navigator.of(context).pop(result),
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
    );
  }
}
