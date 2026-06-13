import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../services/health_service.dart';
import '../../models/health_data.dart';

class SportRecapScreen extends StatefulWidget {
  final String eventId;
  final String eventName;
  final DateTime eventDate;

  const SportRecapScreen({
    super.key,
    required this.eventId,
    required this.eventName,
    required this.eventDate,
  });

  @override
  State<SportRecapScreen> createState() => _SportRecapScreenState();
}

class _SportRecapScreenState extends State<SportRecapScreen> {
  final HealthService _healthService = HealthService();
  final TextEditingController _noteController = TextEditingController();
  DailyHealthSummary? _healthSummary;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecap();
  }

  Future<void> _loadRecap() async {
    await _healthService.init();
    
    // Fetch the summary for the date of the event
    if (_healthService.isOptedIn) {
      _healthSummary = await _healthService.getDailySummary(widget.eventDate);
    }
    
    final savedNote = await _healthService.getSportRecapNote(widget.eventId);
    if (savedNote != null) {
      _noteController.text = savedNote;
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    await _healthService.saveSportRecapNote(widget.eventId, _noteController.text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note saved privately.')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClosioTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: ClosioTheme.backgroundColor,
        elevation: 0,
        title: const Text('Event Recap', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.sports_score, size: 64, color: ClosioTheme.primaryColor),
                  const SizedBox(height: 16),
                  Text(
                    widget.eventName,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'How did it go? Here is your private health snapshot for this day.',
                    style: TextStyle(color: ClosioTheme.secondaryColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  
                  if (_healthSummary != null)
                    _buildStatsRow()
                  else
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: ClosioTheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Health data not available. Ensure you have opted in to Health Snapshot.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: ClosioTheme.secondaryColor),
                      ),
                    ),
                  
                  const SizedBox(height: 32),
                  const Text('Personal Note (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _noteController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Add private notes about your performance, what went well, or what to improve...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: ClosioTheme.surfaceContainer),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: ClosioTheme.surfaceContainer),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _saveNote,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ClosioTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save Recap'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsRow() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ClosioTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClosioTheme.surfaceContainer),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatMetric(Icons.directions_walk, '${_healthSummary!.steps}', 'Steps'),
          _buildStatMetric(Icons.local_fire_department, '${_healthSummary!.activeCalories.toInt()} kcal', 'Active'),
          _buildStatMetric(Icons.map, '${(_healthSummary!.distanceWalkedMeters / 1000).toStringAsFixed(1)} km', 'Distance'),
        ],
      ),
    );
  }

  Widget _buildStatMetric(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: ClosioTheme.primaryColor, size: 28),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: ClosioTheme.secondaryColor, fontSize: 12)),
      ],
    );
  }
}
