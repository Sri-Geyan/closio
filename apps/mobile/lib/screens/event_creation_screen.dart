import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../services/api_service.dart';
import '../services/weather_service.dart';
import '../providers/app_state_provider.dart';
import 'sport_setup/sport_type_selector_screen.dart';

class EventCreationScreen extends StatefulWidget {
  final DateTime selectedDate;
  final String? hubId;
  const EventCreationScreen({super.key, required this.selectedDate, this.hubId});

  @override
  State<EventCreationScreen> createState() => _EventCreationScreenState();
}

class _EventCreationScreenState extends State<EventCreationScreen> {
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  String _selectedType = 'Hangout';
  final List<String> _types = ['Hangout', 'Food', 'Movie', 'Sport', 'Game Night'];
  final _lobbyLinkController = TextEditingController();
  TimeOfDay? _selectedTime;

  List<dynamic> _hubs = [];
  String? _selectedHubId;
  bool _isLoadingHubs = true;
  bool _isCreating = false;
  bool _isPlanning = false;
  Map<String, dynamic>? _aiPlan;

  @override
  void initState() {
    super.initState();
    _fetchHubs();
  }

  Future<void> _fetchHubs() async {
    try {
      final hubs = await ApiService.getHubs();
      setState(() {
        _hubs = hubs;
        if (widget.hubId != null) {
          _selectedHubId = widget.hubId;
        } else if (_hubs.isNotEmpty) {
          _selectedHubId = _hubs.first['id'];
        }
        _isLoadingHubs = false;
      });
    } catch (e) {
      setState(() => _isLoadingHubs = false);
    }
  }

  String _selectedRsvp = 'Going';
  final List<String> _rsvpOptions = ['Going', 'Maybe', "Can't go"];

