#!/bin/bash
set -e

export ANDROID_HOME=/home/ubuntu/android-sdk
export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:/home/ubuntu/flutter/bin:$PATH
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

echo "=========================================================="
echo "🚀 Building KatsKlub Android ARM64 Release APK..."
echo "=========================================================="

cd /home/ubuntu/katsklub-flutter-app

# Build split ABI ARM64
flutter build apk --release --split-per-abi --target-platform android-arm64

ARM64_APK="/home/ubuntu/katsklub-flutter-app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"

if [ -f "$ARM64_APK" ]; then
    echo "Deleting old APK and copying new ARM64 build to web server..."
    sudo rm -f /var/www/html/katsklub-latest.apk
    sudo cp "$ARM64_APK" /var/www/html/katsklub-latest.apk
    sudo chmod 644 /var/www/html/katsklub-latest.apk
    
    FILE_SIZE=$(ls -lh /var/www/html/katsklub-latest.apk | awk '{print $5}')
    echo "=========================================================="
    echo "✅ SUCCESS! Latest ARM64 APK deployed!"
    echo "📦 File Size: $FILE_SIZE"
    echo "🔗 Download URL: https://katsklub.top/katsklub-latest.apk"
    echo "=========================================================="
else
    echo "❌ Error: ARM64 APK file was not found."
    exit 1
fi
