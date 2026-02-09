// Streaming Links Dialog with Key Navigation
import 'dart:io' show Platform, Process, ProcessStartMode;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/key_event_handler.dart';
import '../screens/video_player_screen.dart';
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
    final selectedStream = widget.streams[_selectedStreamIndex];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(
          videoUrl: selectedStream.link,
          title: widget.movieTitle,
          server: selectedStream.server,
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

  Future<void> _openInVLC() async {
    final selectedStream = widget.streams[_selectedStreamIndex];

    try {
      if (kIsWeb) {
        _showSnackBar('VLC is not supported on web platform');
        return;
      }

      if (Platform.isLinux) {
        await _openVLCOnLinux(selectedStream.link);
      } else if (Platform.isAndroid) {
        await _openVLCOnAndroid(selectedStream.link);
      } else if (Platform.isIOS) {
        await _openVLCOnIOS(selectedStream.link);
      } else {
        _showSnackBar('VLC integration not available for this platform');
      }
    } catch (e) {
      _showSnackBar('Error opening VLC: $e');
    }
  }

  Future<void> _openVLCOnLinux(String url) async {
    bool launched = false;

    try {
      await Process.start('vlc', [url], mode: ProcessStartMode.detached);
      launched = true;
      _showSnackBar('Opening in VLC...');
      return;
    } catch (e) {
      print('Standard VLC not found: $e');
    }

    if (!launched) {
      try {
        await Process.start('flatpak', [
          'run',
          'org.videolan.VLC',
          url,
        ], mode: ProcessStartMode.detached);
        launched = true;
        _showSnackBar('Opening in VLC (Flatpak)...');
        return;
      } catch (e) {
        print('Flatpak VLC not found: $e');
      }
    }

    if (!launched) {
      try {
        await Process.start('snap', [
          'run',
          'vlc',
          url,
        ], mode: ProcessStartMode.detached);
        launched = true;
        _showSnackBar('Opening in VLC (Snap)...');
        return;
      } catch (e) {
        print('Snap VLC not found: $e');
      }
    }

    if (!launched) {
      try {
        final whichResult = await Process.run('which', ['vlc']);
        if (whichResult.exitCode == 0 &&
            whichResult.stdout.toString().trim().isNotEmpty) {
          final vlcPath = whichResult.stdout.toString().trim();
          await Process.start(vlcPath, [url], mode: ProcessStartMode.detached);
          launched = true;
          _showSnackBar('Opening in VLC...');
          return;
        }
      } catch (e) {
        print('Which command failed: $e');
      }
    }

    if (!launched) {
      try {
        await Process.start('xdg-open', [url], mode: ProcessStartMode.detached);
        _showSnackBar('Opening video in default player...');
      } catch (e) {
        _showSnackBar(
          'VLC not found. Please install VLC: sudo apt install vlc',
        );
      }
    }
  }

  Future<void> _openVLCOnAndroid(String url) async {
    const platform = MethodChannel('com.example.screenscapetv/vlc');

    try {
      final bool? result = await platform.invokeMethod('launchVLC', {
        'url': url,
        'title': widget.movieTitle,
      });

      if (result == true) {
        _showSnackBar('Opening in VLC...');
        return;
      }
    } catch (e) {
      print('Platform channel failed: $e');
    }

    bool launched = false;

    try {
      final vlcScheme = 'vlc://${Uri.encodeComponent(url)}';
      final vlcUri = Uri.parse(vlcScheme);
      launched = await launchUrl(vlcUri, mode: LaunchMode.externalApplication);
      if (launched) {
        _showSnackBar('Opening in VLC...');
        return;
      }
    } catch (e) {
      print('VLC URL scheme failed: $e');
    }

    try {
      final videoUri = Uri.parse(url);
      launched = await launchUrl(
        videoUri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) {
        _showSnackBar('Opening video (choose VLC from app list)...');
        return;
      }
    } catch (e) {
      print('Direct URL launch failed: $e');
    }

    if (!launched) {
      _showSnackBar(
        'Could not open VLC. Ensure VLC is installed from Play Store.',
      );
    }
  }

  Future<void> _openVLCOnIOS(String url) async {
    try {
      final vlcUri = Uri.parse(
        'vlc-x-callback://x-callback-url/stream?url=${Uri.encodeComponent(url)}',
      );

      if (await canLaunchUrl(vlcUri)) {
        await launchUrl(vlcUri, mode: LaunchMode.externalApplication);
        _showSnackBar('Opening in VLC...');
      } else {
        _showSnackBar('VLC not installed. Please install VLC from App Store.');
      }
    } catch (e) {
      _showSnackBar('Error: VLC app not found');
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
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedStreamIndex = index;
                                      _isVLCSelected = false;
                                    });
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
                              const SizedBox(width: 12),
                              // VLC button
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedStreamIndex = index;
                                    _isVLCSelected = true;
                                  });
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
                                      Image.asset(
                                        'assets/vlc_icon.png',
                                        width: 28,
                                        height: 28,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return Icon(
                                                Icons.live_tv,
                                                color:
                                                    isCurrentStream &&
                                                        _isVLCSelected
                                                    ? Colors.white
                                                    : Colors.orange,
                                                size: 28,
                                              );
                                            },
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

  Widget _buildHint(String key, String action, Color accent) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: accent.withOpacity(0.2)),
          ),
          child: Text(
            key,
            style: TextStyle(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              fontFamily: Platform.isWindows ? 'Segoe UI' : null,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          action,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
