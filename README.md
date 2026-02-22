# CoBuild Manager (Mobile)

Mobile client for **CoBuild Manager** — a Flutter app for managing deposits, expenses, and members. Built with BLoC for state management and supports Android, iOS, web, macOS, Linux, and Windows.

## Features

- **Authentication** — JWT-based login with project selection
- **Project Gating** — Strict project selection required for all features
- **Project Switching** — Easy switching between projects via drawer or home screen
- **Home Dashboard** — Quick navigation cards and management shortcuts
- **Messaging** — Real-time messaging with WebSocket support for channels and direct conversations
- **Decisions** — View and track project decisions (MVP)
- **Notice Board** — Pinned and regular notices
- **Files** — Browse project files (MVP)
- **Members** — View and manage project members
- **Deposits** — Track and add deposits with type categorization
- **Expenses** — Manage and record expenses with detailed tracking
- **Drawer Navigation** — Easy access to all features via side drawer

## Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) ^3.5.3 or higher
- Dart SDK ^3.5.3
- For iOS: Xcode and CocoaPods
- For Android: Android Studio and Android SDK

## Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd cbm-mobile
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure the API**
   
   Create a `.env` file in the project root (copy from `.env.example`):
   ```bash
   cp .env.example .env
   ```
   
   Edit `.env` and set your API URL and WebSocket URL:
   ```
   API_URL=http://127.0.0.1:8181/api
   WEBSOCKET_URL=ws://127.0.0.1:8080
   ```
   
   **For physical devices**: Replace `127.0.0.1` with your computer's local IP address
   
   **For production**: Use your deployed backend URLs (use `wss://` for secure WebSocket)

## Running the App

**Prerequisites:**
- Ensure the backend API is running at the URL specified in `.env`
- For local development, start the Laravel backend first

**Quick Start:**
```bash
# Start the app in Chrome
flutter run -d chrome
```

**Development Workflow:**
After making code changes, you DON'T need to stop and restart:
- Press `r` for **hot reload** (fast, preserves state) - use for UI changes
- Press `R` for **hot restart** (full restart) - use for theme/router/BLoC changes
- Press `h` to see all available commands

**Run on a specific platform:**
```bash
# Android
flutter run -d android

# iOS
flutter run -d ios

# Web
flutter run -d chrome

# macOS
flutter run -d macos
```

**List available devices:**
```bash
flutter devices
```

**Note:** If you close Chrome manually, the Flutter terminal will show "Application finished". This is normal - just run `flutter run -d chrome` again to restart. See [DEVELOPMENT.md](DEVELOPMENT.md) for detailed hot reload guidance.

## First Time Setup

1. **Start the backend API** (from the `co_build_manager` project):
   ```bash
   cd /Users/jobaerahmed/Sites/co_build_manager
   docker-compose up -d
   ```

2. **Run the mobile app**:
   ```bash
   cd /Users/jobaerahmed/Sites/cbm-mobile
   flutter run -d chrome
   ```

3. **Login** with your backend credentials

4. **Select a project** from the list (required for multi-tenant backend)

5. Navigate through the app using the drawer menu (☰ icon)

## Switching Projects

You can switch between projects at any time without logging out:

**Method 1 - From Drawer:**
1. Open drawer (☰ icon)
2. Tap "Switch Project"
3. Select a different project

**Method 2 - From Home Screen:**
1. Tap the swap icon (⇄) in the AppBar
2. Select a different project

Your authentication session is preserved when switching projects.

## Real-Time Messaging

The app includes a production-ready messaging system with WebSocket support:

### Features
- **Real-time updates** — Messages appear instantly via WebSocket
- **Channel messaging** — Team-wide discussions in project channels
- **Direct messaging** — Private 1-on-1 conversations
- **Read receipts** — Track message read status in direct messages
- **Auto-reconnection** — Robust connection management with exponential backoff
- **Smooth UI** — Animated message bubbles, typing indicators, date separators
- **Message history** — Load older messages with infinite scroll pagination

### Configuration

Ensure your `.env` file includes:
```
API_URL=http://127.0.0.1:8181/api
WEBSOCKET_URL=ws://127.0.0.1:8080
```

