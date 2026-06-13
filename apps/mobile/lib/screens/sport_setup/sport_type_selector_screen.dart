import 'package:flutter/material.dart';
import '../../theme.dart';
import 'venue_discovery_screen.dart';
import 'running_setup_screen.dart';

class SportTypeSelectorScreen extends StatelessWidget {
  final Map<String, dynamic> eventData;

  const SportTypeSelectorScreen({super.key, required this.eventData});

  final List<Map<String, dynamic>> _sports = const [
    {'name': 'Running', 'icon': Icons.directions_run},
    {'name': 'Cricket', 'icon': Icons.sports_cricket},
    {'name': 'Football', 'icon': Icons.sports_soccer},
    {'name': 'Badminton (Shuttle)', 'icon': Icons.sports_tennis},
    {'name': 'Pickleball', 'icon': Icons.sports_tennis},
    {'name': 'Swimming', 'icon': Icons.pool},
    {'name': 'Snooker / Pool', 'icon': Icons.sports_esports},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClosioTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: ClosioTheme.backgroundColor,
        elevation: 0,
        title: const Text('Select Sport', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _sports.length,
        itemBuilder: (context, index) {
          final sport = _sports[index];
          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              leading: Icon(sport['icon'], size: 32, color: ClosioTheme.primaryColor),
              title: Text(sport['name'], style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                final updatedData = Map<String, dynamic>.from(eventData);
                updatedData['sportType'] = sport['name'];
                
                if (sport['name'] == 'Running') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => RunningSetupScreen(eventData: updatedData)));
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => VenueDiscoveryScreen(eventData: updatedData)));
                }
              },
            ),
          );
        },
      ),
    );
  }
}
