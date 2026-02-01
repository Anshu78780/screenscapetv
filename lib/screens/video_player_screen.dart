import 'dart:io';
import 'package:flutter/material.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:video_player/video_player.dart';
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
  BetterPlayerController? _betterPlayerController;
  VideoPlayerController? _videoPlayerController;
  bool _isControlsVisible = true;
  bool _isLinux = Platform.isLinux;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  void _initializePlayer() {
    if (_isLinux) {
      // Use video_player for Linux
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
        ..initialize().then((_) {
          setState(() {});
          _videoPlayerController!.play();
        });
    } else {
      // Use better_player_plus for other platforms
      BetterPlayerDataSource betterPlayerDataSource = BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        widget.videoUrl,
        notificationConfiguration: BetterPlayerNotificationConfiguration(
          showNotification: true,
          title: widget.title,
          author: widget.server,
        ),
      );

      _betterPlayerController = BetterPlayerController(
        const BetterPlayerConfiguration(
          autoPlay: true,
          looping: false,
          fullScreenByDefault: false,
          controlsConfiguration: BetterPlayerControlsConfiguration(
            enablePlayPause: true,
            enableMute: true,
            enableFullscreen: true,
            enableProgressBar: true,
            enableProgressText: true,
            enableProgressBarDrag: true,
            showControlsOnInitialize: true,
          ),
        ),
        betterPlayerDataSource: betterPlayerDataSource,
      );
    }
  }

  void _togglePlayPause() {
    if (_isLinux) {
      if (_videoPlayerController?.value.isPlaying ?? false) {
        _videoPlayerController?.pause();
      } else {
        _videoPlayerController?.play();
      }
    } else {
      if (_betterPlayerController?.isPlaying() ?? false) {
        _betterPlayerController?.pause();
      } else {
        _betterPlayerController?.play();
      }
    }
  }

  void _seekForward() {
    if (_isLinux) {
      final currentPosition = _videoPlayerController?.value.position;
      if (currentPosition != null) {
        final newPosition = currentPosition + const Duration(seconds: 10);
        _videoPlayerController?.seekTo(newPosition);
      }
    } else {
      final currentPosition = _betterPlayerController?.videoPlayerController?.value.position;
      if (currentPosition != null) {
        final newPosition = currentPosition + const Duration(seconds: 10);
        _betterPlayerController?.seekTo(newPosition);
      }
    }
  }

  void _seekBackward() {
    if (_isLinux) {
      final currentPosition = _videoPlayerController?.value.position;
      if (currentPosition != null) {
        final newPosition = currentPosition - const Duration(seconds: 10);
        _videoPlayerController?.seekTo(newPosition > Duration.zero ? newPosition : Duration.zero);
      }
    } else {
      final currentPosition = _betterPlayerController?.videoPlayerController?.value.position;
      if (currentPosition != null) {
        final newPosition = currentPosition - const Duration(seconds: 10);
        _betterPlayerController?.seekTo(newPosition > Duration.zero ? newPosition : Duration.zero);
      }
    }
  }

  void _toggleControls() {
    setState(() {
      _isControlsVisible = !_isControlsVisible;
    });
  }

  @override
  void dispose() {
    _betterPlayerController?.dispose();
    _videoPlayerController?.dispose();
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
                child: _isLinux
                    ? (_videoPlayerController?.value.isInitialized ?? false)
                        ? VideoPlayer(_videoPlayerController!)
                        : const Center(
                            child: CircularProgressIndicator(color: Colors.red),
                          )
                    : BetterPlayer(
                        controller: _betterPlayerController!,
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
