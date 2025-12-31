# App Store Connect Setup Guide

## Step 1: Apple Developer Account
1. Go to [developer.apple.com](https://developer.apple.com)
2. Sign up for Apple Developer Program ($99/year)
3. Complete verification process

## Step 2: App Store Connect Setup
1. Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
2. Sign in with your Apple Developer Account
3. Click "My Apps" → "+" → "New App"

## Step 3: App Information
Fill in the following information:

### Basic Information
- **Name:** Smart Bill Splitter
- **Primary Language:** English (U.S.)
- **Bundle ID:** com.mustafa.billsplitter (or your unique identifier)
- **SKU:** smart-bill-splitter-001
- **User Access:** Full Access

### App Information
- **Category:** Productivity
- **Content Rights:** No, I do not use third-party content
- **Age Rating:** 4+ (No objectionable content)

## Step 4: Pricing and Availability
- **Price:** Free
- **Availability:** All countries and regions
- **Release:** Manual release after review

## Step 5: App Store Information

### App Store Listing
- **App Name:** Smart Bill Splitter
- **Subtitle:** AI-Powered Bill Splitting
- **Description:** [Use the description from app_store_metadata.md]
- **Keywords:** bill splitter,expense tracker,group expenses,restaurant bill,AI scanner
- **Support URL:** [Your support website]
- **Marketing URL:** [Your marketing website]
- **Privacy Policy URL:** [Your privacy policy URL]

### App Review Information
- **Contact Information:** [Your email]
- **Demo Account:** Not required
- **Notes:** [Use notes from app_store_metadata.md]

## Step 6: Upload App Binary

### Method 1: Using Xcode (Recommended)
1. Open your project in Xcode
2. Select "Any iOS Device" as target
3. Product → Archive
4. Wait for archive to complete
5. Click "Distribute App"
6. Select "App Store Connect"
7. Follow the upload wizard

### Method 2: Using Application Loader
1. Download Application Loader from App Store Connect
2. Build your app: `flutter build ios --release`
3. Create .ipa file
4. Upload using Application Loader

## Step 7: App Store Assets

### App Icon
- **Size:** 1024 x 1024 pixels
- **Format:** PNG or JPEG
- **No transparency or alpha channels**
- **No rounded corners (Apple adds them automatically)**

### Screenshots
Upload screenshots for:
- iPhone 15 Pro Max (6.7")
- iPhone 15 Pro (6.1")
- iPhone 15 (6.1")
- iPhone 15 Plus (6.7")

### App Preview (Optional)
- 30-second video showing app in action
- MP4 or MOV format
- Same sizes as screenshots

## Step 8: Submit for Review

1. Complete all required fields
2. Upload all assets
3. Review your app information
4. Click "Submit for Review"
5. Wait for Apple's review (1-7 days typically)

## Step 9: After Approval

1. **Release:** Choose "Release This Version" or "Release Automatically"
2. **Monitor:** Check App Store Connect for downloads and reviews
3. **Update:** Plan future updates and improvements

## Important Notes

- **Review Process:** Can take 1-7 days
- **Rejections:** Common reasons include missing privacy policy, unclear functionality, or guideline violations
- **Updates:** You can update your app after it's live
- **Analytics:** Use App Store Connect analytics to track performance

## Common Issues and Solutions

### Code Signing Issues
- Make sure your Apple Developer Account is active
- Check that your Bundle ID matches in Xcode and App Store Connect
- Ensure certificates are valid

### Upload Issues
- Use Xcode for uploading (most reliable)
- Check internet connection
- Try uploading during off-peak hours

### Review Rejections
- Read Apple's feedback carefully
- Address all issues mentioned
- Resubmit with explanations

## Support Resources

- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [App Store Connect Help](https://help.apple.com/app-store-connect/)
