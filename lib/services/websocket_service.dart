import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import '../utils/storage_util.dart';
import '../utils/constants.dart';

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

class WebSocketService {
  WebSocketChannel? _channel;
  final Map<String, StreamController<Map<String, dynamic>>> _channelControllers = {};
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  bool _isConnecting = false;
  bool _shouldReconnect = true;
  String? _token;
  String? _projectId;
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 10;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  final Set<String> _pendingSubscriptions = {};
  String? _socketId;
  
  final StreamController<ConnectionStatus> _statusController = StreamController<ConnectionStatus>.broadcast();
  // Global stream for message.sent and other app events
  final StreamController<Map<String, dynamic>> _globalMessageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get globalMessageStream => _globalMessageController.stream;

  // Pending personal channel suffixes (e.g. "App.Models.User.{id}")
  final Set<String> _pendingPersonalChannels = {};

  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  Stream<ConnectionStatus> get statusStream => _statusController.stream;
  ConnectionStatus get status => _status;

  void _updateStatus(ConnectionStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _statusController.add(newStatus);
      if (kDebugMode) debugPrint('[WebSocket] Status: $newStatus');
    }
  }

  String get _wsUrl {
    final wsBase = dotenv.env['WEBSOCKET_URL'] ?? 'ws://localhost:8080';
    final appKey = dotenv.env['REVERB_APP_KEY'] ?? 'cobuild-key';
    return '$wsBase/app/$appKey?protocol=7&client=js&version=8.4.0&flash=false';
  }

  Future<void> connect() async {
    if (_isConnecting || _channel != null) return;
    
    _isConnecting = true;
    _updateStatus(_reconnectAttempts > 0 ? ConnectionStatus.reconnecting : ConnectionStatus.connecting);
    
    _token = await StorageUtil.getToken();
    _projectId = await StorageUtil.getProjectId();

    if (_token == null) {
      if (kDebugMode) debugPrint('[WebSocket] No token, skipping connection');
      _isConnecting = false;
      _updateStatus(ConnectionStatus.disconnected);
      return;
    }

    try {
      final wsUrl = _wsUrl;
      if (kDebugMode) debugPrint('[WebSocket] Connecting to $wsUrl (attempt ${_reconnectAttempts + 1})');
      
      // No subprotocol — matches how pusher-js connects (plain WebSocket, no Sec-WebSocket-Protocol header)
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      await _channel!.ready.timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Connection timeout after 10s'),
      );
      
      if (kDebugMode) debugPrint('[WebSocket] ✓ Connected successfully');
      
      _isConnecting = false;
      _reconnectAttempts = 0;
      _updateStatus(ConnectionStatus.connected);
      _startPingTimer();
      _listenToMessages();
      _resubscribePendingChannels();
      
    } catch (e) {
      if (kDebugMode) debugPrint('[WebSocket] ✗ Connection error: $e');
      _channel = null;
      _isConnecting = false;
      _updateStatus(ConnectionStatus.error);
      _scheduleReconnect();
    }
  }

  void _resubscribePendingChannels() {
    if (_pendingSubscriptions.isNotEmpty) {
      if (kDebugMode) debugPrint('[WebSocket] Resubscribing to ${_pendingSubscriptions.length} messaging channels');
      final channels = List<String>.from(_pendingSubscriptions);
      for (var channelKey in channels) {
        final parts = channelKey.split('.');
        if (parts.length == 2) {
          subscribeToChannel(parts[0], parts[1]);
        }
      }
    }
    if (_pendingPersonalChannels.isNotEmpty) {
      if (kDebugMode) debugPrint('[WebSocket] Resubscribing to ${_pendingPersonalChannels.length} personal channels');
      final personal = List<String>.from(_pendingPersonalChannels);
      for (final suffix in personal) {
        subscribeToPersonalChannel(suffix);
      }
    }
  }

  void _listenToMessages() {
    _channel?.stream.listen(
      (message) {
        try {
          final data = jsonDecode(message as String);
          _handleMessage(data);
        } catch (e) {
          if (kDebugMode) debugPrint('[WebSocket] [DEBUG] Message parse error: $e');
        }
      },
      onError: (error, stackTrace) {
        if (kDebugMode) {
          debugPrint('[WebSocket] [DEBUG] Stream onError: $error');
          debugPrint('[WebSocket] [DEBUG] Stream onError stack: $stackTrace');
        }
        _handleDisconnect();
      },
      onDone: () {
        if (kDebugMode) debugPrint('[WebSocket] [DEBUG] Stream onDone - connection closed');
        _handleDisconnect();
      },
      cancelOnError: false,
    );
  }

  void _handleMessage(Map<String, dynamic> data) {
    if (kDebugMode) debugPrint('[WebSocket] Received: ${data['event']} on ${data['channel']}');
    
    final event = data['event'];
    final channel = data['channel'];
    
    if (event == 'pusher:connection_established') {
      try {
        final dataStr = data['data'];
        final socketData = dataStr is String ? jsonDecode(dataStr) : dataStr;
        _socketId = socketData['socket_id'];
        if (kDebugMode) debugPrint('[WebSocket] Socket ID: $_socketId');
      } catch (e) {
        if (kDebugMode) debugPrint('[WebSocket] Error parsing socket ID: $e');
      }
    } else if (event == 'pusher_internal:subscription_succeeded') {
      if (kDebugMode) debugPrint('[WebSocket] Subscribed to $channel');
    } else if (event == 'pusher:pong') {
      // Heartbeat response — intentionally ignored
    } else if (event == 'message.sent') {
      try {
        final dataStr = data['data'];
        final messageData = dataStr is String ? jsonDecode(dataStr) : dataStr as Map<String, dynamic>;
        
        if (kDebugMode) debugPrint('[WebSocket] ✓ message.sent on $channel');
        
        // Broadcast to global stream (for messaging list + notification manager)
        _globalMessageController.add({
          'event_type': 'message.sent',
          'channel': channel,
          'data': messageData,
        });
        
        // Deliver to specific channel controller (for chat detail screen)
        if (channel != null && _channelControllers.containsKey(channel)) {
          _channelControllers[channel]!.add(messageData);
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[WebSocket] Error parsing message.sent: $e');
      }
    } else if (event == 'channel.member.added') {
      try {
        final dataStr = data['data'];
        final eventData = dataStr is String
            ? jsonDecode(dataStr) as Map<String, dynamic>
            : (dataStr as Map<String, dynamic>? ?? {});
        if (kDebugMode) debugPrint('[WebSocket] ✓ channel.member.added: $eventData');
        _globalMessageController.add({
          'event_type': 'channel.member.added',
          'channel': channel,
          'data': eventData,
        });
      } catch (e) {
        if (kDebugMode) debugPrint('[WebSocket] Error parsing channel.member.added: $e');
      }
    } else {
      if (kDebugMode) debugPrint('[WebSocket] Unhandled event: $event on channel: $channel');
    }
  }

  void _handleDisconnect() {
    _channel = null;
    _pingTimer?.cancel();
    _updateStatus(ConnectionStatus.disconnected);
    
    if (_shouldReconnect && _reconnectAttempts < _maxReconnectAttempts) {
      _scheduleReconnect();
    } else if (_reconnectAttempts >= _maxReconnectAttempts) {
      if (kDebugMode) debugPrint('[WebSocket] Max reconnect attempts reached');
      _updateStatus(ConnectionStatus.error);
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    
    final delay = _calculateBackoffDelay(_reconnectAttempts);
    
    if (kDebugMode) debugPrint('[WebSocket] Scheduling reconnect in ${delay.inSeconds}s (attempt $_reconnectAttempts)');
    
    _reconnectTimer = Timer(delay, () {
      if (_shouldReconnect) {
        if (kDebugMode) debugPrint('[WebSocket] Reconnecting...');
        connect();
      }
    });
  }

  Duration _calculateBackoffDelay(int attempt) {
    final baseDelay = 2;
    final maxDelay = 30;
    final delay = (baseDelay * (1 << (attempt - 1))).clamp(baseDelay, maxDelay);
    return Duration(seconds: delay);
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_channel != null) {
        _sendRaw({
          'event': 'pusher:ping',
          'data': {},
        });
      }
    });
  }

  void _sendRaw(Map<String, dynamic> data) {
    try {
      _channel?.sink.add(jsonEncode(data));
    } catch (e) {
      if (kDebugMode) debugPrint('[WebSocket] Send error: $e');
    }
  }

  Future<void> subscribeToChannel(String channelType, String channelId) async {
    final channelName = 'private-messaging.$channelType.$channelId';
    final key = '$channelType.$channelId';
    
    _pendingSubscriptions.add(key);
    
    if (_channelControllers.containsKey(channelName)) {
      if (kDebugMode) debugPrint('[WebSocket] Already subscribed to $channelName');
      return;
    }

    if (_channel == null || _status != ConnectionStatus.connected) {
      if (kDebugMode) debugPrint('[WebSocket] [DEBUG] Not connected (_channel=${_channel != null}, status=$_status), subscription queued: $channelName');
      return;
    }

    try {
      final authData = await _getChannelAuth(channelName);
      if (authData == null) {
        if (kDebugMode) debugPrint('[WebSocket] Auth failed for $channelName');
        _pendingSubscriptions.remove(key);
        return;
      }

      _channelControllers[channelName] = StreamController<Map<String, dynamic>>.broadcast();
      if (kDebugMode) debugPrint('[WebSocket] ✓ Created stream controller for $channelName');

      _sendRaw({
        'event': 'pusher:subscribe',
        'data': {
          'channel': channelName,
          'auth': authData,
        },
      });

      if (kDebugMode) debugPrint('[WebSocket] ✓ Sent subscribe request for $channelName');
    } catch (e) {
      if (kDebugMode) debugPrint('[WebSocket] Subscribe error: $e');
      _pendingSubscriptions.remove(key);
    }
  }

  Future<String?> _getChannelAuth(String channelName) async {
    if (_socketId == null) {
      if (kDebugMode) debugPrint('[WebSocket] No socket ID yet, waiting...');
      await Future.delayed(const Duration(milliseconds: 500));
      if (_socketId == null) {
        if (kDebugMode) debugPrint('[WebSocket] Still no socket ID, using fallback');
        _socketId = 'socket-${DateTime.now().millisecondsSinceEpoch}';
      }
    }

    try {
      // Must match pusher-js: POST to /api/broadcasting/auth with form-urlencoded body
      final headers = {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'application/json',
      };
      
      if (_projectId != null && _projectId!.isNotEmpty) {
        headers['X-Project-ID'] = _projectId!;
      }

      final authUrl = '$apiUrl/broadcasting/auth';

      if (kDebugMode) debugPrint('[WebSocket] Auth POST to $authUrl (socket=$_socketId, channel=$channelName)');

      final response = await http.post(
        Uri.parse(authUrl),
        headers: headers,
        body: 'socket_id=$_socketId&channel_name=$channelName',
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (kDebugMode) debugPrint('[WebSocket] Auth successful for $channelName');
        return data['auth'];
      }
      
      if (kDebugMode) debugPrint('[WebSocket] Auth failed: ${response.statusCode} ${response.body}');
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('[WebSocket] Auth error: $e');
      return null;
    }
  }

  /// Subscribe to a personal/user private channel like "App.Models.User.{userId}".
  /// The [channelSuffix] is the part after "private-", e.g. "App.Models.User.abc123".
  Future<void> subscribeToPersonalChannel(String channelSuffix) async {
    final channelName = 'private-$channelSuffix';
    _pendingPersonalChannels.add(channelSuffix);

    if (_channelControllers.containsKey(channelName)) {
      if (kDebugMode) debugPrint('[WebSocket] Already subscribed to $channelName');
      return;
    }

    if (_channel == null || _status != ConnectionStatus.connected) {
      if (kDebugMode) debugPrint('[WebSocket] Not connected, personal channel queued: $channelName');
      return;
    }

    try {
      final authData = await _getChannelAuth(channelName);
      if (authData == null) {
        if (kDebugMode) debugPrint('[WebSocket] Auth failed for personal channel $channelName');
        _pendingPersonalChannels.remove(channelSuffix);
        return;
      }

      _channelControllers[channelName] = StreamController<Map<String, dynamic>>.broadcast();
      _sendRaw({
        'event': 'pusher:subscribe',
        'data': {'channel': channelName, 'auth': authData},
      });
      if (kDebugMode) debugPrint('[WebSocket] ✓ Subscribed to personal channel: $channelName');
    } catch (e) {
      if (kDebugMode) debugPrint('[WebSocket] Personal channel subscribe error: $e');
      _pendingPersonalChannels.remove(channelSuffix);
    }
  }

  Future<void> subscribeToMultipleChannels(List<Map<String, String>> channels) async {
    for (final ch in channels) {
      final type = ch['type'];
      final id = ch['id'];
      if (type != null && id != null) {
        await subscribeToChannel(type, id);
      }
    }
  }

  void unsubscribeFromChannel(String channelType, String channelId) {
    final channelName = 'private-messaging.$channelType.$channelId';
    final key = '$channelType.$channelId';
    
    _pendingSubscriptions.remove(key);
    
    if (_channel != null) {
      _sendRaw({
        'event': 'pusher:unsubscribe',
        'data': {
          'channel': channelName,
        },
      });
    }

    _channelControllers[channelName]?.close();
    _channelControllers.remove(channelName);
    
    if (kDebugMode) debugPrint('[WebSocket] Unsubscribed from $channelName');
  }

  Stream<Map<String, dynamic>>? getChannelStream(String channelType, String channelId) {
    final channelName = 'private-messaging.$channelType.$channelId';
    final hasController = _channelControllers.containsKey(channelName);
    
    if (kDebugMode) debugPrint('[WebSocket] getChannelStream for $channelName: ${hasController ? "✓ found" : "✗ not found"}');
    
    return _channelControllers[channelName]?.stream;
  }

  void disconnect() {
    if (kDebugMode) debugPrint('[WebSocket] Disconnecting');
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _reconnectAttempts = 0;
    
    for (var controller in _channelControllers.values) {
      controller.close();
    }
    _channelControllers.clear();
    _pendingSubscriptions.clear();
    
    _pendingPersonalChannels.clear();
    _channel?.sink.close();
    _channel = null;
    _updateStatus(ConnectionStatus.disconnected);
  }

  void resetReconnection() {
    _reconnectAttempts = 0;
    _shouldReconnect = true;
  }

  void dispose() {
    disconnect();
    _statusController.close();
    _globalMessageController.close();
  }
}
