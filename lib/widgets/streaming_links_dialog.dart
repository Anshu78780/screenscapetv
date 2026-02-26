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
  bool _isCloseButtonFocused = false;
  final List<GlobalKey> _itemKeys = [];

  @override
  void initState() {
    super.initState();
    _itemKeys.addAll(List.generate(widget.streams.length, (_) => GlobalKey()));
  }

  void _navigate(int delta) {
    if (_isCloseButtonFocused) {
      // From close button, only down arrow moves to first stream
      if (delta > 0) {
        setState(() {
          _isCloseButtonFocused = false;
          _selectedStreamIndex = 0;
          _isVLCSelected = false;
        });
        _scrollToSelected();
      }
      return;
    }

    setState(() {
      final newIndex = _selectedStreamIndex + delta;
      
      if (newIndex < 0) {
        // Move to close button when going up from first stream
        _isCloseButtonFocused = true;
        _isVLCSelected = false;
      } else if (newIndex >= widget.streams.length) {
        _selectedStreamIndex = widget.streams.length - 1;
      } else {
        _selectedStreamIndex = newIndex;
      }
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
    if (_isCloseButtonFocused) return; // No toggle when close button is focused
    
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
    if (_isCloseButtonFocused) {
      Navigator.of(context).pop();
      return;
    }
    
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
      final colorScheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: TextStyle(color: colorScheme.onError),
          ),
          backgroundColor: colorScheme.error,
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

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return KeyEventHandler(
      onUpKey: () => _navigate(-1),
      onDownKey: () => _navigate(1),
      onLeftKey: () => _isVLCSelected ? _toggleSelection() : null,
      onRightKey: () => !_isVLCSelected ? _toggleSelection() : null,
      onBackKey: () => Navigator.of(context).pop(),
      onEnterKey: _executeAction,
      child: Scaffold(
        backgroundColor: colorScheme.scrim.withOpacity(0.6),
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 700),
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: colorScheme.outlineVariant.withOpacity(0.5),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withOpacity(0.4),
                  blurRadius: 40,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with close button
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 24, 24, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Stream',
                        style: textTheme.headlineSmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            transform: Matrix4.identity()
                              ..scale(_isCloseButtonFocused ? 1.1 : 1.0),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _isCloseButtonFocused
                                  ? colorScheme.errorContainer
                                  : colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _isCloseButtonFocused
                                    ? colorScheme.error
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.close,
                              color: _isCloseButtonFocused
                                  ? colorScheme.onErrorContainer
                                  : colorScheme.onSurfaceVariant,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Divider(
                  color: colorScheme.outlineVariant,
                  height: 1,
                  thickness: 1,
                ),

                // Streams list
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: widget.streams.asMap().entries.map((entry) {
                        final index = entry.key;
                        final stream = entry.value;
                        final isCurrentStream = !_isCloseButtonFocused && index == _selectedStreamIndex;

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
                                      color: isCurrentStream && !_isVLCSelected
                                          ? colorScheme.primaryContainer
                                          : colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isCurrentStream && !_isVLCSelected
                                            ? colorScheme.primary
                                            : Colors.transparent,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isCurrentStream && !_isVLCSelected
                                              ? Icons.play_circle_filled
                                              : Icons.play_circle_outline,
                                          color:
                                              isCurrentStream && !_isVLCSelected
                                              ? colorScheme.onPrimaryContainer
                                              : colorScheme.onSurfaceVariant,
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
                                                style: textTheme.titleMedium?.copyWith(
                                                  color:
                                                      isCurrentStream &&
                                                          !_isVLCSelected
                                                      ? colorScheme.onPrimaryContainer
                                                      : colorScheme.onSurface,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                stream.type.toUpperCase(),
                                                style: textTheme.labelSmall?.copyWith(
                                                  color:
                                                      isCurrentStream &&
                                                          !_isVLCSelected
                                                      ? colorScheme.onPrimaryContainer.withOpacity(0.8)
                                                      : colorScheme.onSurfaceVariant,
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
                                              color: colorScheme.onPrimaryContainer.withOpacity(0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.arrow_forward_ios_rounded,
                                              color: colorScheme.onPrimaryContainer,
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
                                        ? colorScheme.tertiaryContainer
                                        : colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isCurrentStream && _isVLCSelected
                                          ? colorScheme.tertiary
                                          : Colors.transparent,
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.open_in_new,
                                        color: isCurrentStream && _isVLCSelected
                                            ? colorScheme.onTertiaryContainer
                                            : colorScheme.tertiary,
                                        size: 28,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'VLC',
                                        style: textTheme.labelSmall?.copyWith(
                                          color:
                                              isCurrentStream && _isVLCSelected
                                              ? colorScheme.onTertiaryContainer
                                              : colorScheme.onSurfaceVariant,
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
