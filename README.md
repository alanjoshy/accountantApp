# Accountant

A Flutter-based accounting application designed with a simple, scalable, and maintainable feature-first architecture.

The project is intentionally structured to keep the codebase easy to understand and extend without introducing unnecessary architectural complexity.

---

## Tech Stack

* **Flutter**
* **Dart**
* **Material 3**
* Android
* iOS
* Web
* macOS
* Windows
* Linux

---

## Project Structure

```text
accountant/
│
├── android/                       # Android application configuration
├── ios/                           # iOS application configuration
├── linux/                         # Linux application configuration
├── macos/                         # macOS application configuration
├── web/                           # Web application configuration
├── windows/                       # Windows application configuration
│
├── assets/                        # Application assets
│   ├── images/
│   ├── icons/
│   └── fonts/
│
├── lib/
│   │
│   ├── main.dart                  # Application entry point
│   │
│   ├── app/                       # Application-level configuration
│   │   │
│   │   ├── app.dart              # Root AccountantApp widget
│   │   ├── router.dart            # Application navigation/routes
│   │   │
│   │   ├── config/
│   │   │   ├── app_config.dart    # Application configuration
│   │   │   └── environment.dart   # Environment configuration
│   │   │
│   │   └── theme/
│   │       ├── app_theme.dart     # Global ThemeData
│   │       ├── app_colors.dart    # Application colors
│   │       ├── app_text_styles.dart # Typography
│   │       └── app_spacing.dart   # Standard spacing values
│   │
│   ├── core/                      # Shared technical functionality
│   │   │
│   │   ├── constants/
│   │   │   └── app_constants.dart
│   │   │
│   │   ├── errors/
│   │   │   └── app_exception.dart
│   │   │
│   │   ├── network/
│   │   │   ├── api_client.dart
│   │   │   └── api_exception.dart
│   │   │
│   │   ├── storage/
│   │   │   ├── local_storage.dart
│   │   │   └── secure_storage.dart
│   │   │
│   │   ├── utils/
│   │   │   └── validators.dart
│   │   │
│   │   └── widgets/
│   │       ├── app_button.dart
│   │       ├── loading_view.dart
│   │       └── error_view.dart
│   │
│   └── features/                  # Business features
│       │
│       ├── auth/
│       │   └── presentation/
│       │       ├── screens/
│       │       │   └── sign_in_screen.dart
│       │       │
│       │       └── widgets/
│       │           ├── auth_text_field.dart
│       │           └── google_sign_in_button.dart
│       │
│       └── home/
│           ├── data/
│           │   ├── datasources/
│           │   ├── models/
│           │   └── repositories/
│           │
│           ├── domain/
│           │   └── models/
│           │
│           └── presentation/
│               ├── screens/
│               └── widgets/
│
├── test/                          # Unit and widget tests
│
├── .gitignore                     # Git ignored files
├── .metadata                      # Flutter project metadata
├── analysis_options.yaml          # Dart analysis configuration
├── pubspec.yaml                   # Dependencies and project configuration
├── pubspec.lock                   # Locked dependency versions
└── README.md                      # Project documentation
```

---

## Architecture

The application follows a **feature-first architecture**.

The main idea is to organize code based on the business feature it belongs to rather than putting every screen, model, or service into one global folder.

```text
                    Accountant App
                          │
          ┌───────────────┴───────────────┐
          │                               │
        app/                             core/
          │                               │
   App configuration              Shared technical code
   Routing                         Network
   Theme                           Storage
   Environment                     Errors
                                   Utilities
          │
          └───────────────┬───────────────┘
                          │
                      features/
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
       auth             home             orders
        │
   presentation
        │
   ┌────┴────┐
screens    widgets
```

### Why Feature-First?

Feature-first organization makes it easier to:

* Find code quickly
* Add new business features
* Remove or modify a feature
* Keep related files together
* Avoid large global folders
* Reduce unnecessary coupling
* Scale the application gradually

---

## Folder Responsibilities

### `lib/main.dart`

The application entry point.

Responsibilities should remain minimal:

```text
main.dart
   ↓
AccountantApp
```

Do not put business logic here.

---

### `lib/app/`

Contains application-wide configuration.

Examples:

* Application initialization
* Routing
* Theme
* Environment configuration
* Global application settings

This folder should not contain feature-specific business logic.

---

