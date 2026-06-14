import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme.dart';
import '../../services/places_service.dart';
import '../../services/api_service.dart';
import '../../providers/app_state_provider.dart';

class VenueDiscoveryScreen extends StatefulWidget {
  final Map<String, dynamic> eventData;

  const VenueDiscoveryScreen({super.key, required this.eventData});

  @override
  State<VenueDiscoveryScreen> createState() => _VenueDiscoveryScreenState();
}

class _VenueDiscoveryScreenState extends State<VenueDiscoveryScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _venues = [];
  bool _isSearching = false;
  bool _isCreating = false;

  void _search() async {
    if (_searchController.text.isEmpty) return;
    setState(() => _isSearching = true);
    final results = await PlacesService.searchVenues('${widget.eventData['sportType']} ${_searchController.text}', 0, 0);
    setState(() {
      _venues = results;
      _isSearching = false;
    });
  }

  Future<void> _selectVenue(Map<String, dynamic> venue) async {
    setState(() => _isCreating = true);
    final finalData = Map<String, dynamic>.from(widget.eventData);
    finalData['location'] = venue['name'];
    finalData['sportDetails'] = {
      'venue': venue,
      // Default match details
      'playersCount': 2,
    };

    try {
      await ApiService.createEvent(finalData);
      if (mounted) {
        context.read<AppStateProvider>().fetchEvents(widget.eventData['hubId'], forceRefresh: true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sport Event Created!')));
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sport = widget.eventData['sportType'];
    return Scaffold(
      backgroundColor: ClosioTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Find $sport Venue'),
        backgroundColor: ClosioTheme.backgroundColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Location/Neighborhood',
                      hintText: 'e.g. Downtown',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _search,
                  child: const Text('Search'),
                ),
              ],
            ),
          ),
          if (_isSearching) const CircularProgressIndicator()
          else if (_venues.isEmpty) 
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Text('Search for a neighborhood to find venues nearby. No courts found? Try a broader area.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            )
          else Expanded(
            child: ListView.builder(
              itemCount: _venues.length,
              itemBuilder: (context, index) {
                final venue = _venues[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text(venue['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${venue['distance']} • ⭐ ${venue['rating']} ${venue['openNow'] == true ? '• Open Now' : ''}'),
                    trailing: const Icon(Icons.arrow_forward),
                    onTap: () => _selectVenue(venue),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      // Overlay loading if creating
      bottomSheet: _isCreating ? const LinearProgressIndicator() : null,
    );
  }
}