The backend uses **Laravel Reverb** for WebSocket connections. Make sure:
1. Reverb server is running (typically on port 8080)
2. Backend `.env` has proper Reverb configuration:
   ```
   BROADCAST_CONNECTION=reverb
   REVERB_APP_ID=cobuild-key
   REVERB_SERVER_HOST=0.0.0.0
   REVERB_SERVER_PORT=8080
   ```
3. Docker Compose exposes port 8080 for WebSocket connections

### Usage
1. Navigate to **Messaging** from the drawer
2. Tap a channel or conversation to open
3. Type and send messages
4. Messages update in real-time for all participants
5. Connection status shown in AppBar (Connected/Connecting...)

### Architecture
- **WebSocketService** — Manages connection, subscriptions, reconnection
- **MessageBloc** — Handles message state, sending, receiving via BLoC pattern
- **Message Model** — Type-safe message data with sender info
- **Channel Auth** — JWT-based authentication for private channel subscriptions

## Building for Release

**Android (APK):**
```bash
flutter build apk --release
```

**Android (App Bundle for Play Store):**
```bash
flutter build appbundle --release
```

**iOS:**
```bash
flutter build ios --release
```

**Web:**
```bash
flutter build web --release
```

After building web, serve from `build/web`:
```bash
python3 -m http.server 8080 --directory build/web
```

## Project Structure

```
lib/
├── main.dart                       # App entry with router
├── theme/
│   └── app_theme.dart              # Design system (colors, typography)
├── router/
│   ├── app_router.dart             # go_router configuration
│   └── router_notifier.dart        # Auth state change listener
├── auth/
│   └── auth_bloc.dart              # Authentication BLoC
├── messaging/
│   ├── message_bloc.dart           # Messaging BLoC for real-time updates
│   ├── message_event.dart          # Message events
│   └── message_state.dart          # Message states
├── models/
│   └── message.dart                # Message data model
├── services/
│   ├── api_service.dart            # HTTP client with headers
│   ├── auth_service.dart           # Login/logout logic
│   └── websocket_service.dart      # WebSocket client for real-time messaging
├── utils/
│   ├── constants.dart              # API URL from .env
│   └── storage_util.dart           # Token/project persistence
├── screens/
│   ├── login_screen.dart           # Login with validation
│   ├── project_selection_screen.dart   # Project picker
│   ├── channel_detail_screen.dart  # Channel messaging with real-time updates
│   ├── direct_conversation_screen.dart  # Direct messaging with read receipts
│   ├── home_screen.dart            # Dashboard with quick nav
│   ├── messaging_screen.dart       # Channels & DMs (MVP)
│   ├── decisions_screen.dart       # Decision list (MVP)
│   ├── notices_screen.dart         # Notice board
│   ├── files_screen.dart           # File browser (MVP)
│   ├── members_screen.dart         # Member list
│   ├── deposit_screen.dart         # Deposit list
│   ├── deposit_add_screen.dart     # Add deposit form
│   ├── expense_screen.dart         # Expense list
│   ├── expense_add_screen.dart     # Add expense form
│   └── widgets/
│       ├── app_drawer.dart         # Navigation drawer
│       └── empty_state.dart        # Empty state component
```

## Tech Stack

- **Flutter** — Cross-platform UI framework (^3.5.3)
- **BLoC** — State management for authentication
- **go_router** — Declarative routing with guards
- **http** — RESTful API communication
- **SharedPreferences** — Local storage for token and project context
- **flutter_dotenv** — Environment variable configuration
- **flutter_svg** — SVG asset rendering
- **intl** — Date formatting

## Backend Integration

This mobile app connects to the [CoBuild Manager Laravel backend](/Users/jobaerahmed/Sites/co_build_manager/). Key integration points:

- **Authentication**: JWT token-based auth via `POST /api/login`
  - Request: `{ "login": "email@example.com", "password": "..." }`
  - Response: `{ "items": { "token": "...", "user": {...} } }`
