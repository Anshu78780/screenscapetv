import 'package:flutter/material.dart';
import '../models/movie_info.dart';
import '../utils/key_event_handler.dart';

class EpisodeSelectionDialog extends StatefulWidget {
  final List<Episode> episodes;
  final String quality;

  const EpisodeSelectionDialog({
    super.key,
    required this.episodes,
    required this.quality,
  });

  @override
  State<EpisodeSelectionDialog> createState() => _EpisodeSelectionDialogState();
}

class _EpisodeSelectionDialogState extends State<EpisodeSelectionDialog> {
  final ScrollController _scrollController = ScrollController();
  int _focusedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return KeyEventHandler(
      onUpKey: () {
        if (_focusedIndex > 0) {
          setState(() => _focusedIndex--);
          _scrollToFocused();
        }
      },
      onDownKey: () {
        if (_focusedIndex < widget.episodes.length - 1) {
          setState(() => _focusedIndex++);
          _scrollToFocused();
        }
      },
      onEnterKey: () {
        Navigator.pop(context, widget.episodes[_focusedIndex]);
      },
      onBackKey: () {
        Navigator.pop(context, null);
      },
      child: Scaffold(
        backgroundColor: Colors.black.withOpacity(0.9),
        body: Center(
          child: Container(
            width: 400,
            constraints: const BoxConstraints(maxHeight: 600),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Episode',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.quality,
                  style: const TextStyle(
                    color: Colors.tealAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: widget.episodes.length,
                    itemBuilder: (context, index) {
                      final episode = widget.episodes[index];
                      final isFocused = index == _focusedIndex;
                      
                      return GestureDetector(
                        onTap: () => Navigator.pop(context, episode),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isFocused 
                                ? Colors.tealAccent.withOpacity(0.2) 
                                : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isFocused 
                                  ? Colors.tealAccent 
                                  : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.play_circle_outline,
                                color: isFocused ? Colors.tealAccent : Colors.white70,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  episode.title,
                                  style: TextStyle(
                                    color: isFocused ? Colors.white : Colors.white70,
                                    fontSize: 16,
                                    fontWeight: isFocused ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
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

  void _scrollToFocused() {
    if (_scrollController.hasClients) {
      const itemHeight = 60.0; // Approx height + margin
      final targetOffset = _focusedIndex * itemHeight;
      final viewportHeight = _scrollController.position.viewportDimension;
      
      if (targetOffset < _scrollController.offset) {
         _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      } else if (targetOffset + itemHeight > _scrollController.offset + viewportHeight) {
        _scrollController.animateTo(
          targetOffset + itemHeight - viewportHeight,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    }
  }
}
