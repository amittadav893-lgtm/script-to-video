# Script to Video Generator

A local-first Android Flutter app that turns a text script into a portrait MP4. The app uses the Android device's native text-to-speech engine, downloads one visual from Pollinations.ai, and combines the visual and narration on-device with FFmpeg.

## What was corrected from the supplied source

The original snippet contained a Dart import typo (`dart0io`), did not verify HTTP failures, passed an unreliable audio filename to TTS, did not wait for the synthesized file to become available, and used a discontinued FFmpeg package name. This project fixes those issues and uses the maintained `ffmpeg_kit_flutter_new` package, whose API is compatible with the original FFmpegKit calls and includes the GPL codecs needed for `libx264`.

## Requirements

You need Flutter 3.19 or newer, an Android SDK, an Android device or emulator, and a device TTS engine with an English voice installed. Internet access is required only for the Pollinations visual download. No application API key is required by this project.

## Create the missing Flutter platform files

The sandbox used to prepare this source did not include the Flutter SDK, so the generated package is intentionally SDK-neutral and includes the application source and Android manifest. On a machine with Flutter installed, run these commands from the project directory:

```bash
flutter create --platforms=android .
flutter pub get
flutter run
```

The `flutter create` command supplies the standard Gradle wrapper, Android launcher resources, `MainActivity`, and generated build files without replacing `lib/main.dart` or `pubspec.yaml`.

## Build an APK

```bash
flutter clean
flutter pub get
flutter build apk --release
```

The release APK is written to `build/app/outputs/flutter-apk/release/app-release.apk`.

## Workflow

1. The user enters a script.
2. `flutter_tts` asks the Android native TTS engine to synthesize a WAV file in the app's temporary directory.
3. The app downloads a portrait JPEG from `https://image.pollinations.ai`.
4. `ffmpeg_kit_flutter_new` creates a 720×1280 H.264/AAC MP4 by looping the image until the narration ends.
5. The output path is displayed in the app. It is stored in the temporary app cache, so a production version should add a share/export action or copy the file into a persistent media directory.

## Important limitations

“100% free” describes the app's architecture and absence of paid API keys. The app still requires internet access for Pollinations, and that public service may change its availability, rate limits, models, or terms. Native TTS and FFmpeg are local, but the generated image is not local. The current implementation intentionally creates one visual for the entire script; a multi-scene version can split the script into paragraphs and render a timed image sequence.

## Files

| File | Purpose |
| --- | --- |
| `lib/main.dart` | Complete UI and generation pipeline |
| `pubspec.yaml` | Flutter dependencies and package metadata |
| `android/app/src/main/AndroidManifest.xml` | Internet permission and Android app metadata |
| `README.md` | Setup, build, workflow, and limitations |

## License note

Review the licenses of FFmpeg and the selected FFmpeg package before distributing the app commercially. The full-GPL package includes GPL codecs such as `libx264`.
