import 'package:flutter/material.dart';
import '../provider/provider_manager.dart';
import '../screens/global_search_screen.dart';
// import '../screens/extractor_test_screen.dart';

class Sidebar extends StatefulWidget {
  final String selectedProvider;
  final int focusedIndex;
  final Function(String) onProviderSelected;

  const Sidebar({
    super.key,
    required this.selectedProvider,
    required this.focusedIndex,
    required this.onProviderSelected,
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _itemKeys = {};

  @override
  void initState() {
    super.initState();
    // Create keys for each provider item
    for (int i = 0; i < ProviderManager.availableProviders.length; i++) {
      _itemKeys[i] = GlobalKey();
    }
    // Schedule initial scroll after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToFocusedItem();
    });
  }

  @override
  void didUpdateWidget(Sidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Scroll to focused item when focusedIndex changes
    if (oldWidget.focusedIndex != widget.focusedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToFocusedItem();
      });
    }
  }

  void _scrollToFocusedItem() {
    if (widget.focusedIndex < 0 ||
        widget.focusedIndex >= ProviderManager.availableProviders.length) {
      return;
    }

    final key = _itemKeys[widget.focusedIndex];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.5, // Center the item
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141414), // Deep premium dark background
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.8),
            blurRadius: 30, // Softer shadow
            spreadRadius: 5,
          ),
        ],
        border: Border(
          right: BorderSide(color: Colors.white.withOpacity(0.08), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 30),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      // Vibrant Mixed Colors: Yellow -> Orange -> Pinkish Red
                      colors: [
                        Color(0xFFFFD54F),
                        Color(0xFFFF9800),
                        Color(0xFFFF3D00),
                      ],
                      stops: [0.0, 0.5, 1.0],
                    ).createShader(bounds),
                    child: const Text(
                      'ScreenScapeTV',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const GlobalSearchScreen(),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: widget.focusedIndex == -1
                              ? Colors.white.withOpacity(0.15)
                              : Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: widget.focusedIndex == -1
                                ? Colors.white.withOpacity(0.3)
                                : Colors.white.withOpacity(0.1),
                            width: widget.focusedIndex == -1 ? 2 : 1,
                          ),
                          boxShadow: widget.focusedIndex == -1
                              ? [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.2),
                                    blurRadius: 12,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : [],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.search,
                              color: widget.focusedIndex == -1
                                  ? Colors.white
                                  : Colors.grey[400],
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Global Search',
                              style: TextStyle(
                                color: widget.focusedIndex == -1
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.9),
                                fontSize: 14,
                                fontWeight: widget.focusedIndex == -1
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // const SizedBox(height: 10),
                  // Material(
                  //   color: Colors.transparent,
                  //   child: InkWell(
                  //     onTap: () {
                  //       Navigator.push(
                  //         context,
                  //         MaterialPageRoute(builder: (context) => const ExtractorTestScreen()),
                  //       );
                  //     },
                  //     borderRadius: BorderRadius.circular(10),
                  //     child: Container(
                  //       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  //       decoration: BoxDecoration(
                  //         color: Colors.white.withOpacity(0.08),
                  //         borderRadius: BorderRadius.circular(10),
                  //         border: Border.all(color: Colors.white.withOpacity(0.1)),
                  //       ),
                  //       child: Row(
                  //         children: [
                  //           Icon(Icons.science_outlined, color: Colors.grey[400], size: 18),
                  //           const SizedBox(width: 10),
                  //           const Text(
                  //             'Extractor Test',
                  //             style: TextStyle(
                  //               color: Colors.white,
                  //               fontSize: 14,
                  //               fontWeight: FontWeight.w500,
                  //             ),
                  //           ),
                  //         ],
                  //       ),
                  //     ),
                  //   ),
                  // ),
                  const SizedBox(height: 20),
                  Text(
                    'SELECT PROVIDER',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: ProviderManager.availableProviders.asMap().entries.map((
                entry,
              ) {
                final index = entry.key;
                final provider = entry.value;
                final isSelected = provider['id'] == widget.selectedProvider;
                final isFocused = index == widget.focusedIndex;
                return _buildSidebarItem(
                  key: _itemKeys[index],
                  icon: provider['icon'] as IconData,
                  title: provider['name'] as String,
                  isSelected: isSelected,
                  isFocused: isFocused,
                  onTap: () =>
                      widget.onProviderSelected(provider['id'] as String),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem({
    Key? key,
    required IconData icon,
    required String title,
    required bool isSelected,
    required bool isFocused,
    required VoidCallback onTap,
  }) {
    // Mixed Colors Gradient for selection
    const List<Color> activeColors = [
      Color(0xFFFFC107),
      Color(0xFFFF6F00),
    ]; // Amber to Dark Orange

    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: isSelected
              ? LinearGradient(
                  colors: activeColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : (isFocused
                    ? LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.12),
                          Colors.white.withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null),
          border: isFocused && !isSelected
              ? Border.all(color: Colors.white.withOpacity(0.2), width: 1.5)
              : Border.all(color: Colors.transparent, width: 1.5),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColors[0].withOpacity(0.4),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.black.withOpacity(0.15)
                          : Colors.white.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: isSelected
                          ? Colors.white
                          : (isFocused ? Colors.white : Colors.grey[500]),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    title,
                    style: TextStyle(
                      color: isFocused || isSelected
                          ? Colors.white
                          : Colors.grey[400],
                      fontSize: 15,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : (isFocused ? FontWeight.w600 : FontWeight.w500),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