- **Multi-tenant**: Requires `X-Project-ID` header for all project-scoped endpoints
- **Project Selection**: Users must select a project after login (fetched via `GET /api/projects`)
- **API Endpoints**:
  - `GET /api/projects` - List user's projects (no X-Project-ID required)
  - `GET /api/members` - List members
  - `GET /api/channels` - List messaging channels
  - `GET /api/direct-conversations` - List direct messages
  - `GET /api/decisions` - List decisions
  - `GET /api/notices` - List notices
  - `GET /api/files` - List files
  - `GET /api/deposits` - List deposits
  - `POST /api/deposit` - Add deposit
  - `GET /api/expenses` - List expenses
  - `POST /api/expense` - Add expense

## Troubleshooting

### Login Issues

**"Login succeeded but still showing login page"**
- This is fixed in the latest version with `RouterNotifier`
- The router now listens to auth state changes and automatically redirects
- Check console logs for `[Router] Redirect check` messages
- If issue persists, try hot restart (not just hot reload): press `R` in terminal

**"XMLHttpRequest error" or "Login failed"**
- **For Flutter Web**: CORS issue. Update backend `config/cors.php`:
  ```php
  'allowed_origins_patterns' => [
      '#^http://localhost:\\d+$#',
      '#^http://127\\.0\\.0\\.1:\\d+$#',
  ],
  ```
- Verify backend is running: `curl http://127.0.0.1:8181/api`
- Check `.env` has correct `API_URL`

**"WebSocket not connecting" or "Messages not real-time"**
- Ensure Laravel Reverb is running: `docker ps | grep reverb`
- Verify `WEBSOCKET_URL` in `.env` matches Reverb host and port
- Check browser console for `[WebSocket]` debug logs
- For Flutter Web, ensure CORS allows WebSocket connections
- See [MESSAGING.md](MESSAGING.md) for detailed troubleshooting

**"Keeps loading after login"**
- Open browser DevTools (F12) → Console tab
- Look for network errors or timeout messages
- Check backend logs for authentication errors
- Verify database connection in backend

### API Connection Issues

**Connection fails on physical device:**
- Update `.env` with your computer's local IP instead of `127.0.0.1`
  ```
  API_URL=http://192.168.1.100:8181/api
  ```
- Ensure both devices are on the same network
- Check backend CORS settings allow your device's IP
- For Android emulator: `10.0.2.2:8181` maps to host `127.0.0.1:8181`

**"ProjectID Not Found" error:**
- Make sure you selected a project after login
- Verify the user has access to at least one project in the backend
- Check backend logs: `docker logs <container-name>`

### Development Issues

**"Hot reload not working":**
- Press `R` (capital R) for **hot restart** instead of `r`
- Hot reload (`r`) doesn't work for: theme changes, router changes, BLoC initialization, .env changes
- Hot restart (`R`) reloads everything but loses app state (logs you out)
- See [DEVELOPMENT.md](DEVELOPMENT.md) for detailed guide

**"Terminal not working after closing Chrome":**
- **This is normal** - the Flutter process stops when you close the browser
- Solution: Just run `flutter run -d chrome` again
- The app doesn't automatically reopen Chrome when closed manually

**Hot reload causes errors or strange behavior:**
- State corruption from hot reload
- Solution: Press `R` for hot restart, or stop and restart fully

**Build errors after pulling changes:**
```bash
flutter clean
flutter pub get
flutter run -d chrome
```

**"Waiting for another flutter command...":**
- Another Flutter process is locking the project
- Wait 10-30 seconds for it to release
- Or find and kill: `ps aux | grep flutter` then `kill <pid>`

## Documentation

- [MESSAGING.md](MESSAGING.md) - Complete guide to real-time messaging system
- [MESSAGING_QUICKSTART.md](MESSAGING_QUICKSTART.md) - Quick start guide for messaging
- [MESSAGING_BUGFIX.md](MESSAGING_BUGFIX.md) - Bug fixes for message display and counters
- [TESTING_GUIDE.md](TESTING_GUIDE.md) - Testing checklist for messaging features
- [DEVELOPMENT.md](DEVELOPMENT.md) - Development workflow and hot reload guide
- [REFACTOR_2026.md](REFACTOR_2026.md) - Full refactor plan and architecture
- [MIGRATION_NOTES.md](MIGRATION_NOTES.md) - Changes from original codebase
- [QUICKSTART.md](QUICKSTART.md) - Quick setup and troubleshooting
- [DEBUG.md](DEBUG.md) - Debugging tips for common issues

## License

Private project. See repository for details.
