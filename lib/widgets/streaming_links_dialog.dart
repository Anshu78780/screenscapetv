// Streaming Links Dialog with Key Navigation
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../utils/key_event_handler.dart';
import '../utils/vlc_launcher.dart';
import '../screens/video_player_screen.dart';
import '../screens/linux_video_player_screen.dart';
import '../provider/extractors/stream_types.dart' as stream_types;

class StreamingLinksDialog extends StatefulWidget {
  final List<stream_types.Stream> streams;
  final String quality;
  final String movieTitle;

  const StreamingLinksDialog({
    super.key,
    required this.streams,
    required this.quality,
    required this.movieTitle,
  });

  @override
  State<StreamingLinksDialog> createState() => _StreamingLinksDialogState();
}

class _StreamingLinksDialogState extends State<StreamingLinksDialog> {
  int _selectedStreamIndex = 0;
  bool _isVLCSelected = false; // false = stream button, true = VLC button
  final List<GlobalKey> _itemKeys = [];

  @override
  void initState() {
    super.initState();
    _itemKeys.addAll(List.generate(widget.streams.length, (_) => GlobalKey()));
  }

  void _navigate(int delta) {
    setState(() {
      _selectedStreamIndex = (_selectedStreamIndex + delta).clamp(
        0,
        widget.streams.length - 1,
      );
    });
    _scrollToSelected();
  }

  void _scrollToSelected() {
    if (_selectedStreamIndex >= 0 && _selectedStreamIndex < _itemKeys.length) {
      final context = _itemKeys[_selectedStreamIndex].currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          alignment: 0.5,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _toggleSelection() {
    setState(() {
      _isVLCSelected = !_isVLCSelected;
    });
  }

  void _playSelectedStream() {
    if (!kIsWeb && Platform.isLinux) {
      // Use custom media_kit player on Linux
      _openInLinuxPlayer();
      return;
    }

    final selectedStream = widget.streams[_selectedStreamIndex];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(
          videoUrl: selectedStream.link,
          title: widget.movieTitle,
          server: selectedStream.server,
          headers: selectedStream.headers,
          streams: widget.streams,
          currentStreamIndex: _selectedStreamIndex,
        ),
      ),
    );
  }

  void _executeAction() {
    if (_isVLCSelected) {
      _openInVLC();
    } else {
      _playSelectedStream();
    }
  }

