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
    // Request focus automatically so remote D-pad events are captured
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      setState(() {
        _isCursorVisible = true;
        final size = MediaQuery.of(context).size;

        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          _y = (_y - _step).clamp(0.0, size.height - 50);
        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _y = (_y + _step).clamp(0.0, size.height - 50);
        } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          _x = (_x - _step).clamp(0.0, size.width - 50);
        } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          _x = (_x + _step).clamp(0.0, size.width - 50);
        } else if (event.logicalKey == LogicalKeyboardKey.select ||
                   event.logicalKey == LogicalKeyboardKey.enter) {
          // Simulate clicking/tapping at the current cursor coordinate
          // WebView handles pointer interaction natively via touch simulation if supported,
          // or you can inject JavaScript mouse events here if necessary.
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (node, event) {
        _handleKeyEvent(event);
        return KeyEventResult.handled;
      },
      child: GestureDetector(
        onTap: () {
          // Ensure focus remains locked when clicked
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
