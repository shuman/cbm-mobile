import 'dart:async';

class SessionService {
  SessionService._();
  static final SessionService instance = SessionService._();

  bool _hasPendingSessionExpiredNotice = false;

  final StreamController<void> _sessionExpiredController =
      StreamController<void>.broadcast();

  Stream<void> get onSessionExpired => _sessionExpiredController.stream;

  void notifySessionExpired() {
    _hasPendingSessionExpiredNotice = true;
    if (!_sessionExpiredController.isClosed) {
      _sessionExpiredController.add(null);
    }
  }

  bool consumeSessionExpiredNotice() {
    final hasNotice = _hasPendingSessionExpiredNotice;
    _hasPendingSessionExpiredNotice = false;
    return hasNotice;
  }

  void dispose() {
    _sessionExpiredController.close();
  }
}