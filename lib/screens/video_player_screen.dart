import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tha_player/tha_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../provider/extractors/stream_types.dart' as stream_types;
import '../utils/vlc_launcher.dart';

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

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _currentVideoUrl = widget.videoUrl;
    _currentServerName = widget.server;
    _currentHeaders = widget.headers;
    
    WakelockPlus.enable();
    _initializePlayer();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    WakelockPlus.disable();
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
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: ThaModernPlayer(
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
    );
  }
}
