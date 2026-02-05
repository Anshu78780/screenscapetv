import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../utils/key_event_handler.dart';

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
  late final Player _player;
  late final VideoController _videoController;
  bool _isControlsVisible = true;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  void _initializePlayer() async {
    _player = Player();
    _videoController = VideoController(_player);
    
    await _player.open(Media(widget.videoUrl));
    await _player.play();
    
    setState(() {
      _isInitialized = true;
    });
  }

  void _togglePlayPause() {
    if (_player.state.playing) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  void _seekForward() {
    final currentPosition = _player.state.position;
    final newPosition = currentPosition + const Duration(seconds: 10);
    _player.seek(newPosition);
  }

  void _seekBackward() {
    final currentPosition = _player.state.position;
    final newPosition = currentPosition - const Duration(seconds: 10);
    _player.seek(newPosition > Duration.zero ? newPosition : Duration.zero);
  }

  void _toggleControls() {
    setState(() {
      _isControlsVisible = !_isControlsVisible;
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyEventHandler(
      onEnterKey: _togglePlayPause,
      onRightKey: _seekForward,
      onLeftKey: _seekBackward,
      onUpKey: () {
        // Increase volume or show controls
        _toggleControls();
      },
      onDownKey: () {
        // Decrease volume or hide controls
        _toggleControls();
      },
      onBackKey: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: _isInitialized
                    ? Video(controller: _videoController)
                    : const Center(
                        child: CircularProgressIndicator(color: Colors.red),
                      ),
              ),
            ),
            
            // Top bar with info
            if (_isControlsVisible)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(width: 10),
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
                                  'Server: ${widget.server}',
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
                    ],
                  ),
                ),
              ),
            
            // Bottom controls hint
            if (_isControlsVisible)
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildControlHint(Icons.play_arrow, 'Play/Pause (Enter)'),
                      const SizedBox(width: 20),
                      _buildControlHint(Icons.fast_rewind, '-10s (←)'),
                      const SizedBox(width: 20),
                      _buildControlHint(Icons.fast_forward, '+10s (→)'),
                      const SizedBox(width: 20),
                      _buildControlHint(Icons.arrow_back, 'Back (Back)'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlHint(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.red, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