  Future<void> _openInLinuxPlayer() async {
    final selectedStream = widget.streams[_selectedStreamIndex];

    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LinuxVideoPlayerScreen(
            videoUrl: selectedStream.link,
            title: widget.movieTitle,
            server: selectedStream.server,
            headers: selectedStream.headers,
            streams: widget.streams,
            currentStreamIndex: _selectedStreamIndex,
          ),
        ),
      );
    } catch (e) {
      _showSnackBar('Failed to open player: $e');
    }
  }

  Future<void> _openInVLC() async {
    final selectedStream = widget.streams[_selectedStreamIndex];

    try {
      if (kIsWeb) {
        _showSnackBar('VLC is not supported on web platform');
        return;
      }

      _showSnackBar('Opening in VLC...');
      await VlcLauncher.launchVlc(selectedStream.link, widget.movieTitle);
    } catch (e) {
      _showSnackBar(e.toString());
    }
  }



  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade900,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Handle hot reload and stream updates by syncing keys
    if (_itemKeys.length != widget.streams.length) {
      _itemKeys.clear();
      _itemKeys.addAll(
        List.generate(widget.streams.length, (_) => GlobalKey()),
      );
    }

    const kGoldColor = Color(0xFFFFD700);
    const kDarkBackground = Color(0xFF141414);
    const kSurfaceColor = Color(0xFF2C2C2C);

    return KeyEventHandler(
      onUpKey: () => _navigate(-1),
      onDownKey: () => _navigate(1),
      onLeftKey: () => _isVLCSelected ? _toggleSelection() : null,
      onRightKey: () => !_isVLCSelected ? _toggleSelection() : null,
      onBackKey: () => Navigator.of(context).pop(),
      onEnterKey: _executeAction,
      child: Scaffold(
        backgroundColor: Colors.black.withOpacity(0.95),
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 700),
            margin: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: kDarkBackground,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: kGoldColor.withOpacity(0.15),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.8),
                  blurRadius: 40,
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: kGoldColor.withOpacity(0.05),
                  blurRadius: 100,
                  spreadRadius: -20,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 20),

                // Streams list
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: widget.streams.asMap().entries.map((entry) {
                        final index = entry.key;
                        final stream = entry.value;
                        final isCurrentStream = index == _selectedStreamIndex;

                        return Padding(
                          key: _itemKeys[index],
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            children: [
                              // Main stream button
                              Expanded(
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedStreamIndex = index;
                                        _isVLCSelected = false;
                                      });
                                      _playSelectedStream();
                                    },
                                    child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeOutCubic,
                                    transform: Matrix4.identity()
                                      ..scale(
                                        isCurrentStream && !_isVLCSelected
                                            ? 1.02
                                            : 1.0,
                                      ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient:
                                          isCurrentStream && !_isVLCSelected
                                          ? const LinearGradient(
                                              colors: [
                                                kGoldColor,
                                                Color(0xFFD4AF37),
                                              ],
                                              begin: Alignment.centerLeft,
                                              end: Alignment.centerRight,
                                            )
                                          : LinearGradient(
                                              colors: [
                                                kSurfaceColor,
                                                kSurfaceColor.withOpacity(0.8),
                                              ],
                                              begin: Alignment.centerLeft,
                                              end: Alignment.centerRight,
                                            ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color:
                                            isCurrentStream && !_isVLCSelected
                                            ? Colors.white.withOpacity(0.5)
                                            : Colors.transparent,
                                        width: 1,
                                      ),
                                      boxShadow:
                                          isCurrentStream && !_isVLCSelected
                                          ? [
                                              BoxShadow(
                                                color: kGoldColor.withOpacity(
                                                  0.3,
                                                ),
                                                blurRadius: 20,
                                                offset: const Offset(0, 8),
                                              ),
                                            ]
                                          : [],
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isCurrentStream && !_isVLCSelected
                                              ? Icons.play_circle_filled
                                              : Icons.play_circle_outline,
                                          color:
                                              isCurrentStream && !_isVLCSelected
                                              ? Colors.black
                                              : Colors.white54,
                                          size: 26,
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                stream.server,
                                                style: TextStyle(
                                                  color:
                                                      isCurrentStream &&
                                                          !_isVLCSelected
                                                      ? Colors.black
                                                      : Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                stream.type.toUpperCase(),
                                                style: TextStyle(
                                                  color:
                                                      isCurrentStream &&
                                                          !_isVLCSelected
                                                      ? Colors.black87
                                                      : Colors.white38,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isCurrentStream && !_isVLCSelected)
                                          Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(
                                                0.1,
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.arrow_forward_ios_rounded,
                                              color: Colors.black54,
                                              size: 14,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              ),
                              const SizedBox(width: 12),
                              // VLC button
                              MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedStreamIndex = index;
                                      _isVLCSelected = true;
                                    });
                                    _openInVLC();
                                  },
                                  child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOutCubic,
                                  transform: Matrix4.identity()
                                    ..scale(
                                      isCurrentStream && _isVLCSelected
                                          ? 1.05
                                          : 1.0,
                                    ),
                                  width: 80,
                                  height: 76,
                                  decoration: BoxDecoration(
                                    color: isCurrentStream && _isVLCSelected
                                        ? const Color(
                                            0xFFE85E00,
                                          ) // Vibrant orange
                                        : kSurfaceColor,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isCurrentStream && _isVLCSelected
                                          ? Colors.white.withOpacity(0.3)
                                          : Colors.transparent,
                                      width: 1,
                                    ),
                                    boxShadow: isCurrentStream && _isVLCSelected
                                        ? [
                                            BoxShadow(
                                              color: const Color(
                                                0xFFE85E00,
                                              ).withOpacity(0.4),
                                              blurRadius: 16,
                                              offset: const Offset(0, 4),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.open_in_new,
                                        color: isCurrentStream && _isVLCSelected
                                            ? Colors.white
                                            : Colors.orange,
                                        size: 28,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'VLC',
                                        style: TextStyle(
                                          color:
                                              isCurrentStream && _isVLCSelected
                                              ? Colors.white
                                              : Colors.white38,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            ],
                          ),
                        );
                      }).toList(),
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