### `lib/core/`

Contains functionality that is genuinely shared across multiple features.

Examples:

* API client
* Local storage
* Secure storage
* Common exceptions
* Validators
* Shared loading/error widgets
* Application constants

Avoid putting feature-specific code here just because it is convenient.

---

### `lib/features/`

Contains the application's actual business features.

Examples:

```text
features/
├── auth/
├── home/
├── customers/
├── products/
├── invoices/
├── expenses/
├── reports/
└── settings/
```

New features should be added only when they are actually required.

---

# Feature Structure

A feature can start small.

For example:

```text
features/
└── auth/
    └── presentation/
        ├── screens/
        │   └── sign_in_screen.dart
        │
        └── widgets/
            ├── auth_text_field.dart
            └── google_sign_in_button.dart
```

There is **no need to create data and domain layers until the feature actually requires them**.

When authentication becomes connected to the backend, it can evolve into:

```text
auth/
├── data/
│   ├── datasources/
│   ├── models/
│   └── repositories/
│
├── domain/
│   └── models/
│
└── presentation/
    ├── screens/
    └── widgets/
```

This allows the architecture to grow with the application instead of creating unnecessary files from the beginning.

---

## Current Authentication Flow

The current authentication screen contains:

```text
Sign In / Sign Up
        │
        ├── Name
        │
        ├── Email
        │
        ├── Continue
        │
        └── Continue with Google
```

Google authentication and backend integration will be implemented separately.

The current Google button is only the UI layer.

---

## Development Principles

The project follows a simple engineering approach.

### 1. Keep it simple

Do not introduce a package, abstraction, service, or architectural layer unless it solves a real problem.

### 2. Feature ownership

Feature-specific code should remain inside its feature.

For example:

```text
features/auth/
```

should contain authentication-related functionality.

### 3. Avoid unnecessary abstraction

Do not create:

```text
Service
Manager
Helper
Factory
Provider
Repository
UseCase
```

unless there is a clear responsibility for it.

### 4. Reuse intentionally

Move code into `core/` only when it is genuinely shared.

Do not move something into `core/` simply because it is currently used by two files.

### 5. Keep business logic separate from UI

Widgets should primarily handle presentation.

Business operations should eventually move into appropriate feature-level layers when they become complex.

### 6. No premature architecture

Start small:

```text
Screen
  ↓
Widget
```

Then introduce additional layers when real requirements appear:

```text
Screen
  ↓
Controller / State
  ↓
Repository
  ↓
API
```

---

## Running the Project

### Check Flutter installation

```bash
flutter doctor
```

### Install dependencies

```bash
flutter pub get
```

### Analyze the project

```bash
flutter analyze
```

### Run tests

```bash
flutter test
```

### Run the application

```bash
flutter run
```

---

## Hot Reload

While the application is running:

```text
r
```

Performs a hot reload.

```text
R
```

Performs a hot restart.

Hot reload is useful for quickly seeing UI/code changes without completely restarting the application.

---

## Git Workflow

Before committing changes:

```bash
git status
```

Analyze the project:

```bash
flutter analyze
```

Run tests:

```bash
flutter test
```

Then commit:

```bash
git add .
git commit -m "Your commit message"
git push
```

---

## Environment & Secrets

Never commit sensitive information such as:

* API keys
* Passwords
* Access tokens
* Private certificates
* Production credentials
* Secret environment variables

Use environment-specific configuration for values that should not be stored directly in source code.

Example:

```text
.env.example
```

can document required variables without containing real secrets.

---

## Supported Platforms

The Flutter project currently contains platform configurations for:

* Android
* iOS
* Web
* macOS
* Windows
* Linux

Platform-specific code should remain inside the appropriate platform directory unless it is required by the shared Flutter application.

---

## Testing

Tests are maintained inside:

```text
test/
```

Integration tests can be added later under:

```text
integration_test/
```

Testing should be introduced alongside important business functionality rather than creating unnecessary tests for simple UI boilerplate.

---

## Project Philosophy

The project follows a **simple, reliable, maintainable engineering approach**.

The goal is not to create the most complicated architecture.

The goal is to create an architecture that:

```text
Easy to understand
        +
Easy to modify
        +
Easy to test
        +
Easy to scale
        =
Maintainable application
```

Architecture should evolve based on actual application requirements rather than anticipated complexity.
