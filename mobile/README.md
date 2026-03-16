# migajas – Android Flutter Client

A full-featured Android app for the **migajas** notes backend, built with Flutter.

## Features

- Notes grid with color coding, tags, pinning, search & per-tag filtering
- Rich text editing (flutter_quill — bold, italic, lists, code, links)
- Secret vault notes (unlock with PIN or password)
- Attachment support (images, audio, PDFs, any file)
- Audio playback for recorded attachments
- Tag CRUD with emoji picker
- Admin panel (users, self-registration toggle)
- Dark / Light / System theme
- Persistent sessions via flutter_secure_storage + refresh token

## Project setup

### 1. Bootstrap the Flutter project (already done if you see this file)

The Flutter project lives in this `mobile/` folder. If you haven't run `flutter create` yet:

```bash
cd mobile
flutter create . --project-name migajas --org com.example --android-language kotlin
```

> Your existing `lib/`, `pubspec.yaml`, and `README.md` will **not** be overwritten.

### 2. Install dependencies

```bash
cd mobile
flutter pub get
```

### 3. Configure the backend URL

| Scenario | Command |
|---|---|
| Emulator → localhost | *(default: `http://10.0.2.2/api`)* |
| Physical device on LAN | `--dart-define=API_BASE_URL=http://192.168.x.x/api` |
| Production | `--dart-define=API_BASE_URL=https://your-domain.com/api` |

### 4. Run

```bash
# Debug on connected device / emulator
cd mobile
flutter run --dart-define=API_BASE_URL=http://10.0.2.2/api

# Release APK
flutter build apk --dart-define=API_BASE_URL=https://your-domain.com/api
```

## Architecture

```
lib/
├── config.dart               # API base URL constant
├── main.dart                 # App entry point, ProviderScope, MaterialApp.router
├── router.dart               # go_router + redirect guards
├── api/
│   ├── api_client.dart       # Dio singleton + QueuedInterceptor (401 → refresh)
│   ├── auth_repository.dart
│   ├── notes_repository.dart
│   ├── tags_repository.dart
│   ├── attachments_repository.dart
│   └── admin_repository.dart
├── models/
│   ├── note.dart
│   ├── tag.dart
│   ├── attachment.dart
│   ├── user.dart
│   └── setup_status.dart
├── providers/
│   ├── auth_provider.dart    # AuthNotifier (Notifier API, no codegen)
│   ├── notes_provider.dart   # NotesNotifier
│   ├── tags_provider.dart    # TagsNotifier + selectedTagIdProvider
│   ├── filters_provider.dart # filteredNotesProvider (search + tag filter)
│   ├── setup_provider.dart   # SetupStatus + SetupPhase
│   └── theme_provider.dart   # ThemeMode persisted in SharedPreferences
├── screens/
│   ├── setup_screen.dart     # First-run admin account creation
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── main_screen.dart      # Notes grid + sidebar (responsive drawer/rail)
│   ├── settings_screen.dart  # Theme + vault credential
│   └── admin_screen.dart     # User management
└── widgets/
    ├── note_card.dart         # Card in the grid
    ├── note_sheet.dart        # Full-screen create/edit sheet
    ├── unlock_dialog.dart
    ├── delete_note_dialog.dart
    ├── attachment_panel.dart  # Upload, list, open, play, delete
    ├── tag_editor.dart        # Inline rename + delete row
    ├── rich_editor.dart       # flutter_quill wrapper (HTML ↔ Delta)
    ├── color_picker_row.dart
    └── emoji_data.dart        # 96-emoji constant list
```

## Key technical decisions

- **Riverpod Notifier API** — no code generation, all providers hand-written.
- **QueuedInterceptor** on Dio — prevents duplicate refresh calls when multiple
  concurrent requests hit a 401.
- **Refresh cookie** stored in `flutter_secure_storage`, sent manually as
  `Cookie: refresh_token=<value>` (no cookie jar needed).
- **flutter_quill** + **quill_html_converter** for bidirectional HTML ↔ Delta.
- Responsive layout: `Drawer` on phones (`<600 dp`), permanent side panel on
  tablets.
