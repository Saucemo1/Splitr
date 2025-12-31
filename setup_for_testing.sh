#!/bin/bash

echo "🚀 Setting up Bill Splitter for iPhone Testing"
echo "=============================================="

# Check if Xcode license is accepted
echo "📋 Checking Xcode license..."
if ! xcodebuild -version &> /dev/null; then
    echo "❌ Xcode license not accepted yet."
    echo "Please run: sudo xcodebuild -license accept"
    echo "Then run this script again."
    exit 1
fi

echo "✅ Xcode license accepted!"

# Check Flutter
echo "🔍 Checking Flutter installation..."
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found in PATH"
    echo "Please run: source ~/.zshrc"
    exit 1
fi

echo "✅ Flutter found!"

# Run Flutter doctor
echo "🏥 Running Flutter doctor..."
flutter doctor

echo ""
echo "📱 Next steps for iPhone testing:"
echo "1. Connect your iPhone via USB"
echo "2. On iPhone: Settings → Privacy & Security → Developer Mode → Enable"
echo "3. Trust this computer when prompted"
echo "4. Get Gemini API key from: https://makersuite.google.com/app/apikey"
echo "5. Set API key: export GEMINI_API_KEY='your_key_here'"
echo "6. Run: flutter pub get"
echo "7. Run: flutter run"
echo ""
echo "🎯 Ready to test!"
