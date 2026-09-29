import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'virtual_mouse.dart';
import 'update_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FlutterBrowserNextApp());
}

class FlutterBrowserNextApp extends StatelessWidget {
  const FlutterBrowserNextApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Browser Next',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const BrowserHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class BrowserHomePage extends StatefulWidget {
  const BrowserHomePage({super.key});

  @override
  State<BrowserHomePage> createState() => _BrowserHomePageState();
}

class _BrowserHomePageState extends State<BrowserHomePage> {
  late final WebViewController _controller;
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _urlFocusNode = FocusNode();
  
  // Key to control the virtual mouse overlay focus externally
  final GlobalKey<VirtualMouseOverlayState> _mouseOverlayKey = GlobalKey<VirtualMouseOverlayState>();
  
  final String _homeUrl = 'https://www.facebook.com/login';
  bool _canGoBack = false;
  bool _canGoForward = false;
  String _currentUrl = 'https://www.facebook.com/login';
  
  // User Agent Mode State
  bool _isDesktopMode = true;
  
  static const String _desktopUserAgent = 
      "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";
  static const String _mobileUserAgent = 
      "Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36";

  @override
  void initState() {
    super.initState();
    _urlController.text = _homeUrl;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_desktopUserAgent)
      ..setNavigationDelegate(
        NavigationDelegate(
          // Ad-blocker & tracker interception
          onNavigationRequest: (NavigationRequest request) {
            if (_isAdOrTracker(request.url)) {
              debugPrint('🚫 Blocked Ad/Tracker: ${request.url}');
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageFinished: (String url) async {
            final back = await _controller.canGoBack();
            final forward = await _controller.canGoForward();
            setState(() {
              _currentUrl = url;
              _urlController.text = url;
              _canGoBack = back;
              _canGoForward = forward;
            });

            // EXTREME META INPUT BRIDGE: Force typing into React forms on Facebook
            if (url.contains('facebook.com')) {
              _controller.runJavaScript('''
                (function() {
                  if (window._metaBridgeInitialized) return;
                  window._metaBridgeInitialized = true;

                  document.addEventListener('keydown', function(e) {
                    var active = document.activeElement;
                    if (active && (active.tagName === 'INPUT' || active.tagName === 'TEXTAREA')) {
                      var nativeInputValueSetter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, "value").set;
                      if (e.key.length === 1) {
                        nativeInputValueSetter.call(active, active.value + e.key);
                        active.dispatchEvent(new Event('input', { bubbles: true }));
                        active.dispatchEvent(new Event('change', { bubbles: true }));
                      } else if (e.key === 'Backspace') {
                        nativeInputValueSetter.call(active, active.value.slice(0, -1));
                        active.dispatchEvent(new Event('input', { bubbles: true }));
                        active.dispatchEvent(new Event('change', { bubbles: true }));
                      }
                    }
                  }, true);
                  console.log("Extreme Meta Input Bridge Initialized.");
                })();
              ''');
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView Error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(_homeUrl));

    // Automatically check for GitHub updates silently right after launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.checkForUpdates(context, silent: true);
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  // Toggle between Desktop and Mobile User Agents
  void _toggleDesktopMode() async {
    setState(() {
      _isDesktopMode = !_isDesktopMode;
    });

    final targetUserAgent = _isDesktopMode ? _desktopUserAgent : _mobileUserAgent;
    await _controller.setUserAgent(targetUserAgent);
    _controller.reload();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isDesktopMode ? "Switched to Desktop Mode" : "Switched to Mobile Mode"),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // Jump focus to URL toolbar when Escape is pressed on the webpage
  void _jumpToToolbar() {
    FocusScope.of(context).requestFocus(_urlFocusNode);
  }

  // Domain filter for the lightweight built-in ad blocker
  bool _isAdOrTracker(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    
    final host = uri.host.toLowerCase();

    const blockedDomains = {
      'googlesyndication.com',
      'doubleclick.net',
      'adservice.google.com',
      'amazon-adsystem.com',
      'adnxs.com',
      'ads.twitter.com',
      'facebook.com/tr',
      'hotjar.com',
      'segment.io',
      'scorecardresearch.com',
    };

    for (var domain in blockedDomains) {
      if (host == domain || host.endsWith('.$domain')) {
        return true;
      }
    }
    return false;
  }

  void _loadUrl(String input) {
    String formattedUrl = input.trim();
    if (!formattedUrl.startsWith('http://') && !formattedUrl.startsWith('https://')) {
      if (formattedUrl.contains(' ') || !formattedUrl.contains('.')) {
        formattedUrl = 'https://www.google.com/search?q=${Uri.encodeComponent(formattedUrl)}';
      } else {
        formattedUrl = 'https://$formattedUrl';
      }
    }
    _controller.loadRequest(Uri.parse(formattedUrl));
    
    // Return focus back to the virtual mouse overlay after loading
    _mouseOverlayKey.currentState?.focusOverlay();
  }

  @override
  Widget build(BuildContext context) {
    // PopScope handles Android TV remote Back button behavior safely
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        if (await _controller.canGoBack()) {
          _controller.goBack();
        } else {
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        body: Focus(
          // Shortcut listener (e.g. Menu button or F2 to focus the URL bar)
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.contextMenu ||
                  event.logicalKey == LogicalKeyboardKey.f2) {
                _jumpToToolbar();
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: Column(
            children: [
              // Top Toolbar (Remote Focusable Controls)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                color: Colors.grey[900],
                child: Row(
                  children: [
                    IconButton(
                      focusColor: Colors.blueAccent,
                      icon: const Icon(Icons.arrow_back),
                      onPressed: _canGoBack ? () => _controller.goBack() : null,
                      tooltip: 'Back',
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      focusColor: Colors.blueAccent,
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: _canGoForward ? () => _controller.goForward() : null,
                      tooltip: 'Forward',
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      focusColor: Colors.blueAccent,
                      icon: const Icon(Icons.home),
                      onPressed: () => _loadUrl(_homeUrl),
                      tooltip: 'Home',
                    ),
                    const SizedBox(width: 4),
                    // Desktop / Mobile Mode Toggle Button
                    IconButton(
                      focusColor: Colors.blueAccent,
                      icon: Icon(_isDesktopMode ? Icons.desktop_windows : Icons.phone_android),
                      onPressed: _toggleDesktopMode,
                      tooltip: _isDesktopMode ? 'Switch to Mobile View' : 'Switch to Desktop View',
                    ),
                    const SizedBox(width: 12),
                    // URL / Search Input wrapped in Focus to catch Escape key
                    Expanded(
                      child: Focus(
                        onKeyEvent: (node, event) {
                          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
                            _mouseOverlayKey.currentState?.focusOverlay();
                            return KeyEventResult.handled;
                          }
                          return KeyEventResult.ignored;
                        },
                        child: TextField(
                          controller: _urlController,
                          focusNode: _urlFocusNode,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Search or enter address...',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            filled: true,
                            fillColor: Colors.grey[800],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                          ),
                          onSubmitted: (value) => _loadUrl(value),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Core Web Engine wrapped inside the Virtual Mouse Overlay
              Expanded(
                child: VirtualMouseOverlay(
                  key: _mouseOverlayKey,
                  controller: _controller,
                  onToggleToolbar: _jumpToToolbar,
                  child: WebViewWidget(controller: _controller),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
