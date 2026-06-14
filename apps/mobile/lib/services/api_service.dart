import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class ApiService {
  static String get backendUrl {
    const String envUrl = String.fromEnvironment('API_URL');
    if (envUrl.isNotEmpty) return envUrl;
    
    if (kIsWeb) return 'http://localhost:3000';
    if (Platform.isAndroid) return 'http://10.0.2.2:3000';
    return 'http://localhost:3000';
  }
  static final SupabaseClient _supabase = Supabase.instance.client;

  static Future<Map<String, String>> _getHeaders() async {
    final session = _supabase.auth.currentSession;
    if (session == null) throw Exception('User not logged in');

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${session.accessToken}',
    };
  }

  // --- Hubs ---

  static Future<List<dynamic>> getHubs() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$backendUrl/hubs'), headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load hubs');
    }
  }

  static Future<dynamic> syncUser(String username, {String? avatarUrl, String? fcmToken, String? upiId, String? bio}) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$backendUrl/users/sync'),
      headers: headers,
      body: jsonEncode({
        'username': username,
        'avatarUrl': avatarUrl,
        'fcmToken': fcmToken,
        'upiId': upiId,
        'bio': bio,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to sync user with backend: ${response.statusCode}');
    }
  }

  static Future<dynamic> getUserProfile() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$backendUrl/users/me'), headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch user profile');
    }
  }

  static Future<dynamic> createHub(String name, {String? avatarUrl}) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$backendUrl/hubs'),
      headers: headers,
      body: jsonEncode({'name': name, 'avatarUrl': avatarUrl}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create hub');
    }
  }

  static Future<List<dynamic>> getHubMembers(String hubId) async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$backendUrl/hubs/$hubId/members'), headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load hub members');
    }
  }

  static Future<dynamic> addHubMember(String hubId, String username) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$backendUrl/hubs/$hubId/members'),
      headers: headers,
      body: jsonEncode({'username': username}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to add hub member. Make sure they exist and you are an Admin.');
    }
  }

  static Future<void> leaveHub(String hubId) async {
    final headers = await _getHeaders();
    final response = await http.delete(Uri.parse('$backendUrl/hubs/$hubId/members'), headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to leave hub');
    }
  }

  static Future<String> getHubInviteCode(String hubId) async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$backendUrl/hubs/$hubId/invite'), headers: headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['inviteCode'];
    } else {
      throw Exception('Failed to get invite code');
    }
  }

  static Future<dynamic> joinHubByInviteCode(String inviteCode) async {
    final headers = await _getHeaders();
    final response = await http.post(Uri.parse('$backendUrl/hubs/join/$inviteCode'), headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to join hub via invite code');
    }
  }

  static Future<List<dynamic>> getHubMessages(String hubId) async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$backendUrl/hubs/$hubId/messages'), headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load messages');
    }
  }

  // --- Events ---

  static Future<List<dynamic>> getAllEvents() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$backendUrl/events'), headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load events');
    }
  }

  static Future<List<dynamic>> getHubEvents(String hubId) async {
    final events = await getAllEvents();
    return events.where((e) => e['hubId'] == hubId).toList();
  }

  static Future<dynamic> createEvent(Map<String, dynamic> eventData) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$backendUrl/events'),
      headers: headers,
      body: jsonEncode(eventData),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create event');
    }
  }

  static Future<void> updateRsvp(String eventId, String status) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$backendUrl/events/$eventId/rsvp'),
      headers: headers,
      body: jsonEncode({'status': status}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update RSVP');
    }
  }

  // --- Deep Links ---

  static Future<List<dynamic>> getEventActionLinks(String eventId) async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$backendUrl/events/$eventId/action-links'), headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load action links');
    }
  }

  static Future<void> recordActionLinkTap(String eventId, String linkType) async {
    final headers = await _getHeaders();
    await http.post(Uri.parse('$backendUrl/events/$eventId/action-links/$linkType/tap'), headers: headers);
  }

  // --- Splits ---

  static Future<List<dynamic>> getUserSplits() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$backendUrl/splits'), headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load splits');
    }
  }

  static Future<List<dynamic>> getHubSplits(String hubId) async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$backendUrl/splits/hub/$hubId'), headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load hub splits');
    }
  }

  static Future<void> settleParticipantSplit(String participantId, bool isPaid) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$backendUrl/splits/$participantId/settle'),
      headers: headers,
      body: jsonEncode({'isPaid': isPaid}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update settlement status');
    }
  }

  static Future<dynamic> createSplit(Map<String, dynamic> splitData) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$backendUrl/splits'),
      headers: headers,
      body: jsonEncode(splitData),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create split');
    }
  }

  // --- Jukebox ---
  static Future<dynamic> getActiveJukeboxSession(String hubId) async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$backendUrl/jukebox/$hubId'), headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception('Failed to load jukebox session');
    }
  }

  static Future<dynamic> startJukeboxSession(String hubId, String name, String mood) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$backendUrl/jukebox/$hubId/start'),
      headers: headers,
      body: jsonEncode({'name': name, 'mood': mood}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to start jukebox session');
    }
  }

  static Future<void> endJukeboxSession(String hubId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$backendUrl/jukebox/$hubId/end'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to end jukebox session');
    }
  }

  // --- GENERIC METHODS ---
  static Future<dynamic> get(String endpoint) async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$backendUrl$endpoint'), headers: headers);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    }
    throw Exception('GET $endpoint failed');
  }

  static Future<dynamic> post(String endpoint, {Map<String, dynamic>? body}) async {
    final headers = await _getHeaders();
    final response = await http.post(Uri.parse('$backendUrl$endpoint'), headers: headers, body: body != null ? jsonEncode(body) : null);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    }
    throw Exception('POST $endpoint failed');
  }

  static Future<dynamic> put(String endpoint, {Map<String, dynamic>? body}) async {
    final headers = await _getHeaders();
    final response = await http.put(Uri.parse('$backendUrl$endpoint'), headers: headers, body: body != null ? jsonEncode(body) : null);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    }
    throw Exception('PUT $endpoint failed');
  }

  // --- AI MODULE ---
  
  static Future<Map<String, dynamic>> summariseChat(String text) async {
    final response = await http.post(
      Uri.parse('$backendUrl/ai/summarise'),
      headers: await _getHeaders(),
      body: jsonEncode({'text': text}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to summarise chat');
    }
  }

  // --- AI & Events ---
  static Future<Map<String, dynamic>> planEvent(String eventType, int groupSize, Map<String, dynamic> location, String budget) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$backendUrl/ai/plan-event'),
      headers: headers,
      body: jsonEncode({
        'eventType': eventType,
        'groupSize': groupSize,
        'location': location,
        'budget': budget,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to plan event: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> optimizeSport(String sportType, String date, double lat, double lng) async {
    final response = await http.post(
      Uri.parse('$backendUrl/ai/optimize-sport'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'sport_type': sportType,
        'date': date,
        'lat': lat,
        'lng': lng,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to optimize sport');
    }
  }

  // --- Locations ---
  static Future<List<dynamic>> getActiveLocations() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$backendUrl/locations'), headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  static Future<void> shareLocationAll(double lat, double lng, {int durationMinutes = 60}) async {
    final headers = await _getHeaders();
    await http.post(
      Uri.parse('$backendUrl/locations/share-all'),
      headers: headers,
      body: jsonEncode({
        'latitude': lat,
        'longitude': lng,
        'durationMinutes': durationMinutes
      })
    );
  }

  static Future<void> stopSharingLocationAll() async {
    final headers = await _getHeaders();
    await http.delete(Uri.parse('$backendUrl/locations/share-all'), headers: headers);
  }
}
