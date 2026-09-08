# ==========================================================
# KatsKlub Android Proguard / R8 Configuration
# ==========================================================

# 1. Flutter Framework & Plugins
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# 2. Tencent Cloud TRTC, LiteAV & Live Plugins
-keep class com.tencent.** { *; }
-dontwarn com.tencent.**
-keep class com.tencent.liteav.** { *; }
-dontwarn com.tencent.liteav.**
-keep class com.tencent.trtcplugin.** { *; }
-dontwarn com.tencent.trtcplugin.**
-keep class com.tencent.live2.** { *; }
-dontwarn com.tencent.live2.**
-keep class com.tencent.live.beauty.** { *; }
-dontwarn com.tencent.live.beauty.**

# 3. Preserve all Native (JNI) methods and classes
-keepclasseswithmembernames class * {
    native <methods>;
}

# 4. WebRTC
-keep class com.cloudwebrtc.webrtc.** { *; }
-keep class org.webrtc.** { *; }
-dontwarn org.webrtc.**

# 5. Permission Handler
-keep class com.baseflow.permissionhandler.** { *; }
-dontwarn com.baseflow.permissionhandler.**

# 6. Firebase & Audio
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.ryanheise.** { *; }
-keep class xyz.luan.audioplayers.** { *; }
-dontwarn xyz.luan.audioplayers.**
