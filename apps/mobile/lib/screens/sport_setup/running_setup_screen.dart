import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../theme.dart';
import '../../services/api_service.dart';
import '../../providers/app_state_provider.dart';
import '../../services/weather_service.dart';
import '../../services/places_service.dart';

class RunningSetupScreen extends StatefulWidget {
  final Map<String, dynamic> eventData;

  const RunningSetupScreen({super.key, required this.eventData});

  @override
  State<RunningSetupScreen> createState() => _RunningSetupScreenState();
}

class _RunningSetupScreenState extends State<RunningSetupScreen> {
  final _startController = TextEditingController();
  final _endController = TextEditingController();
  
  Map<String, dynamic>? _conditions;
  bool _isCreating = false;
  
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(37.7749, -122.4194), // Default SF
    zoom: 12,
  );

  @override
  void initState() {
    super.initState();
    _fetchConditions();
  }

  Future<void> _fetchConditions() async {
    final dateStr = widget.eventData['date'];
    final date = DateTime.parse(dateStr);
    final conds = await WeatherService.getRunningConditions(date);
    setState(() => _conditions = conds);
  }

  Future<void> _calculateRoute() async {
    final start = _startController.text;
    final end = _endController.text;
    if (start.isEmpty || end.isEmpty) return;
    
    // Fetch coordinates
    final startLatLng = await PlacesService.getCoordinates(start);
    final endLatLng = await PlacesService.getCoordinates(end);
    
    if (startLatLng == null || endLatLng == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not find one of the locations')));
      }
      return;
    }
    
    setState(() {
      _markers = {
        Marker(markerId: const MarkerId('start'), position: LatLng(startLatLng['lat'], startLatLng['lng']), infoWindow: const InfoWindow(title: 'Start')),
        Marker(markerId: const MarkerId('end'), position: LatLng(endLatLng['lat'], endLatLng['lng']), infoWindow: const InfoWindow(title: 'End'), icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue)),
      };
      
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          color: ClosioTheme.primaryColor,
          width: 4,
          points: [
            LatLng(startLatLng['lat'], startLatLng['lng']),
            LatLng(endLatLng['lat'], endLatLng['lng']),
          ],
        )
      };
    });
    
    // Animate camera to fit both
    if (_mapController != null) {
      LatLngBounds bounds;
      if (startLatLng['lat'] > endLatLng['lat']) {
        bounds = LatLngBounds(
          southwest: LatLng(endLatLng['lat'], endLatLng['lng']),
          northeast: LatLng(startLatLng['lat'], startLatLng['lng']),
        );
      } else {
        bounds = LatLngBounds(
          southwest: LatLng(startLatLng['lat'], startLatLng['lng']),
          northeast: LatLng(endLatLng['lat'], endLatLng['lng']),
        );
      }
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    }
  }

  Future<void> _finishSetup() async {
    if (_startController.text.isEmpty || _endController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter start and end points')));
      return;
    }

    setState(() => _isCreating = true);
    final finalData = Map<String, dynamic>.from(widget.eventData);
    finalData['sportDetails'] = {
      'startPoint': _startController.text,
      'endPoint': _endController.text,
      'conditions': _conditions,
    };
    
    try {
      await ApiService.createEvent(finalData);
      if (mounted) {
        context.read<AppStateProvider>().fetchEvents(widget.eventData['hubId'], forceRefresh: true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Running Event Created!')));
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
    return Scaffold(
      backgroundColor: ClosioTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Setup Run'),
        backgroundColor: ClosioTheme.backgroundColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _startController,
              decoration: const InputDecoration(labelText: 'Start Point', hintText: 'Current Location or address'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _endController,
              decoration: const InputDecoration(labelText: 'End Point', hintText: 'Where are we running to?'),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _calculateRoute,
                icon: const Icon(Icons.map),
                label: const Text('Calculate Route'),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // MAP WIDGET
            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              clipBehavior: Clip.antiAlias,
              child: GoogleMap(
                initialCameraPosition: _initialPosition,
                onMapCreated: (controller) => _mapController = controller,
                markers: _markers,
                polylines: _polylines,
                myLocationEnabled: false,
                zoomControlsEnabled: false,
              ),
            ),
            
            const SizedBox(height: 24),
            
            if (_conditions != null) ...[
              Text('Route Conditions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildCondCard(Icons.thermostat, _conditions!['weather']['temp'], 'Weather')),
                  const SizedBox(width: 8),
                  Expanded(child: _buildCondCard(Icons.air, _conditions!['aqi']['label'], 'AQI')),
                ],
              ),
              const SizedBox(height: 8),
              _buildCondCard(Icons.directions_car, _conditions!['traffic']['label'], 'Traffic', fullWidth: true),
              const SizedBox(height: 8),
              _buildCondCard(Icons.access_time, _conditions!['bestWindow'], 'Best Window', fullWidth: true, color: Colors.green.shade50),
            ] else ...[
              const Center(child: CircularProgressIndicator()),
            ],

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _finishSetup,
                child: _isCreating ? const CircularProgressIndicator(color: Colors.white) : const Text('Create Run Event'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCondCard(IconData icon, String value, String label, {bool fullWidth = false, Color? color}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: ClosioTheme.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
