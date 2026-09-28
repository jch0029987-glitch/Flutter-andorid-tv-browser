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
  
  final String _homeUrl = 'https://www.google.com';
  bool _canGoBack = false;
  bool _canGoForward = false;
  String _currentUrl = 'https://www.google.com';

  @override
  void initState() {
    super.initState();
    _urlController.text = _homeUrl;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) async {
            final back = await _controller.canGoBack();
            final forward = await _controller.canGoForward();
            setState(() {
              _currentUrl = url;
              _urlController.text = url;
              _canGoBack = back;
              _canGoForward = forward;
            });
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
    // Unfocus URL bar after loading to return navigation priority
    FocusScope.of(context).unfocus();
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
          // If no more history, allow app to exit
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        body: Focus(
          // Global shortcut listener for remote buttons (e.g. Menu button to focus URL bar)
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.contextMenu ||
                  event.logicalKey == LogicalKeyboardKey.f2) {
                _urlFocusNode.requestFocus();
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
                    const SizedBox(width: 8),
                    IconButton(
                      focusColor: Colors.blueAccent,
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: _canGoForward ? () => _controller.goForward() : null,
                      tooltip: 'Forward',
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      focusColor: Colors.blueAccent,
                      icon: const Icon(Icons.home),
                      onPressed: () => _loadUrl(_homeUrl),
                      tooltip: 'Home',
                    ),
                    const SizedBox(width: 16),
                    // URL / Search Input
                    Expanded(
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
                  ],
                ),
              ),
              
              // Core Web Engine wrapped inside the Virtual Mouse Overlay
              Expanded(
                child: VirtualMouseOverlay(
                  controller: _controller,
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
