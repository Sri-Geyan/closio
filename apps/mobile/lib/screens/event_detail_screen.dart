import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../services/api_service.dart';
import 'health/sport_recap_screen.dart';
import 'split_screen.dart';
import 'jukebox_screen.dart';
import 'package:intl/intl.dart';

class EventDetailScreen extends StatefulWidget {
  final dynamic event;

  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late dynamic _event;
  bool _isUpdatingRsvp = false;
  List<dynamic> _actionLinks = [];
  bool _isLoadingLinks = true;

  @override
  void initState() {
    super.initState();
    _event = widget.event;
    _fetchActionLinks();
  }

  Future<void> _fetchActionLinks() async {
    try {
      final links = await ApiService.getEventActionLinks(_event['id']);
      if (mounted) {
        setState(() {
          _actionLinks = links;
          _isLoadingLinks = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingLinks = false);
      }
    }
  }

  void _handleActionLinkTap(dynamic link) async {
    // Record tap analytics
    try {
      await ApiService.recordActionLinkTap(_event['id'], link['type']);
    } catch (_) {}

    if (link['internal'] == true) {
      if (link['type'] == 'Split') {
        Navigator.push(context, MaterialPageRoute(builder: (context) => SplitScreen(hubId: _event['hubId'] ?? '', hubName: 'Hub')));
      } else if (link['type'] == 'Spotify') {
        Navigator.push(context, MaterialPageRoute(builder: (context) => JukeboxScreen(hubId: _event['hubId'] ?? '', hubName: 'Hub')));
      } else if (link['type'] == 'Closio Recap') {
        DateTime parsedDate = DateTime.now();
        try {
          parsedDate = DateTime.parse(_event['date'].toString());
        } catch (_) {}
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => SportRecapScreen(
            eventId: _event['id'],
            eventName: _event['title'] ?? 'Sport Event',
            eventDate: parsedDate,
          ),
        ));
      }
    } else {
      final url = Uri.parse(link['url']);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open ${link['title']}')));
        }
      }
    }
  }

  Future<void> _updateRsvp(String status) async {
    setState(() => _isUpdatingRsvp = true);
    try {
      await ApiService.updateRsvp(_event['id'], status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('RSVP Updated to $status')));
        // In a real app we'd fetch the event again to refresh the guest list.
        // For V1, we just pop or show success.
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating RSVP')));
      }
    } finally {
      if (mounted) setState(() => _isUpdatingRsvp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final attendances = _event['attendances'] as List<dynamic>? ?? [];
    int goingCount = attendances.where((a) => a['status'] == 'Going').length;
    int maybeCount = attendances.where((a) => a['status'] == 'Maybe').length;
    int cantGoCount = attendances.where((a) => a['status'] == "Can't go").length;

    bool isPastEvent = false;
    DateTime? parsedDate;
    try {
      // Assuming event['date'] is a string like "YYYY-MM-DD" or similar ISO date
      parsedDate = DateTime.parse(_event['date'].toString());
      if (parsedDate.isBefore(DateTime.now())) {
        isPastEvent = true;
      }
    } catch (_) {
      // If unparseable or custom format like "Jan 14", we'd need a robust parser.
      // For this implementation, we'll try basic parsing.
      try {
        final format = DateFormat('MMMM d, yyyy');
        parsedDate = format.parse(_event['date'].toString());
        if (parsedDate.isBefore(DateTime.now())) {
          isPastEvent = true;
        }
      } catch (_) {}
    }

    return Scaffold(
      backgroundColor: ClosioTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: ClosioTheme.backgroundColor,
        elevation: 0,
        title: Text('Event Details', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner
            Container(
              padding: const EdgeInsets.all(24),
              width: double.infinity,
              decoration: BoxDecoration(
                color: ClosioTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ClosioTheme.primaryColor.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Icon(Icons.event_available, size: 48, color: ClosioTheme.primaryColor),
                  const SizedBox(height: 16),
                  Text(
                    _event['title'] ?? 'Event',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_event['date']} • ${_event['time'] ?? 'All day'}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: ClosioTheme.primaryColor),
                  ),
                  if (_event['location'] != null && _event['location'].toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '📍 ${_event['location']}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
                    ),
                  ]
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Links
            if (_isLoadingLinks)
              const Center(child: CircularProgressIndicator())
            else if (_actionLinks.isNotEmpty) ...[
              Text('Suggested Actions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _actionLinks.length,
                  itemBuilder: (context, index) {
                    final link = _actionLinks[index];
                    IconData iconData = Icons.link;
                    switch (link['icon']) {
                      case 'map': iconData = Icons.map; break;
                      case 'directions_car': iconData = Icons.directions_car; break;
                      case 'restaurant': iconData = Icons.restaurant; break;
                      case 'movie': iconData = Icons.movie; break;
                      case 'directions_run': iconData = Icons.directions_run; break;
                      case 'fitness_center': iconData = Icons.fitness_center; break;
                      case 'receipt_long': iconData = Icons.receipt_long; break;
                      case 'cloud': iconData = Icons.cloud; break;
                      case 'music_note': iconData = Icons.music_note; break;
                    }

                    return GestureDetector(
                      onTap: () => _handleActionLinkTap(link),
                      child: Container(
                        width: 140,
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ClosioTheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(iconData, color: ClosioTheme.primaryColor),
                            const Spacer(),
                            Text(link['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(link['subtitle'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
            ],

            if (isPastEvent && _event['type'] == 'Sport') ...[
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SportRecapScreen(
                        eventId: _event['id'],
                        eventName: _event['title'] ?? 'Sport Event',
                        eventDate: parsedDate ?? DateTime.now(),
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.pink.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.pink.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.favorite, color: Colors.pink, size: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('How did it go?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text('View your private health snapshot for this event.', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.pink),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
            
            // RSVP Actions
            Text('Your RSVP', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _isUpdatingRsvp 
              ? const Center(child: CircularProgressIndicator())
              : Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => _updateRsvp('Going'),
                  style: ElevatedButton.styleFrom(backgroundColor: ClosioTheme.primaryColor),
                  child: const Text('Going'),
                ),
                ElevatedButton(
                  onPressed: () => _updateRsvp('Maybe'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  child: const Text('Maybe'),
                ),
                ElevatedButton(
                  onPressed: () => _updateRsvp("Can't go"),
                  style: ElevatedButton.styleFrom(backgroundColor: ClosioTheme.errorColor),
                  child: const Text("Can't go"),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Guest List
            Text('Guest List ($goingCount going • $maybeCount maybe • $cantGoCount can\'t go)', 
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (attendances.isEmpty)
              const Text('No RSVPs yet.')
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: attendances.length,
                itemBuilder: (context, index) {
                  final att = attendances[index];
                  final user = att['user'];
                  final status = att['status'];
                  
                  Color statusColor = ClosioTheme.primaryColor;
                  if (status == 'Maybe') statusColor = Colors.orange;
                  if (status == "Can't go") statusColor = ClosioTheme.errorColor;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: ClosioTheme.surfaceContainer,
                      backgroundImage: user?['avatarUrl'] != null ? NetworkImage(user['avatarUrl']) : null,
                      child: user?['avatarUrl'] == null ? const Icon(Icons.person, color: ClosioTheme.secondaryColor) : null,
                    ),
                    title: Text(user?['username'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  );
                },
              )
          ],
        ),
      ),
    );
  }
}
