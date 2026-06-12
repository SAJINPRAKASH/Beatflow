# 🎵 BeatFlow Music Player

A premium, neumorphic-designed music streaming and playback application built with **Flutter**, featuring real-time offline downloads, a native 5-band audio equalizer, and personalized interest-driven content curation.

---

## ✨ Key Features

### 🎨 Visual Excellence (Neumorphic Design)
*   **Aesthetic UI**: Smooth, premium neumorphic box decorations that feel tactile and responsive.
*   **Adaptive Themes**: Fully integrated light and dark modes with complete widget color inversion and automatic high-contrast settings.
*   **Smooth Animations**: Dynamic rotation effects on the player record plate synchronized with audio states.

### 📥 Robust Offline Download Manager
*   **Dio Streaming Integration**: Resilient downloading with custom HTTP request headers to bypass 403 stream blocks.
*   **Tracked Progress**: Real-time progress bars, percentage indicators, and active downloads queue in the library tab.
*   **Cancel & Clean Up**: Instant download termination with complete deletion of partial local cache files.

### 🎚️ Native 5-Band Equalizer (Android & iOS Fallback)
*   **Frequency Sliders**: Five-band sliders (60Hz, 230Hz, 910Hz, 4kHz, 14kHz) for exact decibel configurations (-10dB to +10dB).
*   **Response Visualizer**: Live CustomPaint painter rendering frequency response curves using quadratic Beziers.
*   **Pre-configured Presets**: One-tap settings for Rock, Pop, Jazz, Classical, and Bass Booster.

### 🎯 Hybrid Personalization Feed
*   **Onboarding Preferences**: Prompts users for favorite languages (Hindi, English, Malayalam, Tamil, Telugu, Punjabi, etc.) and artists.
*   **Blended Recommendations**: A hybrid feed algorithm interleaving selected genres/artists with track history seeds for instant discovery.

### 🔀 Advanced Queue Playback
*   **Dynamic Injection**: Options to **Play Next** (inserting right after the current track) or **Add to Queue** (appending to the end).
*   **Navigation Shortcuts**: Skip next/previous controls added to the expanded full-screen player and the persistent mini-player.

---

## 🏗️ Repository Folder Structure

The project strictly follows the **Feature-First** architecture pattern:

```text
lib/
├── core/
│   ├── navigation/        # GoRouter definition and paths mapping
│   └── theme/             # Neumorphic styling tokens, dark/light theme definitions
├── features/
│   ├── home/              # HomeScreen feeds and Preferences onboarding dialog
│   ├── library/           # Liked songs, playback history, and offline downloads lists
│   ├── player/            # Full Player screen, Mini player, and Waveform seekbar
│   ├── playlists/         # Playlist management dialogs and listings
│   ├── search/            # Search bar, suggestions, recent queries, and action menus
│   └── settings/          # Equalizer settings, Audio Quality, and credits screens
├── models/                # JSON serialization and data schema models
└── services/              # Audio playback pipeline, Hive databases, and Download manager
```

---

## 🛠️ Tech Stack & Dependencies

*   **Framework**: [Flutter](https://flutter.dev) (Dart)
*   **State Management**: [Flutter Riverpod](https://riverpod.dev) (Compile-safe, modular, and reactive state)
*   **Audio Pipeline**: [just_audio](https://pub.dev/packages/just_audio) & [audio_service](https://pub.dev/packages/audio_service) (Background playback, lock screen metadata, system integrations)
*   **Local Database**: [Hive](https://pub.dev/packages/hive) (Lightweight, ultra-fast key-value database for state retention)
*   **Network Client**: [Dio](https://pub.dev/packages/dio) (Advanced downloading, request interception, and cancelation tokens)
*   **YouTube Scraper**: [youtube_explode_dart](https://pub.dev/packages/youtube_explode_dart) (Video metadata scraping and official video player integration)
*   **Routing**: [GoRouter](https://pub.dev/packages/go_router) (Declarative routing)

---

## 🚀 Setup & Installation

### Prerequisites
*   [Flutter SDK](https://docs.flutter.dev/get-started/install) (Stable Channel)
*   Android Studio / Xcode (for device compilation)
*   Java Development Kit (JDK) for Gradle assembly

### Quick Start
1.  **Clone the Repository**
    ```bash
    git clone https://github.com/your-username/beatflow.git
    cd beatflow
    ```

2.  **Fetch Project Dependencies**
    ```bash
    flutter pub get
    ```

3.  **Run Code Analyzers**
    ```bash
    flutter analyze
    ```

4.  **Launch the Application**
    *   To run on a connected emulator/device:
        ```bash
        flutter run
        ```
    *   To run in release mode for production:
        ```bash
        flutter run --release
        ```

---

## 📱 Platform Configuration

### Android Setup
*   Permissions configured in `android/app/src/main/AndroidManifest.xml`:
    ```xml
    <!-- System audio settings for Equalizer control -->
    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
    <!-- Network access for streaming -->
    <uses-permission android:name="android.permission.INTERNET" />
    ```
*   Minimum Android SDK: `API 21` (configured in `android/app/build.gradle`).

### iOS Setup
*   Ensure background audio modes are checked under Xcode *Signing & Capabilities*:
    *   `Audio, AirPlay, and Picture in Picture`
*   Add key permission usage strings to your `ios/Runner/Info.plist`.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
