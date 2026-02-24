import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_dotenv/flutter_dotenv.dart';

String get apiUrl {
  // Check if API_URL is explicitly set in .env
  final envUrl = dotenv.env['API_URL'];
  if (envUrl != null && envUrl.isNotEmpty) {
    // Only use .env value if not the Android emulator default
    // This allows override for production/staging environments
    if (envUrl != 'http://10.0.2.2:8181/api') {
      return envUrl;
    }
  }

  // Platform-specific defaults for local development
  if (kIsWeb) {
    // Web (Chrome, Firefox, etc.) - use localhost
    return 'http://127.0.0.1:8181/api';
  }

  // For mobile platforms, use _getPlatformApiUrl
  return _getPlatformApiUrl();
}

String get websocketUrl {
  final envUrl = dotenv.env['WEBSOCKET_URL'];
  if (envUrl != null && envUrl.isNotEmpty) {
    if (envUrl != 'ws://10.0.2.2:8080') {
      return envUrl;
    }
  }

  if (kIsWeb) {
    return 'ws://127.0.0.1:8080';
  }

  return _getPlatformWebSocketUrl();
}

String get reverbAppKey => dotenv.env['REVERB_APP_KEY'] ?? '';

// Platform-specific helpers (only called on non-web platforms)
String _getPlatformApiUrl() {
  try {
    // Using defaultTargetPlatform for safe platform detection
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8181/api';
    }
    // iOS, macOS, Linux, Windows, Fuchsia - use localhost
    return 'http://127.0.0.1:8181/api';
  } catch (e) {
    return 'http://127.0.0.1:8181/api';
  }
}

String _getPlatformWebSocketUrl() {
  try {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'ws://10.0.2.2:8080';
    }
    return 'ws://127.0.0.1:8080';
  } catch (e) {
    return 'ws://127.0.0.1:8080';
  }
}
