import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class KeyEventHandler extends StatefulWidget {
  final Widget child;
  final VoidCallback? onLeftKey;
  final VoidCallback? onRightKey;
  final VoidCallback? onUpKey;
  final VoidCallback? onDownKey;
  final VoidCallback? onEnterKey;
  final VoidCallback? onBackKey;
  final VoidCallback? onEscapeKey;
  final bool treatSpaceAsEnter;
  final bool treatBackspaceAsBack;

  const KeyEventHandler({
    super.key,
    required this.child,
    this.onLeftKey,
    this.onRightKey,
    this.onUpKey,
    this.onDownKey,
    this.onEnterKey,
    this.onBackKey,
    this.onEscapeKey,
    this.treatSpaceAsEnter = true,
    this.treatBackspaceAsBack = true,
  });

  @override
  State<KeyEventHandler> createState() => _KeyEventHandlerState();
}

class _KeyEventHandlerState extends State<KeyEventHandler> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Request focus when the widget is first created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      switch (event.logicalKey) {
        // Arrow keys (work on keyboard and Android TV D-pad)
        case LogicalKeyboardKey.arrowLeft:
          widget.onLeftKey?.call();
          return KeyEventResult.handled;
        
        case LogicalKeyboardKey.arrowRight:
          widget.onRightKey?.call();
          return KeyEventResult.handled;
        
        case LogicalKeyboardKey.arrowUp:
          widget.onUpKey?.call();
          return KeyEventResult.handled;
        
        case LogicalKeyboardKey.arrowDown:
          widget.onDownKey?.call();
          return KeyEventResult.handled;
        
        // Enter/Select keys (includes Android TV OK button)
        case LogicalKeyboardKey.enter:
        case LogicalKeyboardKey.select:
          widget.onEnterKey?.call();
          return KeyEventResult.handled;

        case LogicalKeyboardKey.space:
          if (widget.treatSpaceAsEnter) {
            widget.onEnterKey?.call();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        
        // Escape key
        case LogicalKeyboardKey.escape:
          widget.onEscapeKey?.call();
          return KeyEventResult.handled;
        
        // Back keys (includes Android TV Back button)
        case LogicalKeyboardKey.goBack:
        case LogicalKeyboardKey.browserBack:
          widget.onBackKey?.call();
          return KeyEventResult.handled;
        
        case LogicalKeyboardKey.backspace:
          if (widget.treatBackspaceAsBack) {
            widget.onBackKey?.call();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;

        default:
          return KeyEventResult.ignored;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      autofocus: true,
      child: GestureDetector(
        onTap: () {
          _focusNode.requestFocus();
        },
        child: widget.child,
      ),
    );
  }
}

/// Extension for easier keyboard handling in widgets
extension KeyboardNavigation on BuildContext {
  void handleKeyboardEvent({
    VoidCallback? onLeft,
    VoidCallback? onRight,
    VoidCallback? onUp,
    VoidCallback? onDown,
    VoidCallback? onEnter,
  }) {
    // This can be used for inline keyboard handling if needed
  }
}

/// Utility class for common keyboard shortcuts
class KeyboardShortcuts {
  static const Map<String, List<LogicalKeyboardKey>> shortcuts = {
    'search': [LogicalKeyboardKey.keyS, LogicalKeyboardKey.controlLeft],
    'refresh': [LogicalKeyboardKey.keyR, LogicalKeyboardKey.controlLeft],
    'home': [LogicalKeyboardKey.keyH, LogicalKeyboardKey.controlLeft],
    'settings': [LogicalKeyboardKey.comma, LogicalKeyboardKey.controlLeft],
  };

  static bool isShortcutPressed(KeyEvent event, String shortcut) {
    final keys = shortcuts[shortcut];
    if (keys == null || event is! KeyDownEvent) return false;
    
    return keys.every((key) {
      return HardwareKeyboard.instance.isLogicalKeyPressed(key);
    });
  }
}
