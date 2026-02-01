import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

class SeasonList extends StatefulWidget {
  final List<String> qualities;
  final String selectedQuality;
  final Function(String) onQualityChanged;
  final bool isFocused;
  final VoidCallback? onNavigateAway;

  const SeasonList({
    super.key,
    required this.qualities,
    required this.selectedQuality,
    required this.onQualityChanged,
    this.isFocused = false,
    this.onNavigateAway,
  });

  @override
  State<SeasonList> createState() => SeasonListState();
}

class SeasonListState extends State<SeasonList> {
  final GlobalKey _dropdownKey = GlobalKey();

  void openDropdown() {
    // Simulate a tap on the dropdown to open it
    final dynamic dropdownState = _dropdownKey.currentState;
    if (dropdownState != null) {
      final RenderBox? renderBox = _dropdownKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final Offset position = renderBox.localToGlobal(Offset.zero);
        final Size size = renderBox.size;
        // Trigger tap at the center of the dropdown
        GestureBinding.instance.handlePointerEvent(
          PointerDownEvent(
            position: position + Offset(size.width / 2, size.height / 2),
          ),
        );
        GestureBinding.instance.handlePointerEvent(
          PointerUpEvent(
            position: position + Offset(size.width / 2, size.height / 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.grey[850]!,
            Colors.grey[900]!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isFocused ? Colors.red : Colors.red.withOpacity(0.3),
          width: widget.isFocused ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.isFocused ? Colors.red.withOpacity(0.4) : Colors.red.withOpacity(0.2),
            blurRadius: widget.isFocused ? 12 : 8,
            spreadRadius: widget.isFocused ? 2 : 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: _dropdownKey,
              value: widget.selectedQuality,
              dropdownColor: Colors.grey[850],
              icon: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  Icons.arrow_drop_down_rounded,
                  color: widget.isFocused ? Colors.red : Colors.white,
                  size: 24,
                ),
              ),
              style: TextStyle(
                color: widget.isFocused ? Colors.red : Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              items: widget.qualities.map((String quality) {
                final isSelected = quality == widget.selectedQuality;
                return DropdownMenuItem<String>(
                  value: quality,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.red.withOpacity(0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        if (isSelected)
                          const Icon(
                            Icons.check_circle,
                            color: Colors.red,
                            size: 18,
                          ),
                        if (isSelected) const SizedBox(width: 8),
                        Text(
                          quality,
                          style: TextStyle(
                            color: isSelected ? Colors.red : Colors.white,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  widget.onQualityChanged(newValue);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
