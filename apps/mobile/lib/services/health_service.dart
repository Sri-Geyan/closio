import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/health_data.dart';
import 'package:intl/intl.dart';

class HealthService {
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();

  final HealthFactory _health = HealthFactory();
  bool _isOptedIn = false;

  bool get isOptedIn => _isOptedIn;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isOptedIn = prefs.getBool('health_opt_in') ?? false;
  }

  Future<bool> requestPermissions() async {
    final types = [
      HealthDataType.STEPS,
      HealthDataType.ACTIVE_ENERGY_BURNED,
      HealthDataType.SLEEP_SESSION,
      HealthDataType.RESTING_HEART_RATE,
      HealthDataType.DISTANCE_DELTA,
    ];

    try {
      final hasPermissions = await _health.hasPermissions(types) ?? false;
      if (!hasPermissions) {
        final granted = await _health.requestAuthorization(types);
        if (granted) {
          _isOptedIn = true;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('health_opt_in', true);
        }
        return granted;
      }
      return true;
    } catch (e) {
      print('Error requesting health permissions: $e');
      return false;
    }
  }

  Future<void> revokePermissions() async {
    _isOptedIn = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('health_opt_in', false);
    try {
      await _health.revokePermissions();
    } catch (e) {
      print('Error revoking permissions: $e');
    }
  }

  Future<DailyHealthSummary> getDailySummary(DateTime date) async {
    if (!_isOptedIn) {
      return DailyHealthSummary(
        steps: 0,
        distanceWalkedMeters: 0,
        activeCalories: 0,
        sleepDuration: Duration.zero,
        restingHeartRate: 0,
      );
    }

    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    int steps = 0;
    double distance = 0;
    double calories = 0;
    Duration sleep = Duration.zero;
    int rhr = 0;

    try {
      final stepsData = await _health.getHealthDataFromTypes(
        startOfDay,
        endOfDay,
        [HealthDataType.STEPS],
      );
      for (var d in stepsData) {
        steps += (d.value as NumericHealthValue).numericValue.toInt();
      }

      final distData = await _health.getHealthDataFromTypes(
        startOfDay,
        endOfDay,
        [HealthDataType.DISTANCE_DELTA],
      );
      for (var d in distData) {
        distance += (d.value as NumericHealthValue).numericValue.toDouble();
      }

      final calData = await _health.getHealthDataFromTypes(
        startOfDay,
        endOfDay,
        [HealthDataType.ACTIVE_ENERGY_BURNED],
      );
      for (var d in calData) {
        calories += (d.value as NumericHealthValue).numericValue.toDouble();
      }

      final sleepData = await _health.getHealthDataFromTypes(
        startOfDay.subtract(const Duration(hours: 12)),
        startOfDay.add(const Duration(hours: 12)),
        [HealthDataType.SLEEP_SESSION],
      );
      for (var d in sleepData) {
        // Sleep data might need more complex parsing but we'll take the duration between start and end
        sleep += d.dateTo.difference(d.dateFrom);
      }

      final rhrData = await _health.getHealthDataFromTypes(
        startOfDay,
        endOfDay,
        [HealthDataType.RESTING_HEART_RATE],
      );
      if (rhrData.isNotEmpty) {
        rhr = (rhrData.last.value as NumericHealthValue).numericValue.toInt();
      }
    } catch (e) {
      print('Error fetching daily health data: $e');
    }

    return DailyHealthSummary(
      steps: steps,
      distanceWalkedMeters: distance,
      activeCalories: calories,
      sleepDuration: sleep,
      restingHeartRate: rhr,
    );
  }

  Future<WeeklyTrend> getWeeklyTrend() async {
    if (!_isOptedIn) {
      return WeeklyTrend(
        dailySteps: List.filled(7, 0),
        dailyActiveCalories: List.filled(7, 0.0),
        sleepConsistency: 'Unknown',
        mostActiveDay: 'None',
      );
    }

    final end = DateTime.now();
    final start = end.subtract(const Duration(days: 7));
    
    List<int> dailySteps = List.filled(7, 0);
    List<double> dailyCalories = List.filled(7, 0.0);

    try {
      for (int i = 0; i < 7; i++) {
        final dStart = start.add(Duration(days: i));
        final summary = await getDailySummary(dStart);
        dailySteps[i] = summary.steps;
        dailyCalories[i] = summary.activeCalories;
      }
    } catch (e) {
      print('Error fetching weekly trend: $e');
    }

    int maxSteps = 0;
    int maxIdx = 0;
    for (int i = 0; i < 7; i++) {
      if (dailySteps[i] > maxSteps) {
        maxSteps = dailySteps[i];
        maxIdx = i;
      }
    }
    
    final mostActiveDate = start.add(Duration(days: maxIdx));
    final mostActiveDayName = DateFormat('EEEE').format(mostActiveDate);

    return WeeklyTrend(
      dailySteps: dailySteps,
      dailyActiveCalories: dailyCalories,
      sleepConsistency: 'Regular', // Simplified
      mostActiveDay: mostActiveDayName,
    );
  }

  Future<MonthlySummary> getMonthlySummary() async {
    if (!_isOptedIn) {
      return MonthlySummary(
        totalDistanceMeters: 0,
        avgDailySteps: 0,
        baselineSteps: 5000,
        sportEventsAttended: 0,
      );
    }

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    
    double totalDist = 0;
    int totalSteps = 0;
    int days = now.difference(startOfMonth).inDays + 1;

    try {
      for (int i = 0; i < days; i++) {
        final dStart = startOfMonth.add(Duration(days: i));
        final summary = await getDailySummary(dStart);
        totalDist += summary.distanceWalkedMeters;
        totalSteps += summary.steps;
      }
    } catch (e) {
      print('Error fetching monthly summary: $e');
    }

    return MonthlySummary(
      totalDistanceMeters: totalDist,
      avgDailySteps: days > 0 ? (totalSteps / days).round() : 0,
      baselineSteps: 6000, // Hardcoded baseline or from prefs
      sportEventsAttended: 2, // Would usually query the calendar events for Sport
    );
  }

  Future<void> saveSportRecapNote(String eventId, String note) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sport_recap_$eventId', note);
  }

  Future<String?> getSportRecapNote(String eventId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('sport_recap_$eventId');
  }
}
