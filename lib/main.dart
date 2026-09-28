import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
  String _currentUrl = 'https://www.google.com';

  @override
  void initState() {
    super.initState();
    _urlController.text = _currentUrl;
    
    // Initialize the WebView controller
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() {
              _currentUrl = url;
              _urlController.text = url;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(_currentUrl));
  }

  void _loadUrl(String input) {
    String formattedUrl = input.trim();
    if (!formattedUrl.startsWith('http://') && !formattedUrl.startsWith('https://')) {
      // If it's a search term rather than a URL, fall back to a search engine
      if (formattedUrl.contains(' ') || !formattedUrl.contains('.')) {
        formattedUrl = 'https://www.google.com/search?q=${Uri.encodeComponent(formattedUrl)}';
      } else {
        formattedUrl = 'https://$formattedUrl';
      }
    }
    
    _controller.loadRequest(Uri.parse(formattedUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // TV Remote Accessible Top Bar (Address bar & controls)
          Container(
            padding: const EdgeInsets.all(12.0),
            color: Colors.grey[900],
            child: Row(
              children: [
                // Back Button
                IconButton(
                  focusColor: Colors.blueAccent,
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () async {
                    if (await _controller.canGoBack()) {
                      _controller.goBack();
                    }
                  },
                ),
                const SizedBox(width: 8),
                // Forward Button
                IconButton(
                  focusColor: Colors.blueAccent,
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () async {
                    if (await _controller.canGoForward()) {
                      _controller.goForward();
                    }
                  },
                ),
                const SizedBox(width: 12),
                // Address/Search Bar Text Field
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      hintText: 'Enter URL or search query...',
                      filled: true,
                      fillColor: Colors.grey[800],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                    ),
                    onSubmitted: (value) {
                      _loadUrl(value);
                    },
                  ),
                ),
              ],
            ),
          ),
          // WebView Body Content
          Expanded(
            child: WebViewWidget(controller: _controller),
          ),
        ],
      ),
    );
  }
}
