# Codemagic Android release build

The repository now includes `codemagic.yaml` at its root. Codemagic detects this file when it is connected to a repository and uses the `android-release` workflow to run a stable Flutter build with Java 17.

## Connect the ZIP to Codemagic.io

Codemagic normally connects to a Git repository rather than building a ZIP directly. First extract `script_to_video_generator.zip` locally. Then create a new private GitHub repository, for example `script-to-video-generator`, and upload the extracted project contents so that `codemagic.yaml`, `pubspec.yaml`, `lib/`, and `android/` are at the repository root. Do not upload the ZIP as the only repository file.

On [Codemagic](https://codemagic.io), sign in, select **Add application**, choose the repository provider, authorize access to the new repository, select **Flutter** as the project type, and finish adding the application. The repository must contain `codemagic.yaml` in its root for the YAML workflow to be detected. [1] [2]

Open the application, select the `android-release` workflow, choose the `main` branch, and click **Start new build**. Because this project is not configured for Play Store signing, choose an unsigned release APK unless you add Android keystore credentials in Codemagic's code-signing settings. The build itself does not need a paid API key.

## Download the APK

After the build finishes, open the build details page and use the **Artifacts** section to download `app-release.apk`. The YAML publishes both the standard path and a wildcard release-APK path so the file remains downloadable if a future Flutter or flavor configuration changes the exact filename.

## Notes about permissions

The manifest includes `INTERNET` for the Pollinations image request and backward-compatible storage permissions for Android 9 and older. The current renderer writes to the app-private cache directory, so FFmpeg does not require a special Android permission. If a future version exports directly into shared media storage on Android 13+, add the appropriate MediaStore implementation rather than relying on the legacy storage permissions.

## References

[1]: https://docs.codemagic.io/yaml-quick-start/building-a-flutter-app/ "Codemagic Flutter apps quick start"
[2]: https://docs.codemagic.io/yaml-basic-configuration/yaml-getting-started/ "Codemagic YAML configuration"

## GitHub Actions build

The repository also includes `.github/workflows/android.yml`. Push the project to GitHub with the workflow file at that exact path, then open the repository's **Actions** tab. Select **Android Release APK**, choose **Run workflow**, select the branch, and start it. The workflow installs Java 17 and Flutter stable, generates missing Android platform files when the source archive does not contain the standard Gradle wrapper, runs `flutter pub get`, builds the release APK, and uploads `script-to-video-release-apk` as a downloadable artifact. Open the completed run, scroll to **Artifacts**, and download the ZIP containing `app-release.apk`.

The workflow also runs automatically for pushes and pull requests targeting `main`. It does not sign the APK for Google Play; configure a keystore separately if you need a signed production release.
