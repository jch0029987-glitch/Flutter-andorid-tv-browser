import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

class VirtualMouseOverlay extends StatefulWidget {
  final WebViewController controller;
  final Widget child;
  final VoidCallback onToggleToolbar; // Called when Escape is pressed

  const VirtualMouseOverlay({
    super.key,
    required this.controller,
    required this.child,
    required this.onToggleToolbar,
  });

  @override
  State<VirtualMouseOverlay> createState() => _VirtualMouseOverlayState();
}

class _VirtualMouseOverlayState extends State<VirtualMouseOverlay> {
  final FocusNode _focusNode = FocusNode();
  
  double _x = 400.0;
  double _y = 300.0;
  static const double _step = 15.0;
  bool _isCursorVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  // Public method so parent can force focus back to the mouse overlay
  void focusOverlay() {
    if (mounted) {
      FocusScope.of(context).requestFocus(_focusNode);
      setState(() {
        _isCursorVisible = true;
      });
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      final key = event.logicalKey;

      // ESCAPE KEY: Jumps focus up to the URL toolbar
      if (key == LogicalKeyboardKey.escape) {
        widget.onToggleToolbar();
        return KeyEventResult.handled;
      }

      // FAILSAFE: F1 key resets cursor position and screen focus instantly
      if (key == LogicalKeyboardKey.f1) {
        setState(() {
          _isCursorVisible = true;
          _x = 400.0;
          _y = 300.0;
        });
        FocusScope.of(context).requestFocus(_focusNode);
        return KeyEventResult.handled;
      }

      // D-pad movement and selection handling
      if (key == LogicalKeyboardKey.arrowUp ||
          key == LogicalKeyboardKey.arrowDown ||
          key == LogicalKeyboardKey.arrowLeft ||
          key == LogicalKeyboardKey.arrowRight ||
          key == LogicalKeyboardKey.select ||
          key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.space) {
        
        setState(() {
          _isCursorVisible = true;
          final size = MediaQuery.of(context).size;

          if (key == LogicalKeyboardKey.arrowUp) {
            _y = (_y - _step).clamp(0.0, size.height - 50);
          } else if (key == LogicalKeyboardKey.arrowDown) {
            _y = (_y + _step).clamp(0.0, size.height - 50);
          } else if (key == LogicalKeyboardKey.arrowLeft) {
            _x = (_x - _step).clamp(0.0, size.width - 50);
          } else if (key == LogicalKeyboardKey.arrowRight) {
            _x = (_x + _step).clamp(0.0, size.width - 50);
          } else if (key == LogicalKeyboardKey.select ||
                     key == LogicalKeyboardKey.enter ||
                     key == LogicalKeyboardKey.space) {
            
            widget.controller.runJavaScript('''
              (function() {
                var x = $_x;
                var y = $_y;
                var element = document.elementFromPoint(x, y);
                if (element) {
                  element.scrollIntoView({ behavior: 'smooth', block: 'center' });
                  ['mousedown', 'mouseup', 'click', 'focus', 'focusin'].forEach(function(eventType) {
                    var ev = new MouseEvent(eventType, {
                      view: window, bubbles: true, cancelable: true, clientX: x, clientY: y
                    });
                    element.dispatchEvent(ev);
                  });
                  if (element.tagName === 'INPUT' || element.tagName === 'TEXTAREA' || element.isContentEditable) {
                    element.focus();
                    var inputEvent = new Event('input', { bubbles: true });
                    element.dispatchEvent(inputEvent);
                  }
                }
              })();
            ''');
          }
        });
        return KeyEventResult.handled;
      }
    }

    // Let regular typing keys (letters, numbers, backspace) pass through to inputs
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).requestFocus(_focusNode),
        child: Stack(
          children: [
            widget.child,
            if (_isCursorVisible)
              Positioned(
                left: _x,
                top: _y,
                child: IgnorePointer(
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.8),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black45, blurRadius: 6, spreadRadius: 2),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
