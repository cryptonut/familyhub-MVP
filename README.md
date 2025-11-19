# Family Hub MVP

All-in-one family organizer: Calendar, Tasks, Chat, Location

## 📱 Overview

Family Hub is a comprehensive mobile application designed to help families stay organized and connected. The app provides four core features:

- **📅 Calendar**: Manage family events, appointments, and schedules
- **✅ Tasks**: Create and track shared family tasks and to-dos
- **💬 Chat**: Real-time family messaging and communication
- **📍 Location**: Share and view family member locations

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (>=3.0.0)
- Dart SDK (>=3.0.0)
- Android Studio / VS Code with Flutter extensions
- iOS development tools (for iOS development on macOS)
- Firebase account (for authentication and data storage)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/cryptonut/familyhub-MVP.git
   cd familyhub-MVP
   ```

2. **Set up Firebase**
   - Follow the instructions in [FIREBASE_SETUP.md](FIREBASE_SETUP.md)
   - Create a Firebase project
   - Add Firebase configuration files for your platform(s)
   - Enable Email/Password authentication
   - Set up Firestore database

3. **Install dependencies**
   ```bash
   flutter pub get
   ```

4. **Run the app**
   ```bash
   flutter run
   ```

## 📁 Project Structure

```
familyhub-MVP/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── models/                   # Data models
│   ├── screens/                  # UI screens
│   │   ├── home_screen.dart      # Main navigation screen
│   │   ├── calendar/             # Calendar feature screens
│   │   ├── tasks/                # Tasks feature screens
│   │   ├── chat/                 # Chat feature screens
│   │   └── location/             # Location feature screens
│   ├── services/                 # Business logic & API services
│   ├── widgets/                  # Reusable UI components
│   └── utils/                    # Utility functions
├── test/                         # Unit and widget tests
├── pubspec.yaml                  # Dependencies and project config
└── analysis_options.yaml         # Linting rules
```

## 🛠️ Tech Stack

- **Framework**: Flutter
- **Language**: Dart
- **State Management**: Provider
- **Backend**: Firebase (Authentication + Firestore)
- **HTTP Client**: Dio, HTTP
- **Local Storage**: SharedPreferences (for caching)
- **Location Services**: Geolocator, Google Maps
- **Real-time Communication**: Firestore Streams

## 📦 Key Dependencies

- `provider`: State management
- `firebase_core`: Firebase initialization
- `firebase_auth`: User authentication
- `cloud_firestore`: Cloud database with real-time sync
- `geolocator`: Location services
- `google_maps_flutter`: Map integration
- `table_calendar`: Calendar widget

## 🏗️ Development

### Running the App

```bash
# Run on connected device/emulator
flutter run

# Run in release mode
flutter run --release

# Run with specific device
flutter run -d <device-id>
```

### Building the App

```bash
# Build APK for Android
flutter build apk

# Build iOS app (macOS only)
flutter build ios

# Build app bundle for Play Store
flutter build appbundle
```

### Code Generation

If using code generation (e.g., Hive adapters):

```bash
flutter pub run build_runner build
```

### Testing

```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage
```

## 📝 Features Status

- [x] Project setup and structure
- [x] Basic navigation and UI scaffold
- [x] Calendar feature implementation
- [x] Tasks feature implementation
- [x] Chat feature implementation
- [x] Location feature implementation
- [x] User authentication (Firebase Auth)
- [x] Backend integration (Firestore)
- [x] Real-time data sync
- [x] Data persistence
- [ ] Push notifications
- [ ] Family invitation system
- [ ] Google Maps integration

## 🔒 Security

- Environment variables are stored in `.env` files (not committed to git)
- API keys should be stored securely and never hardcoded
- Use secure storage for sensitive user data

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👤 Author

Simon Case

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- All open-source contributors whose packages make this project possible

---

**Note**: This is an MVP (Minimum Viable Product) and is actively under development.
