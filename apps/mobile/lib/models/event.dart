class Event {
  final String id;
  final String hubId;
  final String title;
  final String? description;
  final String date;
  final String? time;
  final String? location;
  final String type;
  final String? sportType;
  final Map<String, dynamic>? sportDetails;
  final DateTime createdAt;
  final DateTime updatedAt;

  Event({
    required this.id,
    required this.hubId,
    required this.title,
    this.description,
    required this.date,
    this.time,
    this.location,
    required this.type,
    this.sportType,
    this.sportDetails,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'],
      hubId: json['hubId'],
      title: json['title'],
      description: json['description'],
      date: json['date'],
      time: json['time'],
      location: json['location'],
      type: json['type'] ?? 'Hangout',
      sportType: json['sportType'],
      sportDetails: json['sportDetails'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hubId': hubId,
      'title': title,
      'description': description,
      'date': date,
      'time': time,
      'location': location,
      'type': type,
      'sportType': sportType,
      'sportDetails': sportDetails,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
