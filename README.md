<!-- This file uses generated code. Visit https://pub.dev/packages/readme_helper for usage information. -->
# HKMU 3D Model Hub

A community platform for HKMU students and staff to upload, browse, and share high-quality 3D models.


## Features

- Public gallery with responsive grid and pagination
- Admin-only upload with thumbnail and metadata
- Full admin panel: manage users and models (edit/delete)
- Supabase backend with secure RLS policies
- Web-optimized (public bucket for fast loading)
- Beautiful UI with custom HKMU green theme

## Live Demo

[https://hkmu-3dmodel-hub.web.app/](https://hkmu-3dmodel-hub.web.app/) <!-- Update with your Firebase/Supabase URL -->

## Tech Stack

- Flutter (Web primary target)
- Supabase (Auth + Database + Storage)
- GoRouter for navigation
- File Picker for uploads

## Setup & Deployment

1. Clone the repo
2. Run `flutter pub get`
3. Configure Supabase keys in `lib/core/constants/supabase_config.dart`
4. Deploy to web:
   ```bash
   flutter build web
   firebase deploy --only hosting# hkmu_3dmodel_hub

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

```
HKMU-3DModel-HUB
lib
 ┣ core
 ┃ ┣ constants
 ┃ ┃ ┗ supabase_config.dart
 ┃ ┗ widgets
 ┃ ┃ ┗ header.dart
 ┣ providers
 ┃ ┗ cart_provider.dart
 ┣ screens
 ┃ ┣ admin_panel_screen.dart
 ┃ ┣ cart_screen.dart
 ┃ ┣ home_screen.dart
 ┃ ┣ login_screen.dart
 ┃ ┣ model_detail_screen.dart
 ┃ ┣ request_success_screen.dart
 ┃ ┗ upload_screen.dart
 ┣ styles
 ┃ ┗ styles.dart
 ┣ app.dart
 ┗ main.dart

```