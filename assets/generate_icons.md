# App Icon Generation Guide

## Required Icon Sizes for iOS

### App Store Icon
- **1024 x 1024 pixels** - App Store listing

### App Icons (iOS)
- **180 x 180 pixels** - iPhone 6 Plus, 6s Plus, 7 Plus, 8 Plus, X, XS, XS Max, 11 Pro Max, 12 Pro Max, 13 Pro Max, 14 Plus, 15 Plus
- **167 x 167 pixels** - iPad Pro (12.9-inch)
- **152 x 152 pixels** - iPad Pro (11-inch)
- **120 x 120 pixels** - iPhone 6, 6s, 7, 8, X, XS, 11 Pro, 12, 12 Pro, 13, 13 Pro, 14, 15
- **87 x 87 pixels** - iPhone 6 Plus, 6s Plus, 7 Plus, 8 Plus, X, XS, XS Max, 11 Pro Max, 12 Pro Max, 13 Pro Max, 14 Plus, 15 Plus (Settings)
- **80 x 80 pixels** - iPad, iPad 2, iPad mini, iPad Air, iPad Pro (9.7-inch), iPad Pro (10.5-inch)
- **76 x 76 pixels** - iPad, iPad 2, iPad mini, iPad Air, iPad Pro (9.7-inch), iPad Pro (10.5-inch)
- **60 x 60 pixels** - iPhone 6, 6s, 7, 8, X, XS, 11 Pro, 12, 12 Pro, 13, 13 Pro, 14, 15 (Settings)
- **58 x 58 pixels** - iPhone 6 Plus, 6s Plus, 7 Plus, 8 Plus, X, XS, XS Max, 11 Pro Max, 12 Pro Max, 13 Pro Max, 14 Plus, 15 Plus (Settings)
- **40 x 40 pixels** - iPad, iPad 2, iPad mini, iPad Air, iPad Pro (9.7-inch), iPad Pro (10.5-inch) (Settings)
- **29 x 29 pixels** - iPhone 6, 6s, 7, 8, X, XS, 11 Pro, 12, 12 Pro, 13, 13 Pro, 14, 15 (Settings)
- **20 x 20 pixels** - iPad, iPad 2, iPad mini, iPad Air, iPad Pro (9.7-inch), iPad Pro (10.5-inch) (Settings)

## How to Generate Icons

### Option 1: Online Icon Generator
1. Go to [appicon.co](https://appicon.co) or [makeappicon.com](https://makeappicon.com)
2. Upload your 1024x1024 PNG icon
3. Download the generated icon set
4. Replace the icons in `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

### Option 2: Using ImageMagick (Command Line)
```bash
# Install ImageMagick first
brew install imagemagick

# Generate all sizes from your 1024x1024 source
convert app_icon_1024.png -resize 180x180 app_icon_180.png
convert app_icon_1024.png -resize 167x167 app_icon_167.png
convert app_icon_1024.png -resize 152x152 app_icon_152.png
convert app_icon_1024.png -resize 120x120 app_icon_120.png
convert app_icon_1024.png -resize 87x87 app_icon_87.png
convert app_icon_1024.png -resize 80x80 app_icon_80.png
convert app_icon_1024.png -resize 76x76 app_icon_76.png
convert app_icon_1024.png -resize 60x60 app_icon_60.png
convert app_icon_1024.png -resize 58x58 app_icon_58.png
convert app_icon_1024.png -resize 40x40 app_icon_40.png
convert app_icon_1024.png -resize 29x29 app_icon_29.png
convert app_icon_1024.png -resize 20x20 app_icon_20.png
```

### Option 3: Using Xcode
1. Open your project in Xcode
2. Go to `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
3. Drag and drop your 1024x1024 icon into the App Store slot
4. Xcode will automatically generate all required sizes

## Icon Requirements

- **Format:** PNG (no transparency)
- **No rounded corners** (Apple adds them automatically)
- **No drop shadows** (Apple adds them automatically)
- **High quality** and sharp at all sizes
- **Consistent design** across all sizes

## Testing Your Icons

1. Build and run your app on a device
2. Check the home screen icon
3. Check the settings icon
4. Check the app switcher icon
5. Make sure it looks good at all sizes
