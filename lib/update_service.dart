import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart'; // Optional or parse manually

class UpdateService {
  // Replace with your actual GitHub owner and repo name
  static const String repoOwner = 'YOUR_GITHUB_USERNAME';
  static const String repoName = 'flutter_browser_next';

  static Future<void> checkForUpdates(BuildContext context, {bool silent = true}) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/$repoOwner/$repoName/releases/latest'),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String latestTag = data['tag_name'] ?? 'v1.0.0';
        // Clean up 'v' prefix if present (e.g., v1.0.1 -> 1.0.1)
        String latestVersion = latestTag.replaceAll(RegExp(r'^v'), '');

        // Get current running app version
        final packageInfo = await PackageInfo.fromPlatform();
        String currentVersion = packageInfo.version;

        if (_isNewerVersion(latestVersion, currentVersion)) {
          // Find the APK download URL from release assets
          List assets = data['assets'] ?? [];
          String? apkUrl;
          for (var asset in assets) {
            if (asset['name'].toString().endsWith('.apk')) {
              apkUrl = asset['browser_download_url'];
              break;
            }
          }

          if (apkUrl != null && context.mounted) {
            _showUpdateDialog(context, latestVersion, apkUrl);
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

  // Simple semantic version comparator
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

  // Remote-friendly TV Dialog prompting user to update
  static void _showUpdateDialog(BuildContext context, String version, String apkUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Update Available'),
          content: Text('A new version ($version) of Flutter Browser Next is available for your Android TV.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Later'),
            ),
            ElevatedButton(
              autofocus: true, // Focuses button automatically for TV D-pad accessibility
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
      // Show progress overlay or snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Downloading update in background...')),
      );

      final dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/update.apk';
      
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        // Launch installer package
        await OpenFilex.open(filePath);
      }
    } catch (e) {
      debugPrint('Update installation failed: $e');
    }
  }
}
