# IRAMS (Intelligent Roadside Assistance Management System)

IRAMS is a multi-platform roadside assistance system built with Flutter mobile apps
(a driver app and a contractor app) and an ASP.NET C# web admin portal, using Firebase
as the backend and the OpenStreetMap API for mapping. It supports automated GPS detection,
real-time tracking, transparent upfront pricing, and digital payments via FPX and e-wallets.

This repository currently contains the **IRAMS User App**, the customer-facing Flutter
application that drivers use to request assistance, track contractors in real time, and pay
for completed jobs. The contractor app and the ASP.NET C# admin portal are separate
components of the wider IRAMS system and are not included in this repository.

## Features

- **Automated GPS detection** that captures the driver's location when a request is created.
- **Real-time tracking** of the assigned contractor on a live map with route guidance.
- **Transparent upfront pricing** so users see the cost of a service before confirming.
- **FPX and e-wallet payments** through a secured ToyyibPay bill flow.
- **Contractor job management** support, with jobs flowing through clear status transitions
  (Pending, Accepted, OnTheWay, Arrived, InProgress, Completed).
- **Admin oversight** through a shared Firestore data model and support messaging that the
  admin portal can read and respond to.

## Tech Stack

- **Flutter / Dart** for the cross-platform mobile client.
- **ASP.NET C#** for the web admin portal (separate component of the IRAMS system).
- **Firebase** for authentication, Cloud Firestore, Cloud Storage, Cloud Messaging, and
  Cloud Functions (the ToyyibPay payment integration runs in `asia-southeast1`).
- **OpenStreetMap API** for mapping and routing (flutter_map with OSRM routing).

## Project Structure

```
UserApp/
├── user_app/                 # Flutter User App (driver/customer client)
│   ├── lib/
│   │   ├── constants/        # Shared constants
│   │   ├── models/           # Data models and chat detail view
│   │   ├── services/         # Firestore, Auth, Invoice, ToyyibPay, Location, Routing
│   │   ├── ui/               # Pages and widgets (home, auth, payment, map, messages)
│   │   ├── images/           # Bundled image assets
│   │   ├── firebase_options.dart   # Firebase config (gitignored, add locally)
│   │   └── main.dart
│   ├── functions/            # Firebase Cloud Functions (Node.js, ToyyibPay bill flow)
│   ├── android/ ios/ web/ windows/ linux/ macos/   # Platform projects
│   ├── assets/               # Map style and other assets
│   ├── firestore.rules       # Firestore security rules
│   ├── storage.rules         # Cloud Storage security rules
│   ├── firebase.json         # Firebase project configuration
│   └── pubspec.yaml          # Flutter dependencies
├── USER_APP_OVERVIEW.md      # Integration reference for the admin portal team
├── PROJECT_STATUS.md         # Project status notes
└── FYP2_Extraction.md        # Project documentation
```

## Getting Started

### Prerequisites

- Flutter SDK 3.9.2 or newer (Dart SDK is bundled with Flutter).
- A configured Android or iOS toolchain, or a desktop/web target.
- Node.js (for the Firebase Cloud Functions) and the Firebase CLI.
- A Firebase project with Authentication, Cloud Firestore, Cloud Storage, Cloud Messaging,
  and Cloud Functions enabled.
- For the admin portal: the .NET SDK (run `dotnet --version` to confirm it is installed).

### Firebase configuration (required, kept out of version control)

Firebase config files contain project-specific values and are gitignored, so they are not
present in this repository. Add them locally before running the app:

1. Run `flutterfire configure` from the `user_app/` directory, or generate the files manually
   from the Firebase console.
2. Confirm the following files exist locally after configuration:
   - `user_app/lib/firebase_options.dart`
   - `user_app/android/app/google-services.json`
   - `user_app/ios/Runner/GoogleService-Info.plist` (for iOS builds)

### Run the Flutter User App

```bash
cd user_app
flutter pub get
flutter run
```

### Deploy the Cloud Functions (optional)

The ToyyibPay integration uses Firebase secrets rather than hardcoded keys. Set them before
deploying:

```bash
cd user_app/functions
npm install
firebase functions:secrets:set TOYYIBPAY_SECRET
firebase functions:secrets:set TOYYIBPAY_CATEGORY
firebase deploy --only functions
```

### Run the admin portal (ASP.NET C#)

The admin portal lives in a separate component of the IRAMS system. When working with it,
restore and run it with the standard .NET workflow:

```bash
dotnet restore
dotnet run
```

Provide local secrets through `appsettings.Development.json` or user secrets. These files are
gitignored and must not be committed.

## Security Notes

Do not commit Firebase config files, service account keys, environment files, or signing
keystores. These are excluded by the project `.gitignore`. The repository is public, so keep
all credentials and project secrets out of version control.
