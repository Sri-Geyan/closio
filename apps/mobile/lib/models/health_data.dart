class DailyHealthSummary {
  final int steps;
  final double distanceWalkedMeters;
  final double activeCalories;
  final Duration sleepDuration;
  final int restingHeartRate;

  DailyHealthSummary({
    required this.steps,
    required this.distanceWalkedMeters,
    required this.activeCalories,
    required this.sleepDuration,
    required this.restingHeartRate,
  });
}

class WeeklyTrend {
  final List<int> dailySteps;
  final List<double> dailyActiveCalories;
  final String sleepConsistency;
  final String mostActiveDay;

  WeeklyTrend({
    required this.dailySteps,
    required this.dailyActiveCalories,
    required this.sleepConsistency,
    required this.mostActiveDay,
  });
}

class MonthlySummary {
  final double totalDistanceMeters;
  final int avgDailySteps;
  final int baselineSteps;
  final int sportEventsAttended;

  MonthlySummary({
    required this.totalDistanceMeters,
    required this.avgDailySteps,
    required this.baselineSteps,
    required this.sportEventsAttended,
  });
}

class SportEventRecap {
  final String eventId;
  final int steps;
  final double distanceMeters;
  final double activeCalories;
  final String? personalNote;

  SportEventRecap({
    required this.eventId,
    required this.steps,
    required this.distanceMeters,
    required this.activeCalories,
    this.personalNote,
  });
}
