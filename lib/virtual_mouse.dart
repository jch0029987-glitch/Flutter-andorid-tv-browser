import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

class VirtualMouseOverlay extends StatefulWidget {
  final Widget child;
  final WebViewController controller;

  const VirtualMouseOverlay({
    super.key,
    required this.child,
    required this.controller,
  });

  @override
  State<VirtualMouseOverlay> createState() => _VirtualMouseOverlayState();
}

class _VirtualMouseOverlayState extends State<VirtualMouseOverlay> {
  // Initial cursor position (center of a typical TV screen layout)
  Offset _cursorPosition = const Offset(640, 360);
  final FocusNode _focusNode = FocusNode();
  
  // Movement speed multiplier for D-pad steps
  static const double _stepSize = 25.0;

  @override
  void initState() {
    super.initState();
    // Auto-focus the wrapper so it immediately captures TV remote inputs
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  // Handle D-pad directional movements and center click selections
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      setState(() {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          _cursorPosition = Offset(
            _cursorPosition.dx,
            (_cursorPosition.dy - _stepSize).clamp(0.0, 1080.0),
          );
        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _cursorPosition = Offset(
            _cursorPosition.dx,
            (_cursorPosition.dy + _stepSize).clamp(0.0, 1080.0),
          );
        } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          _cursorPosition = Offset(
            (_cursorPosition.dx - _stepSize).clamp(0.0, 1920.0),
            _cursorPosition.dy,
          );
        } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          _cursorPosition = Offset(
            (_cursorPosition.dx + _stepSize).clamp(0.0, 1920.0),
            _cursorPosition.dy,
          );
        } else if (event.logicalKey == LogicalKeyboardKey.select ||
                   event.logicalKey == LogicalKeyboardKey.enter ||
                   event.logicalKey == LogicalKeyboardKey.space) {
          // Trigger a JavaScript click event at the current virtual cursor location
          _simulateClickAt(_cursorPosition);
        }
      });
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // Programmatically inject a mouse click into the WebView at specific coordinates
  void _simulateClickAt(Offset position) {
    String script = '''
      (function() {
        var element = document.elementFromPoint(${position.dx}, ${position.dy});
        if (element) {
          element.click();
          var event = new MouseEvent('click', {
            view: window,
            bubbles: true,
            cancelable: true,
            clientX: ${position.dx},
            clientY: ${position.dy}
          });
          element.dispatchEvent(event);
        }
      })();
    ''';
    widget.controller.runJavaScript(script);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // The underlying widget (Your WebView)
              widget.child,

              // The Floating Virtual Mouse Cursor Indicator
              Positioned(
                left: _cursorPosition.dx,
                top: _cursorPosition.dy,
                child: IgnorePointer(
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxBoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 4,
                          spreadRadius: 1,
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