  Future<void> _createEvent() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || _selectedHubId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title and select a hub.')),
      );
      return;
    }

    if (_selectedType == 'Sport') {
      // Navigate to sport setup flow
      Navigator.push(context, MaterialPageRoute(builder: (_) => SportTypeSelectorScreen(eventData: {
        'title': title,
        'hubId': _selectedHubId,
        'date': widget.selectedDate.toIso8601String().split('T')[0],
        'time': _selectedTime != null ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}' : null,
        'type': 'Sport',
        'rsvpStatus': _selectedRsvp,
      })));
      return;
    }

    setState(() => _isCreating = true);
    try {
      await ApiService.createEvent({
        'title': title,
        'hubId': _selectedHubId,
        'date': widget.selectedDate.toIso8601String().split('T')[0],
        'time': _selectedTime != null ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}' : null,
        'location': _locationController.text.trim(),
        'type': _selectedType,
        'lobbyLink': _selectedType == 'Game Night' ? _lobbyLinkController.text.trim() : null,
        'rsvpStatus': _selectedRsvp,
      });
      if (mounted) {
        // Force refresh the hub's events in AppStateProvider so the Calendar tab updates
        context.read<AppStateProvider>().fetchEvents(_selectedHubId!, forceRefresh: true);
        
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event Created!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create event: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Map<String, dynamic>? _timingSuggestion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fetchTimingSuggestion();
  }

  void _fetchTimingSuggestion() async {
    final sug = await WeatherService.getTimingSuggestion(widget.selectedDate, _selectedType);
    if (mounted) {
      setState(() => _timingSuggestion = sug);
    }
  }

  Future<void> _generateAiPlan() async {
    setState(() => _isPlanning = true);
    try {
      final response = await ApiService.planEvent(
        _selectedType,
        4,
        {'lat': 0, 'lng': 0},
        'Medium'
      );
      if (mounted) {
        setState(() {
          _aiPlan = response['plan'];
          // Pre-fill location based on first venue
          if (_aiPlan != null && _aiPlan!['venues'].isNotEmpty) {
            _locationController.text = _aiPlan!['venues'][0]['name'];
            _titleController.text = '$_selectedType at ${_locationController.text}';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to generate plan: $e')));
      }
    } finally {
      if (mounted) setState(() => _isPlanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClosioTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: ClosioTheme.backgroundColor,
        elevation: 0,
        title: const Text('Create Event', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoadingHubs
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Date: ${widget.selectedDate.toString().split(' ')[0]}', style: Theme.of(context).textTheme.bodyLarge),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (time != null && mounted) {
                            setState(() => _selectedTime = time);
                          }
                        },
                        icon: const Icon(Icons.access_time),
                        label: Text(_selectedTime != null ? _selectedTime!.format(context) : 'Add Time'),
                      ),
                    ],
                  ),
                  if (_timingSuggestion != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: Colors.blue, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Best window: ${_timingSuggestion!['window']} · ${_timingSuggestion!['weather']}', style: const TextStyle(fontSize: 12, color: Colors.blue))),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (widget.hubId == null) ...[
                    if (_hubs.isEmpty)
                      const Text('You need to join or create a Hub first to make events!', style: TextStyle(color: Colors.red))
                    else
                      DropdownButtonFormField<String>(
                        value: _selectedHubId,
                        decoration: const InputDecoration(labelText: 'Select Hub'),
                        items: _hubs.map((hub) {
                          return DropdownMenuItem<String>(
                            value: hub['id'],
                            child: Text(hub['name']),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() => _selectedHubId = val);
                        },
                      ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Event Title', hintText: 'e.g. Dinner at Marios'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _locationController,
                    decoration: const InputDecoration(labelText: 'Location', hintText: 'e.g. 123 Main St'),
                  ),
                  const SizedBox(height: 24),
                  Text('Type', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _types.map((type) {
                      return ChoiceChip(
                        label: Text(type),
                        selected: _selectedType == type,
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedType = type);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  if (_selectedType == 'Game Night') ...[
                    TextField(
                      controller: _lobbyLinkController,
                      decoration: const InputDecoration(
                        labelText: 'Lobby Link (Optional)',
                        hintText: 'e.g. steam://joinlobby/... or discord.gg/...',
                        prefixIcon: Icon(Icons.link),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isPlanning ? null : _generateAiPlan,
                      icon: _isPlanning ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome, color: ClosioTheme.primaryColor),
                      label: Text('Plan this for me', style: TextStyle(color: ClosioTheme.primaryColor)),
                      style: OutlinedButton.styleFrom(side: BorderSide(color: ClosioTheme.primaryColor.withOpacity(0.5))),
                    ),
                  ),
                  if (_aiPlan != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: ClosioTheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ClosioTheme.primaryColor.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.auto_awesome, size: 16, color: ClosioTheme.primaryColor),
                              const SizedBox(width: 8),
                              Text('AI Generated Plan', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: ClosioTheme.primaryColor)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Suggested Time: ${_aiPlan!['suggested_timing']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('Est. Split: ${_aiPlan!['split_estimate']['per_person']} / person'),
                          const SizedBox(height: 8),
                          const Text('Top Venues:', style: TextStyle(fontWeight: FontWeight.bold)),
                          ...(_aiPlan!['venues'] as List).map((v) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(v['name']),
                            subtitle: Text('${v['type']} • ${v['distance']}'),
                            trailing: Text(v['cost_estimate']),
                            onTap: () {
                              _locationController.text = v['name'];
                              _titleController.text = '$_selectedType at ${v['name']}';
                            },
                          )),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text('My RSVP', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _rsvpOptions.map((rsvp) {
                      return ChoiceChip(
                        label: Text(rsvp),
                        selected: _selectedRsvp == rsvp,
                        selectedColor: rsvp == 'Going' ? ClosioTheme.primaryColor : (rsvp == 'Maybe' ? Colors.orange : ClosioTheme.errorColor),
                        labelStyle: TextStyle(color: _selectedRsvp == rsvp ? Colors.white : Colors.white70, fontWeight: FontWeight.w900),
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedRsvp = rsvp);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: (_isCreating || _hubs.isEmpty) ? null : _createEvent,
                      child: _isCreating ? const CircularProgressIndicator(color: Colors.white) : const Text('Create & Invite'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
