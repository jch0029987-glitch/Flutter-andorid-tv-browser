import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart'; // Required for TV detection

class UpdateService {
  static const String repoOwner = 'jch0029987-glitch';
  static const String repoName = 'Flutter-android-tv-browser';

  /// Detects if the current running hardware is an Android TV (Leanback interface)
  static Future<bool> isAndroidTV() async {
    if (!Platform.isAndroid) return false;
    try {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      // Android TV boxes feature 'android.software.leanback'
      return androidInfo.systemFeatures.contains('android.software.leanback');
    } catch (e) {
      debugPrint('Error detecting device type: $e');
      return false;
    }
  }

  static Future<void> checkForUpdates(BuildContext context, {bool silent = true}) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/$repoOwner/$repoName/releases/latest'),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String latestTag = data['tag_name'] ?? 'v1.0.0';
        String latestVersion = latestTag.replaceAll(RegExp(r'^v'), '');

        final packageInfo = await PackageInfo.fromPlatform();
        String currentVersion = packageInfo.version;

        if (_isNewerVersion(latestVersion, currentVersion)) {
          List assets = data['assets'] ?? [];
          String? apkUrl;
          for (var asset in assets) {
            // Optional: Match custom file suffixes if you compile separate apks (e.g., -tv.apk or -mobile.apk)
            // For now, it pulls any valid .apk asset from your release
            if (asset['name'].toString().endsWith('.apk')) {
              apkUrl = asset['browser_download_url'];
              break;
            }
          }

          if (apkUrl != null && context.mounted) {
            bool isTv = await isAndroidTV();
            _showUpdateDialog(context, latestVersion, apkUrl, isTv);
          }
        } else {
          if (!silent && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('You are using the latest version!')),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to check for updates: $e');
    }
  }

  static bool _isNewerVersion(String latest, String current) {
    List<int> latestParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < 3; i++) {
      int l = i < latestParts.length ? latestParts[i] : 0;
      int c = i < currentParts.length ? currentParts[i] : 0;
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }

  /// Adapts dialog copy and focus criteria automatically based on device type
  static void _showUpdateDialog(BuildContext context, String version, String apkUrl, bool isTv) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(isTv ? '📺 Android TV Update Available' : '📱 Mobile Update Available'),
          content: Text(
            isTv 
              ? 'A new version ($version) is ready. Would you like to update your Android TV app now?' 
              : 'A new version ($version) is ready for your phone device. Install now?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Later'),
            ),
            ElevatedButton(
              autofocus: isTv, // Auto-focuses confirm button primarily if on TV D-pad
              onPressed: () {
                Navigator.of(context).pop();
                _downloadAndInstall(context, apkUrl);
              },
              child: const Text('Download & Install'),
            ),
          ],
        );
      },
    );
  }

  static Future<void> _downloadAndInstall(BuildContext context, String url) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Downloading update package...')),
      );

      final dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/update.apk';
      
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        await OpenFilex.open(filePath);
      }
    } catch (e) {
      debugPrint('Update installation failed: $e');
    }
  }
}
