import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

class SeasonList extends StatefulWidget {
  final List<String> items;
  final String selectedItem;
  final Function(String) onChanged;
  final bool isFocused;
  final String label;
  final IconData? icon;

  const SeasonList({
    super.key,
    required this.items,
    required this.selectedItem,
    required this.onChanged,
    this.isFocused = false,
    this.label = "Select",
    this.icon,
  });

  @override
  State<SeasonList> createState() => SeasonListState();
}

class SeasonListState extends State<SeasonList> {
  final GlobalKey _dropdownKey = GlobalKey();

  void openDropdown() {
    final dynamic dropdownState = _dropdownKey.currentState;
    if (dropdownState != null) {
      final RenderBox? renderBox = _dropdownKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final Offset position = renderBox.localToGlobal(Offset.zero);
        final Size size = renderBox.size;
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
    // Detect mobile screen
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 16, vertical: 0),
      decoration: BoxDecoration(
        color: widget.isFocused ? Colors.white : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
        border: Border.all(
          color: widget.isFocused ? Colors.white : Colors.white.withOpacity(0.1),
          width: 2,
        ),
        boxShadow: widget.isFocused
            ? [
                BoxShadow(
                  color: Colors.white.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                )
              ]
            : [],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          key: _dropdownKey,
          value: widget.selectedItem,
          isExpanded: true,
          dropdownColor: const Color(0xFF252525),
          borderRadius: BorderRadius.circular(12),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: widget.isFocused ? Colors.black : Colors.white70,
            size: isMobile ? 18 : 24,
          ),
          style: TextStyle(
            color: widget.isFocused ? Colors.black : Colors.white,
            fontSize: isMobile ? 12 : 15,
            fontWeight: FontWeight.w600,
            fontFamily: 'GoogleSans',
          ),
          onChanged: (String? newValue) {
            if (newValue != null) {
              widget.onChanged(newValue);
            }
          },
          selectedItemBuilder: (context) {
             return widget.items.map((e) {
               return Row(
                  children: [
                    if (widget.icon != null) ...[
                      Icon(
                        widget.icon, 
                        size: isMobile ? 14 : 18, 
                        color: widget.isFocused ? Colors.black54 : Colors.white54
                      ),
                      SizedBox(width: isMobile ? 4 : 8),
                    ],
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: widget.isFocused ? Colors.black54 : Colors.white54,
                        fontWeight: FontWeight.w500,
                        fontSize: isMobile ? 11 : 15,
                      ),
                    ),
                    SizedBox(width: isMobile ? 4 : 8),
                    Flexible(
                      child: Text(
                        e,
                        overflow: TextOverflow.ellipsis,
                         style: TextStyle(
                          color: widget.isFocused ? Colors.black : Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: isMobile ? 12 : 15,
                        ),
                      ),
                    ),
                  ],
               );
             }).toList();
          },
          items: widget.items.map((String item) {
            final isSelected = item == widget.selectedItem;
            return DropdownMenuItem<String>(
              value: item,
              child: Container(
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.symmetric(vertical: isMobile ? 6 : 8),
                child: Row(
                  children: [
                    if (isSelected)
                      Container(
                        width: isMobile ? 3 : 4, 
                        height: isMobile ? 12 : 16, 
                        margin: EdgeInsets.only(right: isMobile ? 8 : 12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    Flexible(
                      child: Text(
                        item,
                        style: TextStyle(
                          color: isSelected ? Colors.redAccent : Colors.white,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: isMobile ? 12 : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
