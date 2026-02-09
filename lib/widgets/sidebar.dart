import 'package:flutter/material.dart';
import '../provider/provider_manager.dart';

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
        color: Colors.grey[900],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 60),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Colors.red, Colors.orange],
                ).createShader(bounds),
                child: const Text(
                  'ScreenScapeTV',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          Expanded(
            child: ListView(
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: BoxDecoration(
            color: isSelected ? Colors.red.withOpacity(0.2) : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: isSelected ? Colors.red : Colors.transparent,
                width: 4,
              ),
              top: isFocused ? const BorderSide(color: Colors.white, width: 2) : BorderSide.none,
              right: isFocused ? const BorderSide(color: Colors.white, width: 2) : BorderSide.none,
              bottom: isFocused ? const BorderSide(color: Colors.white, width: 2) : BorderSide.none,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon, 
                color: isFocused ? Colors.white : (isSelected ? Colors.red : Colors.grey[400]), 
                size: 24
              ),
              const SizedBox(width: 15),
              Text(
                title,
                style: TextStyle(
                  color: isFocused ? Colors.white : (isSelected ? Colors.white : Colors.grey[400]),
                  fontSize: 16,
                  fontWeight: isFocused || isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
