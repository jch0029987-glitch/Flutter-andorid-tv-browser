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

            // REACT CDN INJECTION & QUICK-FILL BRIDGE FOR META
            if (url.contains('facebook.com')) {
              _controller.runJavaScript('''
                (function() {
                  if (window._reactInjected) return;
                  window._reactInjected = true;

                  // 1. Load React CDN
                  var reactScript = document.createElement('script');
                  reactScript.src = 'https://unpkg.com/react@18/umd/react.production.min.js';
                  
                  reactScript.onload = function() {
                    var domScript = document.createElement('script');
                    domScript.src = 'https://unpkg.com/react-dom@18/umd/react-dom.production.min.js';
                    domScript.onload = function() { mountReactOverlay(); };
                    document.head.appendChild(domScript);
                  };
                  document.head.appendChild(reactScript);

                  // 2. Mount React TV Helper Component
                  function mountReactOverlay() {
                    var container = document.createElement('div');
                    container.id = 'tv-react-helper-root';
                    container.style.position = 'fixed';
                    container.style.bottom = '20px';
                    container.style.right = '20px';
                    container.style.zIndex = '999999';
                    document.body.appendChild(container);

                    function TVLoginHelper() {
                      const [status, setStatus] = React.useState('Ready');
                      
                      React.useEffect(() => {
                        window._updateTvCredentials = (u, p) => {
                          setStatus('Credentials Loaded');
                        };
                      }, []);

                      const fillInput = (selector, value) => {
                        var field = document.querySelector(selector);
                        if (!field) {
                          setStatus('Field not found: ' + selector);
                          return;
                        }

                        field.focus();
                        var nativeSetter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, "value").set;
                        nativeSetter.call(field, value);

                        if (field._valueTracker) {
                          field._valueTracker.setValue(value);
                        }

                        var inputEvent = new InputEvent('input', { bubbles: true, cancelable: true, inputType: 'insertText', data: value });
                        field.dispatchEvent(inputEvent);
                        field.dispatchEvent(new Event('change', { bubbles: true }));
                        setStatus('Filled successfully');
                      };

                      return React.createElement('div', {
                        style: {
                          background: 'rgba(20, 20, 20, 0.95)',
                          color: '#00ffcc',
                          padding: '16px',
                          borderRadius: '12px',
                          fontFamily: 'sans-serif',
                          fontSize: '13px',
                          boxShadow: '0 8px 24px rgba(0,0,0,0.7)',
                          border: '1px solid #00ffcc',
                          width: '240px'
                        }
                      }, [
                        React.createElement('div', { key: 'title', style: { fontWeight: 'bold', marginBottom: '8px', fontSize: '14px' } }, '📺 TV React Helper'),
                        React.createElement('div', { key: 'status', style: { color: '#ffffff', fontSize: '11px', marginBottom: '10px' } }, 'Status: ' + status),
                        
                        React.createElement('button', {
                          key: 'btn-email',
                          onClick: () => fillInput('#email', window._tvUser || ''),
                          style: { width: '100%', padding: '8px', marginBottom: '6px', background: '#1877f2', color: '#fff', border: 'none', borderRadius: '4px', cursor: 'pointer' }
                        }, '⚡ Fill Email/Phone'),

                        React.createElement('button', {
                          key: 'btn-pass',
                          onClick: () => fillInput('#pass', window._tvPass || ''),
                          style: { width: '100%', padding: '8px', background: '#d93838', color: '#fff', border: 'none', borderRadius: '4px', cursor: 'pointer' }
                        }, '⚡ Fill Password')
                      ]);
                    }

                    const root = ReactDOM.createRoot(container);
                    root.render(React.createElement(TVLoginHelper));
                  }
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

  // Secure In-App Credentials Dialog for TV
  void _showCredentialsDialog() {
    final TextEditingController userController = TextEditingController();
    final TextEditingController passController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🔐 Set Meta Credentials'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: userController,
              decoration: const InputDecoration(labelText: 'Email or Phone'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _injectCredentialsIntoReact(userController.text, passController.text);
            },
            child: const Text('Save & Inject'),
          ),
        ],
      ),
    );
  }

  void _injectCredentialsIntoReact(String username, String password) {
    final safeUser = username.replaceAll("'", "\\'");
    final safePass = password.replaceAll("'", "\\'");

    _controller.runJavaScript('''
      window._tvUser = '$safeUser';
      window._tvPass = '$safePass';
      if (window._updateTvCredentials) {
        window._updateTvCredentials('$safeUser', '$safePass');
      }
    ''');
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Credentials loaded into React helper!'), duration: Duration(seconds: 2)),
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
    _mouseOverlayKey.currentState?.focusOverlay();
  }

  @override
  Widget build(BuildContext context) {
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
                    IconButton(
                      focusColor: Colors.blueAccent,
                      icon: Icon(_isDesktopMode ? Icons.desktop_windows : Icons.phone_android),
                      onPressed: _toggleDesktopMode,
                      tooltip: _isDesktopMode ? 'Switch to Mobile View' : 'Switch to Desktop View',
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      focusColor: Colors.blueAccent,
                      icon: const Icon(Icons.vpn_key),
                      onPressed: _showCredentialsDialog,
                      tooltip: 'Set Login Credentials',
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
