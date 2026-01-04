# Copilot Instructions for Flutter Development

## 🧩 Project Context
- **Framework**: Flutter (Dart SDK ^3.9.2)
- **Target Platforms**: Android & iOS only
- **Architecture**: Clean Architecture (feature-based separation)
- **State Management**: Provider pattern

---

## 📁 Project Structure
```
lib/
├── main.dart                 # Entry point
├── app.dart                  # App initialization & configuration
├── core/                     # Cross-cutting concerns
│   ├── constants.dart        # Global constants
│   ├── theme.dart            # Light/Dark theme setup
│   ├── theme_provider.dart   # Theme management via Provider
│   └── models/               # Global data models
├── features/                 # Feature-based modularization
│   ├── auth/                 # Authentication
│   ├── profile/              # User Profile
│   └── [feature_name]/       # Additional features
├── widgets/                  # Reusable widgets
└── l10n/                     # Localization files (.arb)
```

---

## ⚙️ Core Dependencies
| Category | Package | Version | Purpose |
|-----------|----------|---------|----------|
| Core | flutter | SDK | Framework |
| Localization | flutter_localizations | built-in | Localization support |
| Icons | cupertino_icons | latest | iOS-like icons |
| State Management | provider | ^6.1.2 | Reactive state management |
| Persistence | shared_preferences | ^2.2.3 | User preferences |
| i18n | intl | ^0.20.2 | Internationalization |
| Sharing | share_plus | ^10.0.2 | Content sharing |
| Linting | flutter_lints | ^5.0.0 | Code analysis |
| Testing | flutter_test | built-in | Unit & widget testing |

---

## 🧠 Development Patterns

### 1. Theming
- Dual theme support (light/dark)
- Persistent theme preference (SharedPreferences)
- Provider for reactive updates
- Centralized theme configuration

### 2. State Management
- Use **Provider** & **ChangeNotifier**
- Declare `MultiProvider` in app root
- Use `Consumer` for efficient widget rebuilds

### 3. Feature Architecture
Each feature module must include:
```
feature_name/
├── data/        # Data sources, repositories
├── domain/      # Entities & use cases
├── presentation/# UI, providers, pages
```

### 4. Localization
- `.arb` files under `lib/l10n/`
- Supported locales defined in `l10n.yaml`
- Use `AppLocalizations.of(context)`

---

## 🧩 Configuration Files

### `l10n.yaml`
```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
```

### `pubspec.yaml`
```yaml
flutter:
  generate: true
```

### `analysis_options.yaml`
```yaml
include: package:flutter_lints/flutter.yaml
```

---

## 💻 Build Configurations

### Android
- compileSdk: `flutter.compileSdkVersion`
- minSdk: `flutter.minSdkVersion`
- targetSdk: `flutter.targetSdkVersion`
- Java/Kotlin compatibility: VERSION_11
- Gradle with Kotlin DSL (`build.gradle.kts`)

### iOS
- Unique Bundle Identifier
- Permissions in `Info.plist`
- Assets, icons & launch images configured

---

## 🧪 Testing
- Unit Tests → `flutter_test`
- Widget Tests → UI component testing
- Integration Tests → End-to-end flow validation

---

## ⚡ Performance Best Practices
- Use `const` constructors whenever possible
- Cache large assets (e.g., `cached_network_image`)
- Lazy-load long lists (`ListView.builder`)
- Profile builds for performance monitoring

---

## ✍️ Coding Conventions

| Element | Convention |
|----------|-------------|
| Files | snake_case |
| Classes | PascalCase |
| Variables & Methods | camelCase |
| Constants | UPPER_CASE or camelCase |
| Comments | Descriptive & JSDoc-style for APIs |

---

## 🧭 Code Style Guidelines for Copilot
- Suggest Provider-based patterns by default.
- Prefer feature-based folder suggestions (avoid monolithic code).
- Generate tests when adding new providers or repositories.
- Encourage use of localization keys instead of hardcoded text.
- When generating UI, default to **StatelessWidget** unless stateful logic is required.
- Always wrap shared state in Provider or ChangeNotifier.

---

## 🧰 Additional Recommendations
- Keep `README.md` updated with environment setup.
- Use environment variables for sensitive keys.
- Avoid logic in UI widgets (move to providers or use cases).
- Follow SOLID principles within feature modules.

---
**Author**: Senior Flutter Developer (10+ years experience)
**Purpose**: Ensure AI-assisted code generation aligns with maintainable, scalable, and production-ready Flutter architecture.
