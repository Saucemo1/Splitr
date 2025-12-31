# 📱 Testing Bill Splitter on iPhone - Complete Guide

## Prerequisites

### 1. Install Flutter
Run the installation script:
```bash
./install_flutter.sh
```

Or manually:
1. Download Flutter from https://flutter.dev/docs/get-started/install/macos
2. Extract to `~/flutter`
3. Add to PATH: `export PATH="$PATH:$HOME/flutter/bin"`

### 2. Install Xcode
- Open App Store
- Search for "Xcode"
- Install (takes ~10GB, 30+ minutes)

### 3. Get Gemini API Key
1. Go to https://makersuite.google.com/app/apikey
2. Create a new API key
3. Set it as environment variable:
```bash
export GEMINI_API_KEY="your_api_key_here"
```

## iPhone Setup

### 1. Enable Developer Mode
1. Connect iPhone to Mac via USB
2. On iPhone: Settings → Privacy & Security → Developer Mode → Enable
3. Restart iPhone when prompted

### 2. Trust Computer
1. When connected, iPhone will ask "Trust This Computer?"
2. Tap "Trust" and enter passcode

### 3. Enable USB Debugging
1. iPhone: Settings → Privacy & Security → USB Accessories
2. Enable "Allow Accessories to Connect"

## Testing Steps

### 1. Check Flutter Setup
```bash
flutter doctor
```
Fix any issues shown (usually just need to accept Xcode licenses)

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Connect iPhone
```bash
flutter devices
```
You should see your iPhone listed

### 4. Run the App
```bash
flutter run
```
- Select your iPhone when prompted
- App will install and launch on your iPhone

### 5. Test Features

#### Camera Access
- Tap "Camera" button
- Allow camera permission when prompted
- Take a photo of a receipt/bill

#### Photo Library Access
- Tap "Upload" button
- Allow photo library permission
- Select a bill image from your photos

#### Bill Scanning
- Use a clear photo of a restaurant bill
- Wait for AI processing (may take 10-30 seconds)
- Verify items are extracted correctly

#### Adding People
- Add 2-3 people with different names
- Verify color-coded chips appear

#### Item Assignment
- Assign items to people using the chips
- Try both "Cost" and "Units" modes for multi-quantity items
- Verify calculations are correct

#### Split Results
- Check that totals add up correctly
- Test the "Select for Summing" feature
- Verify currency formatting

## Troubleshooting

### App Won't Install
- Check iPhone is unlocked
- Trust the computer again
- Restart both devices

### Camera/Photos Not Working
- Check permissions in iPhone Settings
- Restart the app
- Try a different photo

### AI Scanning Fails
- Check internet connection
- Verify API key is set correctly
- Try a clearer photo of the bill

### Build Errors
```bash
flutter clean
flutter pub get
flutter run
```

## Test Scenarios

### 1. Simple Restaurant Bill
- 2-3 items
- Clear prices
- Tax included
- 2-3 people

### 2. Complex Bill
- Multiple items with quantities
- Separate tax line
- Service charge
- 4+ people

### 3. Edge Cases
- Very small text
- Poor lighting
- Handwritten bills
- Different currencies

## Performance Testing

- Test with large bills (10+ items)
- Test with many people (5+)
- Test app responsiveness
- Test memory usage

## Ready for App Store?

Once testing is complete:
1. Build release version: `flutter build ipa --release`
2. Archive in Xcode
3. Upload to App Store Connect
4. Submit for review

## Support

If you encounter issues:
1. Check Flutter documentation
2. Verify all permissions are granted
3. Test with different bill types
4. Check network connectivity for AI features
