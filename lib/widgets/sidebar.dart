import 'dart:ui';
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
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF141414).withOpacity(0.95),
                const Color(0xFF1C1C1C).withOpacity(0.90),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
            border: Border(
              right: BorderSide(
                  color: Colors.white.withOpacity(0.05), width: 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 50),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Logo
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            Color(0xFFFFC107),
                            Color(0xFFFF5722),
                            Color(0xFFE91E63),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds),
                        child: Row(
                          children: [
                            const Icon(Icons.movie_filter_rounded,
                                color: Colors.white, size: 28),
                            const SizedBox(width: 12),
                            const Text(
                              'ScreenScape',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Global Search Item
                      _buildGlobalSearchItem(),

                      const SizedBox(height: 30),

                      // Section Title
                      Row(
                        children: [
                          Container(
                            width: 3,
                            height: 12,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFC107),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'PROVIDERS',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: ProviderManager.availableProviders.length,
                  itemBuilder: (context, index) {
                    final provider =
                        ProviderManager.availableProviders[index];
                    final isSelected =
                        provider['id'] == widget.selectedProvider;
                    final isFocused = index == widget.focusedIndex;
                    return _buildSidebarItem(
                      key: _itemKeys[index],
                      icon: provider['icon'] as IconData,
                      title: provider['name'] as String,
                      isSelected: isSelected,
                      isFocused: isFocused,
                      onTap: () => widget
                          .onProviderSelected(provider['id'] as String),
                    );
                  },
                ),
              ),
              
              // Footer
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'v1.0.0 Beta',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.2),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlobalSearchItem() {
    final isFocused = widget.focusedIndex == -1;

    return Material(
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
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isFocused
                ? Colors.white.withOpacity(0.12)
                : Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isFocused
                  ? Colors.white.withOpacity(0.3)
                  : Colors.white.withOpacity(0.05),
              width: 1,
            ),
            boxShadow: isFocused
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.search,
                  color: Color(0xFF64B5F6),
                  size: 18,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'Global Search',
                style: TextStyle(
                  color: isFocused ? Colors.white : Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (isFocused)
                 Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF64B5F6),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Color(0xFF64B5F6), blurRadius: 6),
                    ],
                  ),
                ),
            ],
          ),
        ),
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
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          // Clean Gradient or subtle fill
          gradient: isSelected
              ? const LinearGradient(
                  colors: [
                    Color(0xFFFFC107),
                    Color(0xFFFF8F00),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: isFocused && !isSelected ? Colors.white.withOpacity(0.08) : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF8F00).withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
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
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: isSelected ? Colors.white : (isFocused ? Colors.white : Colors.grey[500]),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: isSelected || isFocused ? Colors.white : Colors.grey[400],
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w700 : (isFocused ? FontWeight.w600 : FontWeight.w500),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
