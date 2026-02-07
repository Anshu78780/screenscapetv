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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: widget.isFocused 
            ? Colors.red.withOpacity(0.1) 
            : const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isFocused ? Colors.red : Colors.grey.withOpacity(0.2),
          width: 2,
        ),
        boxShadow: widget.isFocused
            ? [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
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
      child: Row(
        children: [
           Container(
             padding: const EdgeInsets.all(10),
             decoration: BoxDecoration(
               color: widget.isFocused ? Colors.red.withOpacity(0.2) : Colors.grey[800],
               borderRadius: BorderRadius.circular(10),
             ),
             child: Icon(
               Icons.high_quality_rounded,
               color: widget.isFocused ? Colors.red : Colors.grey[400],
               size: 24,
             ),
           ),
           const SizedBox(width: 16),
           Expanded(
             child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                    Text(
                      "Select Quality", 
                      style: TextStyle(
                        color: Colors.grey[400], 
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      )
                    ),
                    const SizedBox(height: 2),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        key: _dropdownKey,
                        value: widget.selectedQuality,
                        isDense: true,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF2C2C2C),
                        icon: const SizedBox.shrink(), // Hide default icon, we have one on the right
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          overflow: TextOverflow.ellipsis,
                        ),
                        items: widget.qualities.map((String quality) {
                          final isSelected = quality == widget.selectedQuality;
                          return DropdownMenuItem<String>(
                            value: quality,
                            child: Container(
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                quality,
                                style: TextStyle(
                                  color: isSelected ? Colors.red : Colors.white,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                                overflow: TextOverflow.ellipsis,
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
           ),
           Icon(
             Icons.keyboard_arrow_down_rounded,
             color: widget.isFocused ? Colors.red : Colors.grey[600],
             size: 28,
           ),
        ],
      ),
    );
  }
}
