class Message {
  final String id;
  final String hubId;
  final String senderId;
  final String? text;
  final String? mediaUrl;
  final String type;
  final DateTime createdAt;
  final int? vanishTtl;
  final Map<String, dynamic>? sender;

  Message({
    required this.id,
    required this.hubId,
    required this.senderId,
    this.text,
    this.mediaUrl,
    required this.type,
    required this.createdAt,
    this.vanishTtl,
    this.sender,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      hubId: json['hubId'],
      senderId: json['senderId'],
      text: json['text'],
      mediaUrl: json['mediaUrl'],
      type: json['type'] ?? 'TEXT',
      createdAt: DateTime.parse(json['createdAt']),
      vanishTtl: json['vanishTtl'],
      sender: json['sender'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hubId': hubId,
      'senderId': senderId,
      'text': text,
      'mediaUrl': mediaUrl,
      'type': type,
      'createdAt': createdAt.toIso8601String(),
      'vanishTtl': vanishTtl,
      'sender': sender,
    };
  }

  bool get isExpired {
    if (vanishTtl == null) return false;
    final diff = DateTime.now().difference(createdAt).inSeconds;
    return diff > vanishTtl!;
  }
}
