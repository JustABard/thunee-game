# Building Release APK for Thunee Game

This guide explains how to build a signed release APK for the Thunee Game Flutter application.

## Prerequisites

Before building a release APK, ensure you have:

- Flutter SDK installed and configured
- Android SDK installed (via Android Studio or command-line tools)
- Java Development Kit (JDK) 17 or higher
- A physical device or emulator for testing

## Step 1: Generate a Signing Key

A release APK must be signed with a private key. You'll need to create a keystore file containing this key.

### Create a Keystore File

Run the following command to generate a keystore:

```bash
keytool -genkey -v -keystore ~/thunee-game-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias thunee-game
```

You'll be prompted to enter:
- **Keystore password**: Choose a strong password and remember it
- **Key password**: Can be the same as keystore password
- **Name, Organization, City, State, Country**: Fill in your details

**Important**: Keep your keystore file (`thunee-game-key.jks`) secure and never commit it to version control. If you lose this file, you won't be able to update your app on the Play Store.

### Alternative Location

If you prefer to store the keystore in the project directory (not recommended for production):

```bash
keytool -genkey -v -keystore ./android/app/thunee-game-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias thunee-game
```

## Step 2: Create Key Properties File

Create a file named `key.properties` in the `android/` directory with the following content:

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=thunee-game
storeFile=/path/to/thunee-game-key.jks
```

Replace:
- `YOUR_KEYSTORE_PASSWORD` with your keystore password
- `YOUR_KEY_PASSWORD` with your key password
- `/path/to/thunee-game-key.jks` with the absolute path to your keystore file

**Important**: Never commit `key.properties` to version control. It should be listed in `.gitignore`.

## Step 3: Configure Gradle for Signing

The `android/app/build.gradle.kts` file should be configured to read the signing configuration from `key.properties`.

Add the following code before the `android` block:

```kotlin
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = java.util.Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(java.io.FileInputStream(keystorePropertiesFile))
}
```

Then update the `android` block to include signing configurations:

```kotlin
android {
    // ... existing configuration ...

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // Enable code shrinking, obfuscation, and optimization
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}
```

## Step 4: Build the Release APK

Now you're ready to build the release APK!

### Option A: Using Flutter Command (Recommended)

```bash
flutter build apk --release
```

This will build a single APK that works on all supported architectures (arm64-v8a, armeabi-v7a, x86_64).

### Option B: Build Split APKs (Smaller File Size)

To build separate APKs for each architecture (recommended for Play Store):

```bash
flutter build apk --release --split-per-abi
```

This creates three APKs:
- `app-armeabi-v7a-release.apk` (32-bit ARM)
- `app-arm64-v8a-release.apk` (64-bit ARM)
- `app-x86_64-release.apk` (64-bit x86)

### Option C: Build App Bundle (Recommended for Google Play)

For Google Play Store distribution, build an Android App Bundle:

```bash
flutter build appbundle --release
```

The App Bundle format (.aab) is more efficient and required by Google Play.

## Step 5: Locate the Built APK

After a successful build, you'll find the APK(s) at:

- **Single APK**: `build/app/outputs/flutter-apk/app-release.apk`
- **Split APKs**: `build/app/outputs/flutter-apk/app-{abi}-release.apk`
- **App Bundle**: `build/app/outputs/bundle/release/app-release.aab`

## Step 6: Test the Release APK

Before distributing, test the release APK on a physical device:

```bash
flutter install --release
```

Or manually install using adb:

```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

## Step 7: Verify APK Signing

To verify your APK is properly signed:

```bash
jarsigner -verify -verbose -certs build/app/outputs/flutter-apk/app-release.apk
```

You should see "jar verified" in the output.

## Troubleshooting

### Common Issues

1. **"Keystore file not found"**
   - Verify the path in `key.properties` is correct and absolute
   - Ensure the keystore file exists at the specified location

2. **"Cannot recover key"**
   - Check that the passwords in `key.properties` are correct
   - Ensure the key alias matches the one used when creating the keystore

3. **Build fails with ProGuard errors**
   - Check `android/app/proguard-rules.pro` for necessary keep rules
   - Some Flutter plugins may require specific ProGuard rules

4. **APK size is too large**
   - Use `--split-per-abi` to create smaller APKs
   - Consider using app bundles for Play Store distribution
   - Review and remove unused assets and dependencies

5. **"Execution failed for task ':app:minifyReleaseWithR8'"**
   - Check for ProGuard/R8 configuration issues
   - Add necessary keep rules in `proguard-rules.pro`

## Security Best Practices

1. **Never commit sensitive files**:
   - `key.properties`
   - `*.jks` (keystore files)
   - Any file containing passwords or keys

2. **Backup your keystore**:
   - Store it in a secure location
   - Keep multiple encrypted backups
   - Document the passwords securely

3. **Use environment variables** (for CI/CD):
   ```bash
   export KEYSTORE_PASSWORD=your_password
   export KEY_PASSWORD=your_key_password
   export KEY_ALIAS=thunee-game
   export KEYSTORE_FILE=/path/to/keystore.jks
   ```

## Distribution

### Google Play Store

1. Build an app bundle: `flutter build appbundle --release`
2. Go to [Google Play Console](https://play.google.com/console)
3. Create a new app or select existing app
4. Upload the `.aab` file
5. Complete the store listing and publish

### Direct Distribution

1. Build APK: `flutter build apk --release`
2. Share the APK file directly with users
3. Users must enable "Install from Unknown Sources" on their devices

## Additional Resources

- [Flutter Deployment Documentation](https://docs.flutter.dev/deployment/android)
- [Android App Signing](https://developer.android.com/studio/publish/app-signing)
- [Google Play Console Help](https://support.google.com/googleplay/android-developer)

## Version Management

The app version is defined in `pubspec.yaml`:

```yaml
version: 1.0.0+1
```

Format: `major.minor.patch+buildNumber`

- `1.0.0` is the version name (shown to users)
- `1` is the build number (must be incremented for each release)

Update this before each release build.
