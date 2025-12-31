# Splitr: Split Bills with OCR - Flutter iOS App

A Flutter application that uses AI-powered bill scanning to split restaurant bills and other expenses among multiple people. This app can be published to the iOS App Store.

## Features

- **AI-Powered Bill Scanning**: Uses Google's Gemini AI to extract bill details from photos
- **Smart Item Assignment**: Assign items to people by cost split or quantity
- **Automatic Calculations**: Handles taxes, tips, discounts, and service charges
- **Beautiful UI**: Modern Material Design 3 interface with dark/light theme support
- **iOS Optimized**: Native iOS experience with proper permissions and configurations

## Prerequisites

Before building and running this app, you need:

1. **Flutter SDK** (3.0.0 or higher)
2. **Xcode** (14.0 or higher) for iOS development
3. **Google Gemini API Key** for bill scanning functionality
4. **macOS** for iOS development

## Setup Instructions

### 1. Install Flutter

If you don't have Flutter installed:

```bash
# Install Flutter using Homebrew
brew install --cask flutter

# Or download from https://flutter.dev/docs/get-started/install/macos
```

### 2. Configure Gemini API Key

1. Get a Gemini API key from [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Set the API key as an environment variable:

```bash
export GEMINI_API_KEY="your_api_key_here"
```

### 3. Install Dependencies

```bash
cd bill_splitter_flutter
flutter pub get
```

### 4. iOS Configuration

The app is already configured for iOS with:
- Camera and photo library permissions
- Proper bundle identifier
- iOS deployment target 11.0+
- Network security settings

### 5. Run the App

```bash
# Run on iOS Simulator
flutter run

# Run on physical iOS device
flutter run --device-id=your_device_id
```

## Building for iOS App Store

### 1. Configure Signing

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select the Runner target
3. Go to "Signing & Capabilities"
4. Select your development team
5. Update the bundle identifier if needed

### 2. Build for Release

```bash
# Build iOS app
flutter build ios --release

# Build iOS app bundle for App Store
flutter build ipa --release
```

### 3. Archive and Upload

1. Open the project in Xcode
2. Select "Any iOS Device" as the target
3. Go to Product → Archive
4. Upload to App Store Connect

## App Structure

```
lib/
├── main.dart                 # App entry point
├── models/
│   ├── bill_models.dart     # Data models for bills and calculations
│   └── constants.dart       # App constants and color themes
├── services/
│   ├── gemini_service.dart  # AI bill scanning service
│   └── bill_processor.dart  # Bill calculation logic
├── screens/
│   └── bill_splitter_screen.dart # Main app screen
└── widgets/
    ├── spinner.dart         # Loading indicator
    └── alert_message.dart   # Alert/error messages
```

## Key Features Explained

### Bill Scanning
- Takes photos of restaurant bills or receipts
- Uses Gemini AI to extract items, prices, taxes, and totals
- Handles various bill formats and currencies

### Item Assignment
- **Cost Split Mode**: Split item cost equally among selected people
- **Quantity Mode**: Assign specific quantities to people (for multi-quantity items)
- Visual assignment with color-coded person chips

### Smart Calculations
- Proportional distribution of taxes, tips, and service charges
- Handles discounts and special charges
- Ensures totals match the original bill amount

### User Experience
- Intuitive step-by-step workflow
- Dark/light theme support
- Responsive design for different screen sizes
- Error handling with retry options

## Customization

### Colors and Themes
Edit `lib/models/constants.dart` to customize:
- Person color schemes
- App branding colors
- Theme preferences

### AI Prompt
Modify the Gemini prompt in `lib/models/constants.dart` to:
- Support different bill formats
- Handle specific currencies
- Adjust parsing accuracy

## Troubleshooting

### Common Issues

1. **API Key Not Working**
   - Ensure the environment variable is set correctly
   - Check that the API key has proper permissions
   - Verify network connectivity

2. **iOS Build Issues**
   - Clean and rebuild: `flutter clean && flutter pub get`
   - Check Xcode version compatibility
   - Verify signing configuration

3. **Camera Permissions**
   - Ensure Info.plist has proper permission descriptions
   - Test on physical device (simulator may not have camera)

### Debug Mode

Run in debug mode for detailed logging:

```bash
flutter run --debug
```

## Publishing to App Store

1. **Prepare App Store Assets**
   - App icon (1024x1024)
   - Screenshots for different device sizes
   - App description and keywords

2. **App Store Connect**
   - Create app listing
   - Set pricing and availability
   - Submit for review

3. **Review Guidelines**
   - Ensure app follows Apple's Human Interface Guidelines
   - Test thoroughly on different devices
   - Provide clear app description

## License

This project is open source and available under the MIT License.

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review Flutter documentation
3. Check iOS development guidelines
4. Test with different bill formats and currencies

## Future Enhancements

Potential features for future versions:
- Multiple bill support
- Export to PDF/email
- Payment integration
- Bill history and analytics
- Multi-language support
- Offline mode with sync
