# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Tencent Cloud TRTC & LiteAV SDK (Prevent R8 stripping native JNI classes)
-keep class com.tencent.** { *; }
-dontwarn com.tencent.**

# Flutter WebRTC
-keep class com.cloudwebrtc.webrtc.** { *; }
-keep class org.webrtc.** { *; }

# Permission Handler
-keep class com.baseflow.permissionhandler.** { *; }

# Firebase & Audio
-keep class com.google.firebase.** { *; }
-keep class com.ryanheise.** { *; }
-keep class xyz.luan.audioplayers.** { *; }
