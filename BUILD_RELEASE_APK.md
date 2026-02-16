# Building Release APK for Thunee Game

This guide explains how to build a signed release APK for the Thunee Game Flutter application.

## Quick Start: GitHub Actions (Recommended for Mobile Users)

**Perfect for when you're on mobile!** The easiest way to build release APKs is using GitHub Actions, which builds automatically in the cloud. Jump to the [GitHub Actions Setup](#github-actions-automated-builds) section to get started.

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

## GitHub Actions Automated Builds

This project includes a GitHub Actions workflow that automatically builds release APKs in the cloud. This is ideal when:
- You're on mobile and can't build locally
- You want automated builds on every commit
- You need consistent build environments

### Setting Up GitHub Actions

#### Step 1: Generate a Keystore

First, you need to create a keystore on a computer (you only need to do this once):

```bash
keytool -genkey -v -keystore thunee-game-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias thunee-game
```

Save the keystore file and remember:
- The keystore password
- The key password
- The key alias (use: `thunee-game`)

#### Step 2: Convert Keystore to Base64

Convert your keystore to base64 so it can be stored in GitHub Secrets:

**On Linux/Mac:**
```bash
base64 thunee-game-key.jks | tr -d '\n' > keystore.base64.txt
```

**On Windows (PowerShell):**
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("thunee-game-key.jks")) | Out-File keystore.base64.txt
```

This creates a `keystore.base64.txt` file containing the encoded keystore.

#### Step 3: Add GitHub Secrets

1. Go to your GitHub repository
2. Click **Settings** > **Secrets and variables** > **Actions**
3. Click **New repository secret** and add these secrets:

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `KEYSTORE_BASE64` | Contents of `keystore.base64.txt` | Base64-encoded keystore |
| `KEYSTORE_PASSWORD` | Your keystore password | Password for the keystore |
| `KEY_PASSWORD` | Your key password | Password for the key |
| `KEY_ALIAS` | `thunee-game` | Alias used when creating keystore |

**Important**: Keep the `keystore.base64.txt` file secure and delete it after adding to GitHub Secrets.

#### Step 4: Trigger a Build

The workflow can be triggered in several ways:

**Option A: Manual Trigger (Best for Mobile)**
1. Go to **Actions** tab in your GitHub repository
2. Click **Build Release APK** workflow
3. Click **Run workflow** button
4. Select branch and click **Run workflow**

**Option B: Automatic on Push**
- The workflow automatically runs when you push to `main` or `master` branch

**Option C: Automatic on Tag**
- Create a version tag to trigger a release:
  ```bash
  git tag v1.0.0
  git push origin v1.0.0
  ```
- This also creates a GitHub Release with downloadable APKs

#### Step 5: Download Your APK

After the workflow completes:

1. Go to **Actions** tab in your repository
2. Click on the completed workflow run
3. Scroll to **Artifacts** section at the bottom
4. Download the APK or App Bundle:
   - `thunee-game-vX.X.X-release.apk` - Universal APK
   - `thunee-game-vX.X.X-release.aab` - App Bundle for Play Store
   - `thunee-game-vX.X.X-split-apks` - Smaller APKs for each architecture

**Artifacts are stored for 30 days.**

### What the Workflow Does

The GitHub Actions workflow automatically:
1. ✅ Sets up Java 17 and Flutter
2. ✅ Installs project dependencies
3. ✅ Runs code generation (`build_runner`)
4. ✅ Decodes your keystore from secrets
5. ✅ Creates the `key.properties` file
6. ✅ Builds signed release APK
7. ✅ Builds signed App Bundle (.aab)
8. ✅ Builds split APKs for each architecture
9. ✅ Uploads all builds as downloadable artifacts
10. ✅ Creates GitHub Release (when pushing tags)

### Using from Mobile

From your mobile device:

1. **Trigger Build**:
   - Open GitHub app or browser
   - Go to Actions tab
   - Run workflow manually

2. **Wait for Build** (usually 5-10 minutes):
   - You'll get a notification when complete
   - Or check the Actions tab for status

3. **Download APK**:
   - Open the completed workflow
   - Download artifact from Artifacts section
   - Extract APK from zip file
   - Install on your device

### Workflow File Location

The workflow is defined in:
```
.github/workflows/build-release-apk.yml
```

You can customize it to:
- Change trigger conditions
- Modify Flutter version
- Add additional build steps
- Change artifact retention period

### Security Notes for GitHub Actions

1. **Secrets are encrypted**: GitHub encrypts all secrets and they're never exposed in logs
2. **Keystore stays secure**: The base64 keystore is decoded only during the build and immediately discarded
3. **No local storage needed**: You don't need to store sensitive files on your device
4. **Audit trail**: All builds are logged and can be reviewed

### Troubleshooting GitHub Actions

**Workflow fails at "Decode keystore" step:**
- Verify `KEYSTORE_BASE64` secret is set correctly
- Ensure there are no extra spaces or newlines in the base64 string

**Workflow fails at "Build APK" step:**
- Check that all four secrets are set correctly
- Verify the `KEY_ALIAS` matches what you used when creating the keystore
- Check workflow logs for specific error messages

**Cannot find artifacts:**
- Artifacts are only available for 30 days
- Check that the workflow completed successfully
- Look in the workflow run details, not the Actions tab

**Want to build without signing:**
- Remove or leave empty the `KEYSTORE_BASE64` secret
- The workflow will build using debug signing (for testing only)

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
