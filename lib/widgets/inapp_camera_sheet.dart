import 'dart:io';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';

class InAppCameraScreen extends StatelessWidget {
  const InAppCameraScreen({super.key});

  static Future<File?> show(BuildContext context) async {
    final String? path = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const InAppCameraScreen(),
      ),
    );
    if (path != null && path.isNotEmpty) {
      return File(path);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            CameraAwesomeBuilder.awesome(
              saveConfig: SaveConfig.photo(),
              onMediaTap: (mediaCapture) {
                final path = mediaCapture.captureRequest.path;
                if (path != null && path.isNotEmpty) {
                  Navigator.of(context).pop(path);
                }
              },
            ),
            Positioned(
              top: 12,
              left: 12,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
