#!/bin/bash

echo "🚀 Installing Flutter for Bill Splitter App"
echo "=========================================="

# Check if Flutter is already installed
if command -v flutter &> /dev/null; then
    echo "✅ Flutter is already installed!"
    flutter --version
    exit 0
fi

echo "📥 Downloading Flutter SDK..."

# Create flutter directory in home
mkdir -p ~/flutter

# Download Flutter (ARM64 version for M1/M2 Macs)
cd ~/flutter
curl -L https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_arm64_3.24.5-stable.zip -o flutter.zip

echo "📦 Extracting Flutter..."
unzip -q flutter.zip
rm flutter.zip

# Add Flutter to PATH
echo "🔧 Adding Flutter to PATH..."
echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.zshrc

# Reload shell configuration
source ~/.zshrc

echo "✅ Flutter installation complete!"
echo ""
echo "Next steps:"
echo "1. Install Xcode from App Store (if not already installed)"
echo "2. Run: flutter doctor"
echo "3. Run: flutter pub get"
echo "4. Connect your iPhone and run: flutter run"
echo ""
echo "To test the app, run:"
echo "cd /Users/mustafa/Downloads/bill_splitter_flutter"
echo "flutter run"
