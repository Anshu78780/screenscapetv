// Streaming Links Dialog with Key Navigation
import 'package:flutter/material.dart';
import '../provider/drive/hubcloud_extractor.dart';
import '../utils/key_event_handler.dart';
import '../screens/video_player_screen.dart';

class StreamingLinksDialog extends StatefulWidget {
  final List<Stream> streams;
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
  int _selectedIndex = 0;

  void _navigate(int delta) {
    setState(() {
      _selectedIndex = (_selectedIndex + delta) % widget.streams.length;
      if (_selectedIndex < 0) {
        _selectedIndex = widget.streams.length - 1;
      }
    });
  }

  void _playSelectedStream() {
    final selectedStream = widget.streams[_selectedIndex];
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



  @override
  Widget build(BuildContext context) {
    return KeyEventHandler(
      onUpKey: () => _navigate(-1),
      onDownKey: () => _navigate(1),
      onBackKey: () => Navigator.of(context).pop(),
      onEnterKey: _playSelectedStream,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            margin: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.3), width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.red.withOpacity(0.3), Colors.transparent],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.video_library, color: Colors.red, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select Server',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              widget.quality,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Streams list
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: widget.streams.asMap().entries.map((entry) {
                        final index = entry.key;
                        final stream = entry.value;
                        final isSelected = index == _selectedIndex;
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            transform: Matrix4.identity()..scale(isSelected ? 1.02 : 1.0),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isSelected
                                    ? [Colors.red.withOpacity(0.9), Colors.red.shade700]
                                    : [Colors.grey[850]!, Colors.grey[900]!],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.red.withOpacity(0.3),
                                width: isSelected ? 3 : 1,
                              ),
                              boxShadow: isSelected ? [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.4),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ] : null,
                            ),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.play_circle_outline,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              title: Text(
                                stream.server,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                stream.type.toUpperCase(),
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                ),
                              ),
                              trailing: Icon(
                                Icons.play_arrow,
                                color: isSelected ? Colors.white : Colors.red,
                                size: 32,
                              ),
                              onTap: () {
                                setState(() {
                                  _selectedIndex = index;
                                });
                              },
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                
                // Footer with controls hint
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildHint('↑ ↓', 'Navigate'),
                      const SizedBox(width: 20),
                      _buildHint('Enter ⏎', 'Play'),
                      const SizedBox(width: 20),
                      _buildHint('Back', 'Close'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHint(String key, String action) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.red.withOpacity(0.5)),
          ),
          child: Text(
            key,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          action,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
