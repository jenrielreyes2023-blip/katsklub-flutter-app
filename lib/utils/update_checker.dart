import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateChecker {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static const String _versionUrl = 'https://katsklub.top/app-version.json';

  static Future<void> checkForUpdates() async {
    try {
      final cacheBusterUrl = '$_versionUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      final response = await http.get(Uri.parse(cacheBusterUrl)).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return;

      final data = json.decode(response.body);
      final String latestVersion = data['latestVersion'] ?? '1.0.0';
      final int latestBuildNumber = data['latestBuildNumber'] ?? 1;
      final String downloadUrl = data['downloadUrl'] ?? 'https://katsklub.top/katsklub-latest.apk';
      final String releaseNotes = data['releaseNotes'] ?? 'A new version of KatsKlub is available.';
      final bool forceUpdate = data['forceUpdate'] ?? false;

      final packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = packageInfo.version;
      final int currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 1;

      bool hasUpdate = false;
      if (latestBuildNumber > currentBuildNumber) {
        hasUpdate = true;
      } else {
        final latestParts = latestVersion.split('.').map(int.tryParse).toList();
        final currentParts = currentVersion.split('.').map(int.tryParse).toList();

        for (int i = 0; i < latestParts.length && i < currentParts.length; i++) {
          final lVal = latestParts[i] ?? 0;
          final cVal = currentParts[i] ?? 0;
          if (lVal > cVal) {
            hasUpdate = true;
            break;
          } else if (lVal < cVal) {
            break;
          }
        }
      }

      if (hasUpdate) {
        // Wait and retry up to 5 times (2.5s) if context is not registered yet
        for (int retry = 0; retry < 5; retry++) {
          final context = navigatorKey.currentContext;
          if (context != null && context.mounted) {
            _showUpdateDialog(context, latestVersion, downloadUrl, releaseNotes, forceUpdate);
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }
    } catch (_) {
      // Fail silently
    }
  }

  static void _showUpdateDialog(
    BuildContext context,
    String latestVersion,
    String downloadUrl,
    String releaseNotes,
    bool forceUpdate,
  ) {
    showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (context) {
        return PopScope(
          canPop: !forceUpdate,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            title: const Row(
              children: [
                Icon(
                  Icons.system_update_rounded,
                  color: Color(0xFFFF7A59),
                  size: 28,
                ),
                SizedBox(width: 10),
                Text(
                  'Update Available',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Version $latestVersion is now available.',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'What\'s New:',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF4B5563),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  releaseNotes,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    height: 1.4,
                    color: Color(0xFF4B5563),
                  ),
                ),
              ],
            ),
            actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            actions: [
              if (!forceUpdate)
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Later',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ElevatedButton(
                onPressed: () async {
                  final uri = Uri.parse(downloadUrl);
                  if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                    if (!forceUpdate && context.mounted) {
                      Navigator.of(context).pop();
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7A59),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: const Text(
                  'Update Now',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
