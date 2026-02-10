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
    const accentColor = Colors.amber;

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
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accentColor.withOpacity(0.3), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
                BoxShadow(
                  color: accentColor.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.movie_filter_rounded, color: accentColor, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      'Select Episode',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(left: 40),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.quality,
                      style: const TextStyle(
                        color: accentColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
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
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: isFocused 
                                ? accentColor 
                                : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isFocused 
                                  ? accentColor 
                                  : Colors.transparent,
                              width: 1,
                            ),
                             boxShadow: isFocused
                              ? [
                                  BoxShadow(
                                    color: accentColor.withOpacity(0.4),
                                    blurRadius: 12,
                                    spreadRadius: 1,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : [],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isFocused ? Icons.play_circle_filled : Icons.play_circle_outline,
                                color: isFocused ? Colors.black : Colors.white70,
                                size: 24,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  episode.title,
                                  style: TextStyle(
                                    color: isFocused ? Colors.black : Colors.white70,
                                    fontSize: 16,
                                    fontWeight: isFocused ? FontWeight.bold : FontWeight.w500,
                                  ),
                                ),
                              ),
                             if (isFocused)
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: Colors.black.withOpacity(0.8),
                                  size: 16,
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
