import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'update_service.dart';

// WebSocket packages for phone-to-TV sync
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:network_info_plus/network_info_plus.dart';

// QR Code packages
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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
  
  static const String _desktopUserAgent = 
      "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";
  static const String _mobileUserAgent = 
      "Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36";

  @override
  void initState() {
    super.initState();
    _urlController.text = _homeUrl;
    _checkIfTvDevice();

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
      
      _showStartupSetupMenu(context);
      FocusScope.of(context).requestFocus(_appFocusNode);
    });
  }

  Future<void> _checkIfTvDevice() async {
    try {
      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        final bool isTv = androidInfo.systemFeatures.contains('android.software.leanback') ||
                          androidInfo.systemFeatures.contains('com.google.android.tv');
        if (isTv) {
          setState(() {
            _isTvMouseMode = true;
          });
          _showToast('📺 TV Detected: Mouse & D-Pad active');
        }
      } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        setState(() {
          _isTvMouseMode = true;
        });
      }
    } catch (e) {
      debugPrint('Device check error: $e');
    }
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
                    icon: const Icon(Icons.tv),
                    label: const Text('TV Hosting Mode (Show QR)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TvPairingScreen(
                            onSynced: (rawData) {
                              _injectProfileDataDirectly(rawData);
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Phone Push Mode (Scan QR)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PhonePairingScreen(
                            webController: _controller,
                            showToast: _showToast,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
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

  Future<void> _injectProfileDataDirectly(String rawData) async {
    try {
      final Map<String, dynamic> data = jsonDecode(rawData);
      final String rawCookies = data['cookies'] ?? '';
      final Map<String, dynamic> localStore = data['localStorage'] ?? {};
      final Map<String, dynamic> sessionStore = data['sessionStorage'] ?? {};

      // 1. Restore Cookies via CookieManager
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

      // 2. Setup navigation delegate to restore LocalStorage and SessionStorage upon reaching Facebook
      _controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            if (_isAdOrTracker(request.url)) return NavigationDecision.prevent;
            return NavigationDecision.navigate;
          },
          onPageFinished: (String url) async {
            if (url.contains('facebook.com')) {
              StringBuffer jsBuilder = StringBuffer();

              // Rebuild LocalStorage items
              localStore.forEach((key, val) {
                final sKey = key.replaceAll("'", "\\'");
                final sVal = val.toString().replaceAll("'", "\\'");
                jsBuilder.write("window.localStorage.setItem('$sKey', '$sVal');\n");
              });

              // Rebuild SessionStorage items
              sessionStore.forEach((key, val) {
                final sKey = key.replaceAll("'", "\\'");
                final sVal = val.toString().replaceAll("'", "\\'");
                jsBuilder.write("window.sessionStorage.setItem('$sKey', '$sVal');\n");
              });

              await _controller.runJavaScript(jsBuilder.toString());
              debugPrint('✅ Full browser storage profile reconstructed.');
            }
          },
        ),
      );

      _showToast('✅ Profile synced! Loading feed...');
      _controller.loadRequest(Uri.parse('https://m.facebook.com/'));
      
    } catch (e) {
      debugPrint('Error restoring profile payload: $e');
      _showToast('❌ Failed to parse session profile');
    }
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
        
        // Handle full profile json format if loaded from file
        if (decodedData is Map && decodedData.containsKey('cookies')) {
          _injectProfileDataDirectly(contents);
          return;
        }

        // Fallback for older cookie-only json files
        final cookieManager = WebViewCookieManager();
        List<dynamic> cookiesList = [];

        if (decodedData is List) {
          cookiesList = decodedData;
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
          _controller.loadRequest(Uri.parse('https://m.facebook.com/'));
        } else {
          _showToast('⚠ No valid cookies found in JSON');
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

// =========================================================================
// Dedicated Full-Screen TV Hosting Screen (Displays Large QR Code & Server)
// =========================================================================
class TvPairingScreen extends StatefulWidget {
  final Function(String) onSynced;
  const TvPairingScreen({super.key, required this.onSynced});

  @override
  State<TvPairingScreen> createState() => _TvPairingScreenState();
}

class _TvPairingScreenState extends State<TvPairingScreen> {
  HttpServer? _server;
  String _wsAddress = 'Initializing network...';
  bool _isConnected = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _startServer();
  }

  Future<void> _startServer() async {
    try {
      await Permission.location.request();

      final info = NetworkInfo();
      String? ip;
      try {
        ip = await info.getWifiIP();
      } catch (e) {
        debugPrint('NetworkInfo error: $e');
      }

      ip ??= '192.168.1.100';
      const int port = 8080;
      _wsAddress = 'ws://$ip:$port';

      var handler = webSocketHandler((WebSocketChannel webSocket) {
        if (mounted) {
          setState(() {
            _isConnected = true;
          });
        }
        webSocket.stream.listen((message) async {
          try {
            widget.onSynced(message.toString());
            webSocket.sink.add('SUCCESS');
            await Future.delayed(const Duration(milliseconds: 600));
            if (mounted) Navigator.pop(context);
          } catch (e) {
            debugPrint('Error syncing: $e');
          }
        });
      });

      _server = await shelf_io.serve(handler, '0.0.0.0', port);
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Failed to start server: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _wsAddress = 'Server Error: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _server?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TV Companion Hosting Mode'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.grey[900],
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _hasError
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    Text(
                      _wsAddress,
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Scan this QR code with your phone app to sync profile:',
                      style: TextStyle(fontSize: 18, color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SizedBox(
                        width: 220,
                        height: 220,
                        child: QrImageView(
                          data: _wsAddress,
                          version: QrVersions.auto,
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SelectableText(
                      _wsAddress, 
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.cyanAccent),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isConnected ? '✅ Connected! Processing sync...' : '⏳ Waiting for incoming phone connection...',
                      style: TextStyle(
                        fontSize: 15, 
                        color: _isConnected ? Colors.greenAccent : Colors.orangeAccent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// =========================================================================
// Dedicated Full-Screen Phone Scanner Screen (Camera QR Code Reader)
// =========================================================================
class PhonePairingScreen extends StatefulWidget {
  final WebViewController webController;
  final Function(String) showToast;

  const PhonePairingScreen({
    super.key, 
    required this.webController, 
    required this.showToast,
  });

  @override
  State<PhonePairingScreen> createState() => _PhonePairingScreenState();
}

class _PhonePairingScreenState extends State<PhonePairingScreen> {
  bool _hasPermission = false;
  bool _hasScanned = false;
  late final MobileScannerController _scannerController;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController();
    _checkCameraPermission();
  }

  Future<void> _checkCameraPermission() async {
    final status = await Permission.camera.request();
    setState(() {
      _hasPermission = status.isGranted;
    });
    if (!status.isGranted) {
      widget.showToast('⚠️ Camera permission is required to scan QR codes');
    }
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan TV QR Code'),
        backgroundColor: Colors.black,
      ),
      body: _hasPermission
          ? MobileScanner(
              controller: _scannerController,
              onDetect: (capture) async {
                if (_hasScanned) return;
                
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  final String? rawValue = barcode.rawValue;
                  if (rawValue != null && (rawValue.startsWith('ws://') || rawValue.startsWith('wss://'))) {
                    _hasScanned = true;
                    await _scannerController.stop();
                    
                    if (mounted) {
                      Navigator.pop(context);
                    }
                    
                    _sendBrowserProfileOverWebSocket(rawValue);
                    return;
                  }
                }
              },
            )
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.camera_alt, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'Camera permission is needed to scan the QR code.',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                      onPressed: _checkCameraPermission,
                      child: const Text('Grant Permission'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _sendBrowserProfileOverWebSocket(String wsUrl) async {
    try {
      // Deep profile capture script: grabs Cookies, LocalStorage, and SessionStorage
      final profileScript = '''
        (function() {
          var profile = {
            cookies: document.cookie,
            localStorage: {},
            sessionStorage: {}
          };

          for (var i = 0; i < localStorage.length; i++) {
            var key = localStorage.key(i);
            profile.localStorage[key] = localStorage.getItem(key);
          }

          for (var j = 0; j < sessionStorage.length; j++) {
            var sKey = sessionStorage.key(j);
            profile.sessionStorage[sKey] = sessionStorage.getItem(sKey);
          }

          return JSON.stringify(profile);
        })();
      ''';

      final result = await widget.webController.runJavaScriptReturningResult(profileScript);
      String cleanJson = result.toString();
      
      if (cleanJson.startsWith('"') && cleanJson.endsWith('"')) {
        cleanJson = cleanJson.substring(1, cleanJson.length - 1)
            .replaceAll(r'\"', '"')
            .replaceAll(r'\\', '\\');
      }

      if (cleanJson.isEmpty || cleanJson == 'null') {
        widget.showToast('⚠ No active browser profile found to push');
        return;
      }

      final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      channel.sink.add(cleanJson);
      widget.showToast('📤 Pushing full browser profile to TV...');

      channel.stream.listen((message) {
        if (message.toString() == 'SUCCESS') {
          widget.showToast('✅ Profile successfully pushed to TV!');
          channel.sink.close();
        }
      }, onError: (error) {
        widget.showToast('❌ Sync connection error');
        debugPrint('WS Error: $error');
      });
    } catch (e) {
      debugPrint('Error sending profile: $e');
      widget.showToast('❌ Failed to connect to TV address');
    }
  }
}
