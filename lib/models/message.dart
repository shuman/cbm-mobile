class Message {
  final String id;
  final String body;
  final DateTime createdAt;
  final MessageUser sender;
  final bool isFromMe;
  final bool? isRead;
  final DateTime? readAt;

  Message({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.sender,
    required this.isFromMe,
    this.isRead,
    this.readAt,
  });

  factory Message.fromJson(Map<String, dynamic> json, String currentUserId) {
    final senderId = json['user_id']?.toString() ?? json['sender_id']?.toString() ?? '';
    
    return Message(
      id: json['id']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      sender: MessageUser.fromJson(json['user'] ?? json['sender'] ?? {}),
      isFromMe: senderId == currentUserId,
      isRead: json['is_read'] as bool?,
      readAt: json['read_at'] != null ? DateTime.tryParse(json['read_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'body': body,
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead,
      'read_at': readAt?.toIso8601String(),
    };
  }
}

class MessageUser {
  final String id;
  final String name;
  final String? email;
  final String? photoPath;

  MessageUser({
    required this.id,
    required this.name,
    this.email,
    this.photoPath,
  });

  factory MessageUser.fromJson(Map<String, dynamic> json) {
    return MessageUser(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown User',
      email: json['email']?.toString(),
      photoPath: json['photo_path']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'photo_path': photoPath,
    };
  }
}
