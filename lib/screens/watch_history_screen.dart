import 'package:flutter/material.dart';
import '../utils/key_event_handler.dart';
import '../utils/watch_history_storage.dart';
import '../models/movie_info.dart';
import 'info.dart';

class WatchHistoryScreen extends StatefulWidget {
  const WatchHistoryScreen({super.key});

  @override
  State<WatchHistoryScreen> createState() => _WatchHistoryScreenState();
}

class _WatchHistoryScreenState extends State<WatchHistoryScreen> {
  List<WatchHistoryItem> _items = [];
  bool _isLoading = true;
  int _focusedIndex = 0;
  bool _isBackButtonFocused = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final items = await WatchHistoryStorage.getItems();
    if (!mounted) return;
    setState(() {
      _items = items;
      _isLoading = false;
      if (_focusedIndex >= _items.length) {
        _focusedIndex = _items.isEmpty ? 0 : _items.length - 1;
      }
    });
  }

  int _crossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width < 600 ? 3 : 7;
  }

  void _navigateHorizontal(int delta) {
    if (_items.isEmpty) return;

    final crossAxisCount = _crossAxisCount(context);
    setState(() {
      final currentRow = _focusedIndex ~/ crossAxisCount;
      final currentCol = _focusedIndex % crossAxisCount;
      final newCol = currentCol + delta;

      if (newCol >= 0 && newCol < crossAxisCount) {
        final newIndex = currentRow * crossAxisCount + newCol;
        if (newIndex < _items.length) {
          _focusedIndex = newIndex;
        }
      } else if (newCol < 0) {
        if (currentRow > 0) {
          final newIndex =
              (currentRow - 1) * crossAxisCount + (crossAxisCount - 1);
          _focusedIndex = newIndex < _items.length
              ? newIndex
              : _items.length - 1;
        }
      } else {
        final newIndex = (currentRow + 1) * crossAxisCount;
        if (newIndex < _items.length) {
          _focusedIndex = newIndex;
        }
      }
    });
    _scrollToFocused();
  }

  void _navigateVertical(int delta) {
    if (_items.isEmpty) return;

    final crossAxisCount = _crossAxisCount(context);
    final totalRows = (_items.length / crossAxisCount).ceil();
    final currentRow = _focusedIndex ~/ crossAxisCount;

    if (delta < 0) {
      if (currentRow > 0) {
        setState(() {
          _focusedIndex -= crossAxisCount;
        });
      }
    } else {
      if (currentRow < totalRows - 1) {
        final newIndex = _focusedIndex + crossAxisCount;
        setState(() {
          _focusedIndex = newIndex < _items.length
              ? newIndex
              : _items.length - 1;
        });
      }
    }

    _scrollToFocused();
  }

  void _scrollToFocused() {
    if (!_scrollController.hasClients) return;

    final crossAxisCount = _crossAxisCount(context);
    const itemHeight = 340.0;
    final row = _focusedIndex ~/ crossAxisCount;
    final target = row * itemHeight;
    final viewport = _scrollController.position.viewportDimension;
    final current = _scrollController.offset;

    if (target < current || target > current + viewport - itemHeight) {
      _scrollController.animateTo(
        target - (viewport / 3),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _removeFocused() async {
    if (_items.isEmpty) return;
    final item = _items[_focusedIndex];
    await WatchHistoryStorage.removeItem(item.movieUrl);
    await _loadHistory();
  }

  void _openFocused() {
    if (_items.isEmpty) return;
    final item = _items[_focusedIndex];
    final movieUrl = item.movieUrl;
    if (movieUrl.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => InfoScreen(movieUrl: movieUrl)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KeyEventHandler(
      onLeftKey: () {
        if (_isBackButtonFocused) return;
        _navigateHorizontal(-1);
      },
      onRightKey: () {
        if (_isBackButtonFocused) return;
        _navigateHorizontal(1);
      },
      onUpKey: () {
        if (_isBackButtonFocused) return;

        final isTopGridRow =
            _items.isNotEmpty && _focusedIndex < _crossAxisCount(context);
        if (isTopGridRow || _items.isEmpty) {
          setState(() => _isBackButtonFocused = true);
          return;
        }

        _navigateVertical(-1);
      },
      onDownKey: () {
        if (_isBackButtonFocused) {
          setState(() => _isBackButtonFocused = false);
          return;
        }
        _navigateVertical(1);
      },
      onEnterKey: () {
        if (_isBackButtonFocused) {
          Navigator.of(context).pop();
          return;
        }
        _openFocused();
      },
      onBackKey: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          leadingWidth: 64,
          leading: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isBackButtonFocused
                      ? const Color(0xFFFFC107)
                      : Colors.transparent,
                  width: 2,
                ),
                color: _isBackButtonFocused
                    ? const Color(0xFFFFC107).withOpacity(0.15)
                    : Colors.transparent,
              ),
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
              ),
            ),
          ),
          title: const Text('Watch History'),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.amber))
            : _items.isEmpty
                ? Center(
                    child: Text(
                      'Watch history is empty',
                      style: TextStyle(color: Colors.grey[500], fontSize: 18),
                    ),
                  )
                : GridView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(30, 24, 30, 50),
                    clipBehavior: Clip.hardEdge,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _crossAxisCount(context),
                      childAspectRatio: 0.62,
                      crossAxisSpacing:
                          MediaQuery.of(context).size.width < 600 ? 16 : 35,
                      mainAxisSpacing:
                          MediaQuery.of(context).size.width < 600 ? 20 : 42,
                    ),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final isFocused = index == _focusedIndex;
                      return _buildHistoryCard(item, isFocused);
                    },
                  ),
      ),
    );
  }

  Widget _buildHistoryCard(WatchHistoryItem item, bool isFocused) {
    final imageUrl = item.imageUrl;

    return Material(
      color: Colors.transparent,
      elevation: isFocused ? 20 : 0,
      borderRadius: BorderRadius.circular(16),
      child: GestureDetector(
        onTap: _openFocused,
        onLongPress: _removeFocused,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          transformAlignment: Alignment.center,
          transform: Matrix4.identity()..scale(isFocused ? 1.08 : 1.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: isFocused
                ? [
                    BoxShadow(
                      color: const Color(0xFFFFC107).withOpacity(0.3),
                      blurRadius: 25,
                      spreadRadius: -5,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[900],
                          child: const Icon(
                            Icons.broken_image,
                            color: Colors.white24,
                            size: 40,
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.grey[900],
                        child: const Icon(
                          Icons.movie,
                          color: Colors.white24,
                          size: 40,
                        ),
                      ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.0),
                        Colors.black.withOpacity(0.6),
                        Colors.black.withOpacity(0.95),
                      ],
                      stops: const [0.0, 0.5, 0.75, 1.0],
                    ),
                  ),
                ),
                if (isFocused)
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFFFC107),
                        width: 3,
                      ),
                    ),
                  ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () async {
                      await WatchHistoryStorage.removeItem(item.movieUrl);
                      await _loadHistory();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFC107),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.provider.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.title,
                        style: TextStyle(
                          color: isFocused ? Colors.white : Colors.white70,
                          fontSize: isFocused ? 14 : 13,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                          shadows: [
                            Shadow(
                              blurRadius: 2,
                              color: Colors.black.withOpacity(0.8),
                              offset: const Offset(1, 1),
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
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
}
