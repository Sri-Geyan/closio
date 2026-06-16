import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme.dart';
import '../../models/health_data.dart';
import '../../services/health_service.dart';

class HealthDashboardScreen extends StatefulWidget {
  const HealthDashboardScreen({super.key});

  @override
  State<HealthDashboardScreen> createState() => _HealthDashboardScreenState();
}

class _HealthDashboardScreenState extends State<HealthDashboardScreen> {
  final HealthService _healthService = HealthService();
  bool _isLoading = true;
  bool _isOptedIn = false;

  DailyHealthSummary? _daily;
  WeeklyTrend? _weekly;
  MonthlySummary? _monthly;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await _healthService.init();
    _isOptedIn = _healthService.isOptedIn;

    if (_isOptedIn) {
      final now = DateTime.now();
      _daily = await _healthService.getDailySummary(now);
      _weekly = await _healthService.getWeeklyTrend();
      _monthly = await _healthService.getMonthlySummary();
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _handleOptIn() async {
    final granted = await _healthService.requestPermissions();
    if (granted) {
      _loadData();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Health permissions not granted. Please ensure Health Connect is installed and permissions are enabled.')),
        );
      }
    }
  }

  Future<void> _handleOptOut() async {
    await _healthService.revokePermissions();
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClosioTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: ClosioTheme.backgroundColor,
        elevation: 0,
        title: const Text('Health Snapshot', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_isOptedIn)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Health Data Privacy'),
                    content: const Text(
                      'Your health data is completely private and stored locally. It is never shared with hubs or other members.\n\n'
                      'Would you like to revoke access and opt out of Health Snapshot?'
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _handleOptOut();
                        },
                        child: const Text('Opt Out', style: TextStyle(color: ClosioTheme.errorColor)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_isOptedIn
              ? _buildOptInView()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildDailyCard(),
                      const SizedBox(height: 16),
                      _buildWeeklyCard(),
                      const SizedBox(height: 16),
                      _buildMonthlyCard(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildOptInView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.favorite, size: 64, color: ClosioTheme.primaryColor),
            const SizedBox(height: 24),
            Text(
              'Your Private Health Snapshot',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'View your daily, weekly, and monthly health aggregates locally. Your data is strictly private, non-gamified, and never shared with anyone.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: ClosioTheme.secondaryColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _handleOptIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: ClosioTheme.primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Enable Health Access'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyCard() {
    if (_daily == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ClosioTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClosioTheme.surfaceContainer),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Today', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatMetric(Icons.directions_walk, '${_daily!.steps}', 'Steps'),
              _buildStatMetric(Icons.local_fire_department, '${_daily!.activeCalories.toInt()} kcal', 'Active'),
              _buildStatMetric(Icons.map, '${(_daily!.distanceWalkedMeters / 1000).toStringAsFixed(1)} km', 'Distance'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatMetric(Icons.bedtime, '${_daily!.sleepDuration.inHours}h ${_daily!.sleepDuration.inMinutes % 60}m', 'Sleep'),
              _buildStatMetric(Icons.favorite, '${_daily!.restingHeartRate} bpm', 'Resting HR'),
            ],
          ),
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

  Widget _buildWeeklyCard() {
    if (_weekly == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ClosioTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClosioTheme.surfaceContainer),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Weekly Trend', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (_weekly!.dailySteps.reduce((a, b) => a > b ? a : b) + 2000).toDouble(),
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                        final idx = value.toInt() % 7;
                        return Text(days[idx], style: const TextStyle(fontSize: 10, color: ClosioTheme.secondaryColor));
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(
                  7,
                  (i) => BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: _weekly!.dailySteps[i].toDouble(),
                        color: ClosioTheme.primaryColor,
                        width: 12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sleep Consistency', style: TextStyle(color: ClosioTheme.secondaryColor, fontSize: 12)),
                  Text(_weekly!.sleepConsistency, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Most Active Day', style: TextStyle(color: ClosioTheme.secondaryColor, fontSize: 12)),
                  Text(_weekly!.mostActiveDay, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyCard() {
    if (_monthly == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ClosioTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClosioTheme.surfaceContainer),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Monthly Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              backgroundColor: ClosioTheme.surfaceContainerLow,
              child: Icon(Icons.map, color: ClosioTheme.primaryColor),
            ),
            title: const Text('Total Distance', style: TextStyle(fontWeight: FontWeight.w600)),
            trailing: Text('${(_monthly!.totalDistanceMeters / 1000).toStringAsFixed(1)} km', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              backgroundColor: ClosioTheme.surfaceContainerLow,
              child: Icon(Icons.directions_walk, color: ClosioTheme.primaryColor),
            ),
            title: const Text('Avg Daily Steps', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('Baseline: ${_monthly!.baselineSteps}'),
            trailing: Text('${_monthly!.avgDailySteps}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              backgroundColor: ClosioTheme.surfaceContainerLow,
              child: Icon(Icons.sports_basketball, color: ClosioTheme.primaryColor),
            ),
            title: const Text('Sport Events Attended', style: TextStyle(fontWeight: FontWeight.w600)),
            trailing: Text('${_monthly!.sportEventsAttended}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
