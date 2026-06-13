import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../theme.dart';
import '../services/api_service.dart';
import 'event_creation_screen.dart';
import 'event_detail_screen.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';

class HubCalendarTab extends StatefulWidget {
  final String hubId;
  final String hubName;

  const HubCalendarTab({super.key, required this.hubId, required this.hubName});

  @override
  State<HubCalendarTab> createState() => _HubCalendarTabState();
}

class _HubCalendarTabState extends State<HubCalendarTab> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppStateProvider>().fetchEvents(widget.hubId);
    });
  }

  List<dynamic> _getEventsForDay(DateTime day, List<dynamic> hubEvents) {
    final dateStr = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    return hubEvents.where((e) => e['date'] == dateStr).toList();
  }

  List<dynamic> _getUpcomingEvents(List<dynamic> hubEvents) {
    final todayStr = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
    final upcoming = hubEvents.where((e) => (e['date'] as String).compareTo(todayStr) >= 0).toList();
    upcoming.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    return upcoming.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final hubEvents = appState.getEvents(widget.hubId);
    final isLoading = appState.isLoadingEvents(widget.hubId);
    
    final upcomingEvents = _getUpcomingEvents(hubEvents);

    return Scaffold(
      backgroundColor: ClosioTheme.backgroundColor,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EventCreationScreen(
                selectedDate: _selectedDay ?? DateTime.now(),
                hubId: widget.hubId,
              ),
            ),
          ).then((_) {
            if (context.mounted) {
              context.read<AppStateProvider>().fetchEvents(widget.hubId, forceRefresh: true);
            }
          });
        },
        backgroundColor: ClosioTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final isTablet = constraints.maxWidth > 600;

                final calendarWidget = TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  eventLoader: (day) => _getEventsForDay(day, hubEvents),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  calendarFormat: isTablet ? CalendarFormat.month : CalendarFormat.month,
                  calendarStyle: const CalendarStyle(
                    selectedDecoration: BoxDecoration(
                      color: ClosioTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    todayDecoration: BoxDecoration(
                      color: ClosioTheme.secondaryColor,
                      shape: BoxShape.circle,
                    ),
                    markerDecoration: BoxDecoration(
                      color: ClosioTheme.errorColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                );

                final upcomingListWidget = Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Coming up',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: upcomingEvents.isEmpty
                          ? const Center(child: Text('No upcoming events for this Hub.'))
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                              itemCount: upcomingEvents.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 16),
                              itemBuilder: (context, index) {
                                final event = upcomingEvents[index];
                                final dateParts = (event['date'] as String).split('-'); // YYYY-MM-DD
                                final month = _getMonthName(int.parse(dateParts[1]));
                                final day = dateParts[2];

                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => EventDetailScreen(event: event),
                                      ),
                                    ).then((_) {
                                      if (context.mounted) {
                                        context.read<AppStateProvider>().fetchEvents(widget.hubId, forceRefresh: true);
                                      }
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(16.0),
                                    decoration: BoxDecoration(
                                      color: ClosioTheme.surfaceColor,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: ClosioTheme.surfaceContainer),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Column(
                                          children: [
                                            Text(
                                              month,
                                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                                    color: ClosioTheme.secondaryColor,
                                                  ),
                                            ),
                                            Text(
                                              day,
                                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 24),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                event['title'] ?? 'Event',
                                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${event['time'] ?? 'All Day'} • ${event['hub']?['name'] ?? widget.hubName}',
                                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                      color: ClosioTheme.secondaryColor,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );

                if (isTablet) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: calendarWidget,
                          ),
                        ),
                      ),
                      const VerticalDivider(width: 1, color: ClosioTheme.surfaceContainer),
                      Expanded(
                        flex: 2,
                        child: upcomingListWidget,
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      calendarWidget,
                      const Divider(height: 1, color: ClosioTheme.surfaceContainer),
                      Expanded(child: upcomingListWidget),
                    ],
                  );
                }
              },
            ),
    );
  }

  String _getMonthName(int month) {
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return months[month - 1];
  }
}
