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
        child: CameraAwesomeBuilder.awesome(
          saveConfig: SaveConfig.photo(),
          onMediaTap: (mediaCapture) {
            final path = mediaCapture.filePath;
            if (path != null && path.isNotEmpty) {
              Navigator.of(context).pop(path);
            }
          },
          topActionsBuilder: (state) {
            return AwesomeTopActions(
              state: state,
              children: [
                AwesomeIconButton(
                  icon: Icons.close_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                AwesomeFlashButton(state: state),
                AwesomeAspectRatioButton(state: state),
              ],
            );
          },
        ),
      ),
    );
  }
}
