import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'update_service.dart'; // Imported separately

// WebSocket packages for phone-to-TV sync
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:network_info_plus/network_info_plus.dart';

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
  
  final String _homeUrl = 'https://m.facebook.com/login';
  bool _canGoBack = false;
  bool _canGoForward = false;
  String _currentUrl = 'https://m.facebook.com/login';
  
  bool _isDesktopMode = false;
  bool _isTvMouseMode = false;
  
  double _cursorX = 300;
  double _cursorY = 300;

  String? _toastMessage;
  HttpServer? _tvServer;
  
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

    _initAppSequence();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        UpdateService.checkForUpdates(context, silent: true);
      } catch (_) {}
      
      // Show startup setup menu immediately on app launch
      _showStartupSetupMenu(context);
      
      FocusScope.of(context).requestFocus(_appFocusNode);
    });
  }

  Future<void> _initAppSequence() async {
    await _requestStoragePermission();
    _controller.loadRequest(Uri.parse(_homeUrl));
  }

  @override
  void dispose() {
    _urlController.dispose();
    _urlFocusNode.dispose();
    _appFocusNode.dispose();
    _tvServer?.close();
    super.dispose();
  }

  void _showToast(String message) {
    if (!mounted) return;
    setState(() {
      _toastMessage = message;
    });
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _toastMessage == message) {
        setState(() {
          _toastMessage = null;
        });
      }
    });
  }

  Future<void> _requestStoragePermission() async {
    try {
      if (Platform.isAndroid) {
        var status = await Permission.manageExternalStorage.status;
        if (!status.isGranted) {
          status = await Permission.manageExternalStorage.request();
        }
        
        if (!status.isGranted) {
          _showToast('⚠️ Please grant "All files access" for Downloads');
          await openAppSettings();
        }
      }
    } catch (e) {
      debugPrint('Permission request error: $e');
    }
  }

  // --- Startup Setup Menu ---
  void _showStartupSetupMenu(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.tv, color: Colors.cyanAccent, size: 28),
              SizedBox(width: 12),
              Text('Browser Setup Menu'),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome! Choose how you would like to load your session configuration:',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 20),

                // Option 1: Sync with Phone (WebSocket Server)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    autofocus: true,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.phone_android),
                    label: const Text('Sync Session with Phone', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pop(context);
                      _startTvSyncServer(context);
                    },
                  ),
                ),
                const SizedBox(height: 10),

                // Option 2: Load Local File (session_config.json)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.cyanAccent),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Load Local session_config.json', style: TextStyle(fontSize: 14)),
                    onPressed: () {
                      Navigator.pop(context);
                      _loadCookiesFromFile();
                    },
                  ),
                ),
                const SizedBox(height: 10),

                // Option 3: Skip / Browse Normally
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.web),
                    label: const Text('Skip / Browse Normally', style: TextStyle(fontSize: 14)),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- WebSocket Server Logic for TV Sync ---
  void _startTvSyncServer(BuildContext context) async {
    try {
      final info = NetworkInfo();
      String? ip = await info.getWifiIP();
      ip ??= '192.168.1.x';
      const int port = 8080;

      var handler = webSocketHandler((WebSocketChannel webSocket) {
        debugPrint('📱 Phone connected to TV WebSocket!');
        webSocket.stream.listen((message) async {
          try {
            await _injectCookieStringDirectly(message.toString());
            _showToast('✅ Synced successfully from phone!');
            webSocket.sink.add('SUCCESS');
            _tvServer?.close();
          } catch (e) {
            debugPrint('Error parsing synced cookies: $e');
          }
        });
      });

      _tvServer = await shelf_io.serve(handler, '0.0.0.0', port);
      
      if (context.mounted) {
        _showPairingDialog(context, 'ws://$ip:$port');
      }
    } catch (e) {
      debugPrint('Failed to start TV WebSocket server: $e');
      _showToast('❌ Could not start local server');
    }
  }

  void _showPairingDialog(BuildContext context, String wsAddress) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Text('📺 TV Companion Pairing'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Type this address into your phone companion app to sync login:'),
            const SizedBox(height: 12),
            SelectableText(
              wsAddress, 
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.cyanAccent),
            ),
            const SizedBox(height: 12),
            const Text('Waiting for phone connection...', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 20),
            // Optional helper button if testing on the phone itself
            OutlinedButton.icon(
              icon: const Icon(Icons.send),
              label: const Text('Simulate Push from Phone'),
              onPressed: () {
                Navigator.pop(context);
                _showPushDialog(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _tvServer?.close();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // --- Phone-Side Push Dialog with Smart URL Cleaner ---
  void _showPushDialog(BuildContext context) {
    final TextEditingController ipController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🚀 Push Session to TV'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the address shown on your Android TV:'),
            const SizedBox(height: 10),
            TextField(
              controller: ipController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                hintText: '192.168.1.50:8080 (or ws://...)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              String input = ipController.text.trim();
              Navigator.pop(context);

              // --- SMART URL CLEANER ---
              // Automatically strips out accidental mobile keyboard prefixes
              input = input.replaceAll('https://', '');
              input = input.replaceAll('http://', '');
              input = input.replaceAll('wss://', '');
              input = input.replaceAll('ws://', '');
              
              if (input.endsWith('/')) {
                input = input.substring(0, input.length - 1);
              }

              String finalWsUrl = 'ws://$input';
              await _sendCookiesOverWebSocket(finalWsUrl);
            },
            child: const Text('Connect & Sync'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendCookiesOverWebSocket(String wsUrl) async {
    try {
      // 1. Grab current cookies from WebView JavaScript context
      final cookiesString = await _controller.runJavaScriptReturningResult('document.cookie');
      String cleanCookies = cookiesString.toString();
      
      // Strip potential wrapping quotes from JS evaluation output
      if (cleanCookies.startsWith('"') && cleanCookies.endsWith('"')) {
        cleanCookies = cleanCookies.substring(1, cleanCookies.length - 1);
      }

      if (cleanCookies.isEmpty || cleanCookies == 'null') {
        _showToast('⚠️ No active cookies found to push');
        return;
      }

      // 2. Open WebSocket channel to TV
      final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      // Send the cookie payload
      channel.sink.add(cleanCookies);
      _showToast('📤 Pushing session to TV...');

      // Listen for acknowledgement
      channel.stream.listen((message) {
        if (message.toString() == 'SUCCESS') {
          _showToast('✅ Successfully pushed to TV!');
          channel.sink.close();
        }
      }, onError: (error) {
        _showToast('❌ Sync connection error');
        debugPrint('WS Error: $error');
      });
    } catch (e) {
      debugPrint('Error sending cookies: $e');
      _showToast('❌ Failed to connect to TV address');
    }
  }

  Future<void> _injectCookieStringDirectly(String rawCookies) async {
    final cookieManager = WebViewCookieManager();
    List<String> pairs = rawCookies.split(';');

    for (String pair in pairs) {
      List<String> parts = pair.split('=');
      if (parts.length >= 2) {
        String name = parts[0].trim();
        String value = parts.sublist(1).join('=').trim();

        if (name.isNotEmpty && value.isNotEmpty) {
          await cookieManager.setCookie(
            WebViewCookie(name: name, value: value, domain: '.facebook.com', path: '/'),
          );
        }
      }
    }
    _controller.loadRequest(Uri.parse(_homeUrl));
  }

  Future<void> _loadCookiesFromFile() async {
    try {
      final List<String> possiblePaths = [
        '/storage/emulated/0/Download/session_config.json',
        '/storage/emulated/0/download/session_config.json',
        '/sdcard/Download/session_config.json',
        '/sdcard/download/session_config.json',
      ];

      File? targetFile;
      for (final path in possiblePaths) {
        try {
          final file = File(path);
          if (await file.exists()) {
            targetFile = file;
            break;
          }
        } catch (_) {}
      }

      if (targetFile != null) {
        final contents = await targetFile.readAsString();
        final decodedData = jsonDecode(contents);
        
        final cookieManager = WebViewCookieManager();
        List<dynamic> cookiesList = [];

        if (decodedData is List) {
          cookiesList = decodedData;
        } else if (decodedData is Map && decodedData.containsKey('cookies')) {
          cookiesList = decodedData['cookies'];
        } else if (decodedData is Map) {
          decodedData.forEach((key, value) {
            cookiesList.add({'name': key, 'value': value, 'domain': '.facebook.com', 'path': '/'});
          });
        }

        int injectedCount = 0;
        for (var cookieData in cookiesList) {
          final String name = cookieData['name'] ?? '';
          final String value = cookieData['value'] ?? '';
          String domain = cookieData['domain'] ?? '.facebook.com';
          final String path = cookieData['path'] ?? '/';

          if (name.isNotEmpty && value.isNotEmpty) {
            if (domain.contains('facebook.com')) {
              domain = '.facebook.com';
            } else if (!domain.startsWith('.')) {
              domain = '.$domain';
            }

            await cookieManager.setCookie(
              WebViewCookie(name: name, value: value, domain: domain, path: path),
            );
            injectedCount++;
          }
        }

        if (injectedCount > 0) {
          _showToast('🍪 Loaded $injectedCount Cookies Successfully!');
          _controller.loadRequest(Uri.parse(_homeUrl));
        } else {
          _showToast('⚠️ No valid cookies found in JSON');
          _controller.loadRequest(Uri.parse(_homeUrl));
        }
      } else {
        _showToast('⚠️ session_config.json not found in Download');
        _controller.loadRequest(Uri.parse(_homeUrl));
      }
    } catch (e) {
      debugPrint('Error loading local session file: $e');
      _showToast('❌ Error loading cookies');
      _controller.loadRequest(Uri.parse(_homeUrl));
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
                      if (_toastMessage != null)
                        Positioned(
                          bottom: 30,
                          left: 40,
                          right: 40,
                          child: Center(
                            child: Material(
                              color: Colors.transparent,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.cyanAccent, width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.6),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  _toastMessage!,
                                  style: const TextStyle(
                                    color: Colors.cyanAccent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
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
