import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class AppStateProvider with ChangeNotifier {
  // Global Data
  List<dynamic> _hubs = [];
  bool _isLoadingHubs = false;

  // Cached Data by Hub ID
  final Map<String, List<dynamic>> _hubMessages = {};
  final Map<String, List<dynamic>> _hubEvents = {};

  // Loading states
  final Map<String, bool> _isLoadingMessages = {};
  final Map<String, bool> _isLoadingEvents = {};

  // Getters
  List<dynamic> get hubs => _hubs;
  bool get isLoadingHubs => _isLoadingHubs;

  List<dynamic> getMessages(String hubId) => _hubMessages[hubId] ?? [];
  bool isLoadingMessages(String hubId) => _isLoadingMessages[hubId] ?? false;

  List<dynamic> getEvents(String hubId) => _hubEvents[hubId] ?? [];
  bool isLoadingEvents(String hubId) => _isLoadingEvents[hubId] ?? false;

  // Fetch Hubs
  Future<void> fetchHubs({bool forceRefresh = false}) async {
    if (_hubs.isNotEmpty && !forceRefresh) return; // Return cached
    _isLoadingHubs = true;
    notifyListeners();

    try {
      final hubs = await ApiService.getHubs();
      _hubs = hubs;
    } catch (e) {
      debugPrint('Failed to fetch hubs: $e');
    } finally {
      _isLoadingHubs = false;
      notifyListeners();
    }
  }

  // Fetch Messages for a specific Hub
  Future<void> fetchMessages(String hubId, {bool forceRefresh = false}) async {
    if (_hubMessages.containsKey(hubId) && !forceRefresh) return; // Return cached
    _isLoadingMessages[hubId] = true;
    notifyListeners();

    try {
      final msgs = await ApiService.getHubMessages(hubId);
      _hubMessages[hubId] = msgs;
    } catch (e) {
      debugPrint('Failed to fetch messages for $hubId: $e');
    } finally {
      _isLoadingMessages[hubId] = false;
      notifyListeners();
    }
  }

  // Add a new message dynamically (e.g., from WebSockets)
  void addMessage(String hubId, dynamic message) {
    if (_hubMessages.containsKey(hubId)) {
      if (!_hubMessages[hubId]!.any((m) => m['id'] == message['id'])) {
        _hubMessages[hubId]!.add(message);
        notifyListeners();
      }
    }
  }

  // Update a message (e.g., poll updated)
  void updateMessage(String hubId, dynamic message) {
    if (_hubMessages.containsKey(hubId)) {
      final idx = _hubMessages[hubId]!.indexWhere((m) => m['id'] == message['id']);
      if (idx != -1) {
        _hubMessages[hubId]![idx] = message;
        notifyListeners();
      }
    }
  }

  // Fetch Events for a specific Hub
  Future<void> fetchEvents(String hubId, {bool forceRefresh = false}) async {
    if (_hubEvents.containsKey(hubId) && !forceRefresh) return; // Return cached
    _isLoadingEvents[hubId] = true;
    notifyListeners();

    try {
      final events = await ApiService.getHubEvents(hubId);
      _hubEvents[hubId] = events;
    } catch (e) {
      debugPrint('Failed to fetch events for $hubId: $e');
    } finally {
      _isLoadingEvents[hubId] = false;
      notifyListeners();
    }
  }

  // Clear all data (on logout)
  void clearAll() {
    _hubs.clear();
    _hubMessages.clear();
    _hubEvents.clear();
    _isLoadingMessages.clear();
    _isLoadingEvents.clear();
    notifyListeners();
  }
}
