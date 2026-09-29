import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

class VirtualMouseOverlay extends StatefulWidget {
  final WebViewController controller;
  final Widget child;

  const VirtualMouseOverlay({
    super.key,
    required this.controller,
    required this.child,
  });

  @override
  State<VirtualMouseOverlay> createState() => _VirtualMouseOverlayState();
}

class _VirtualMouseOverlayState extends State<VirtualMouseOverlay> {
  final FocusNode _focusNode = FocusNode();
  
  // Cursor position coordinates
  double _x = 400.0;
  double _y = 300.0;
  
  // Movement speed multiplier per D-pad click
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

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      final key = event.logicalKey;

      // Only intercept D-pad and selection keys for the virtual mouse
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
                  element.focus();
                  element.click();
                  
                  if (element.tagName === 'INPUT' || element.tagName === 'TEXTAREA' || element.isContentEditable) {
                    element.focus();
                    var clickEvent = new MouseEvent('click', {
                      view: window,
                      bubbles: true,
                      cancelable: true,
                      clientX: x,
                      clientY: y
                    });
                    element.dispatchEvent(clickEvent);
                  }
                }
              })();
            ''');
          }
        });
        return KeyEventResult.handled; // Handled as a mouse movement/click
      }
    }

    // CRITICAL: Let regular typing keys (letters, numbers, backspace) pass through to text fields!
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        onTap: () {
          FocusScope.of(context).requestFocus(_focusNode);
        },
        child: Stack(
          children: [
            // The underlying web view content
            widget.child,

            // Virtual Mouse Cursor Overlay
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
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 6,
                          spreadRadius: 2,
                        ),
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
