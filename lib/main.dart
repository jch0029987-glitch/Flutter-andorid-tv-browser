import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
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
  final FocusNode _appFocusNode = FocusNode();
  
  final String _homeUrl = 'https://www.facebook.com/login';
  bool _canGoBack = false;
  bool _canGoForward = false;
  String _currentUrl = 'https://www.facebook.com/login';
  
  // Modes State
  bool _isDesktopMode = false;
  bool _isTvMouseMode = false;
  
  // Virtual Cursor Coordinates for TV Mode
  double _cursorX = 300;
  double _cursorY = 300;
  
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
      ..setUserAgent(_mobileUserAgent)
      ..setNavigationDelegate(
        NavigationDelegate(
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

            if (url.contains('facebook.com')) {
              _controller.runJavaScript('''
                (function() {
                  if (window._reactInjected) return;
                  window._reactInjected = true;

                  var reactScript = document.createElement('script');
                  reactScript.src = 'https://unpkg.com/react@18/umd/react.production.min.js';
                  
                  reactScript.onload = function() {
                    var domScript = document.createElement('script');
                    domScript.src = 'https://unpkg.com/react-dom@18/umd/react-dom.production.min.js';
                    domScript.onload = function() { mountReactOverlay(); };
                    document.head.appendChild(domScript);
                  };
                  document.head.appendChild(reactScript);

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
                          padding: '12px',
                          borderRadius: '12px',
                          fontFamily: 'sans-serif',
                          fontSize: '12px',
                          boxShadow: '0 8px 24px rgba(0,0,0,0.7)',
                          border: '1px solid #00ffcc',
                          width: '210px'
                        }
                      }, [
                        React.createElement('div', { key: 'title', style: { fontWeight: 'bold', marginBottom: '6px', fontSize: '13px' } }, '📺/📱 Quick-Fill'),
                        React.createElement('div', { key: 'status', style: { color: '#ffffff', fontSize: '10px', marginBottom: '8px' } }, 'Status: ' + status),
                        
                        React.createElement('button', {
                          key: 'btn-email',
                          onClick: () => fillInput('#email', window._tvUser || ''),
                          style: { width: '100%', padding: '6px', marginBottom: '4px', background: '#1877f2', color: '#fff', border: 'none', borderRadius: '4px', cursor: 'pointer' }
                        }, '⚡ Fill Email/Phone'),

                        React.createElement('button', {
                          key: 'btn-pass',
                          onClick: () => fillInput('#pass', window._tvPass || ''),
                          style: { width: '100%', padding: '6px', background: '#d93838', color: '#fff', border: 'none', borderRadius: '4px', cursor: 'pointer' }
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
      );

    _loadCookiesFromFile().then((_) {
      _controller.loadRequest(Uri.parse(_homeUrl));
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        UpdateService.checkForUpdates(context, silent: true);
      } catch (_) {}
      FocusScope.of(context).requestFocus(_appFocusNode);
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _urlFocusNode.dispose();
    _appFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCookiesFromFile() async {
    try {
      final directory = await getExternalStorageDirectory();
      if (directory == null) return;
      
      final file = File('${directory.path}/Download/session_config.json');
      if (await file.exists()) {
        final contents = await file.readAsString();
        final data = jsonDecode(contents);
        
        final String cUser = data['c_user'] ?? '';
        final String xs = data['xs'] ?? '';

        if (cUser.isNotEmpty && xs.isNotEmpty) {
          final cookieManager = WebViewCookieManager();
          await cookieManager.setCookie(
            WebViewCookie(name: 'c_user', value: cUser, domain: '.facebook.com', path: '/'),
          );
          await cookieManager.setCookie(
            WebViewCookie(name: 'xs', value: xs, domain: '.facebook.com', path: '/'),
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading local session file: $e');
    }
  }

  void _toggleDesktopMode() async {
    setState(() {
      _isDesktopMode = !_isDesktopMode;
    });

    final targetUserAgent = _isDesktopMode ? _desktopUserAgent : _mobileUserAgent;
    await _controller.setUserAgent(targetUserAgent);
    _controller.reload();
  }

  void _toggleTvMouseMode() {
    setState(() {
      _isTvMouseMode = !_isTvMouseMode;
    });
  }

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
  }

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
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!_isTvMouseMode) return KeyEventResult.ignored;

    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      const double step = 20.0;
      setState(() {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          _cursorY = (_cursorY - step).clamp(0.0, MediaQuery.of(context).size.height);
        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _cursorY = (_cursorY + step).clamp(0.0, MediaQuery.of(context).size.height);
        } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          _cursorX = (_cursorX - step).clamp(0.0, MediaQuery.of(context).size.width);
        } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          _cursorX = (_cursorX + step).clamp(0.0, MediaQuery.of(context).size.width);
        } else if (event.logicalKey == LogicalKeyboardKey.select || 
                   event.logicalKey == LogicalKeyboardKey.enter ||
                   event.logicalKey == LogicalKeyboardKey.space) {
          _controller.runJavaScript('''
            var el = document.elementFromPoint($_cursorX, $_cursorY);
            if (el) {
              el.click();
              el.focus();
            }
          ''');
        }
      });
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        
        if (await _controller.canGoBack()) {
          _controller.goBack();
        } else {
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Focus(
        focusNode: _appFocusNode,
        onKeyEvent: _handleKeyEvent,
        child: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                  color: Colors.grey[900],
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, size: 20),
                        onPressed: _canGoBack ? () => _controller.goBack() : null,
                        tooltip: 'Back',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward, size: 20),
                        onPressed: _canGoForward ? () => _controller.goForward() : null,
                        tooltip: 'Forward',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                      IconButton(
                        icon: const Icon(Icons.home, size: 20),
                        onPressed: () => _loadUrl(_homeUrl),
                        tooltip: 'Home',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                      IconButton(
                        icon: Icon(_isDesktopMode ? Icons.desktop_windows : Icons.phone_android, size: 20),
                        onPressed: _toggleDesktopMode,
                        tooltip: 'Toggle Desktop/Mobile Mode',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                      IconButton(
                        icon: Icon(_isTvMouseMode ? Icons.mouse : Icons.tv, size: 20, color: _isTvMouseMode ? Colors.cyanAccent : Colors.white),
                        onPressed: _toggleTvMouseMode,
                        tooltip: 'Toggle TV Mouse Mode',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                      IconButton(
                        icon: const Icon(Icons.vpn_key, size: 20),
                        onPressed: _showCredentialsDialog,
                        tooltip: 'Set Login Credentials',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: SizedBox(
                          height: 38,
                          child: TextField(
                            controller: _urlController,
                            focusNode: _urlFocusNode,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Search or enter address...',
                              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                              filled: true,
                              fillColor: Colors.grey[800],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6.0),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 0),
                            ),
                            onSubmitted: (value) => _loadUrl(value),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      WebViewWidget(controller: _controller),
                      if (_isTvMouseMode)
                        Positioned(
                          left: _cursorX - 12,
                          top: _cursorY - 12,
                          child: IgnorePointer(
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.cyanAccent.withOpacity(0.8),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.5),
                                    blurRadius: 6,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(Icons.navigation, size: 12, color: Colors.black),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
