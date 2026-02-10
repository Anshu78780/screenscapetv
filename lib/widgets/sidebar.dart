import 'package:flutter/material.dart';
import '../provider/provider_manager.dart';
import '../screens/global_search_screen.dart';

class Sidebar extends StatelessWidget {
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
                      colors: [Color(0xFFFFD54F), Color(0xFFFF9800), Color(0xFFFF3D00)], 
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
                          MaterialPageRoute(builder: (context) => const GlobalSearchScreen()),
                        );
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search, color: Colors.grey[400], size: 18),
                            const SizedBox(width: 10),
                            const Text(
                              'Global Search',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: ProviderManager.availableProviders.asMap().entries.map((entry) {
                final index = entry.key;
                final provider = entry.value;
                final isSelected = provider['id'] == selectedProvider;
                final isFocused = index == focusedIndex;
                return _buildSidebarItem(
                  provider['icon'] as IconData,
                  provider['name'] as String,
                  isSelected,
                  isFocused,
                  () => onProviderSelected(provider['id'] as String),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String title, bool isSelected, bool isFocused, VoidCallback onTap) {
    // Mixed Colors Gradient for selection
    const List<Color> activeColors = [Color(0xFFFFC107), Color(0xFFFF6F00)]; // Amber to Dark Orange

    return Padding(
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
                      colors: [Colors.white.withOpacity(0.12), Colors.white.withOpacity(0.05)],
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
                       color: isSelected ? Colors.black.withOpacity(0.15) : Colors.white.withOpacity(0.05),
                       shape: BoxShape.circle,
                     ),
                     child: Icon(
                        icon, 
                        color: isSelected ? Colors.white : (isFocused ? Colors.white : Colors.grey[500]), 
                        size: 20
                      ),
                   ),
                  const SizedBox(width: 16),
                  Text(
                    title,
                    style: TextStyle(
                      color: isFocused || isSelected ? Colors.white : Colors.grey[400],
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w700 : (isFocused ? FontWeight.w600 : FontWeight.w500),
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
