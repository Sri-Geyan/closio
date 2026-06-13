import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:table_calendar/table_calendar.dart';
import '../theme.dart';
import '../services/api_service.dart';
import 'event_creation_screen.dart';
import 'event_detail_screen.dart';
import 'components/glass_container.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<dynamic> _allEvents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    try {
      final events = await ApiService.getAllEvents();
      setState(() {
        _allEvents = events;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<dynamic> _getUpcomingEvents() {
    final todayStr = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
    final upcoming = _allEvents.where((e) => (e['date'] as String).compareTo(todayStr) >= 0).toList();
    upcoming.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    return upcoming;
  }

  void _showEventDetailsOverlay(dynamic event) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) {
        return SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Material(
                color: Colors.transparent,
                child: GlassContainer(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              event['title'] ?? 'Event',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(context).pop(),
                          )
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text('Date: ${event['date']}', style: Theme.of(context).textTheme.bodyLarge),
                      Text('Time: ${event['time']}', style: Theme.of(context).textTheme.bodyLarge),
                      Text('Location: ${event['hub']?['name'] ?? 'Unknown'}', style: Theme.of(context).textTheme.bodyLarge),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => EventDetailScreen(event: event)),
                            ).then((_) => _fetchEvents());
                          },
                          child: const Text('View Full Details'),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
            )),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final upcomingEvents = _getUpcomingEvents();
    final nextEvent = upcomingEvents.isNotEmpty ? upcomingEvents.first : null;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Private Network',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EventCreationScreen(selectedDate: _selectedDay ?? DateTime.now()),
                ),
              ).then((_) => _fetchEvents());
            },
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Stack(
            children: [
              // Abstract background to show off glassmorphism
              Positioned(
                top: -100,
                right: -100,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    gradient: RadialGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary.withOpacity(0.2),
                        Colors.transparent,
                      ]
                    )
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 120),
                  child: StaggeredGrid.count(
                    crossAxisCount: 4,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    children: [
                      // Large Calendar Tile
                      StaggeredGridTile.count(
                        crossAxisCellCount: 4,
                        mainAxisCellCount: 2.5,
                        child: GlassContainer(
                          padding: const EdgeInsets.all(8),
                          child: TableCalendar(
                            firstDay: DateTime.utc(2020, 1, 1),
                            lastDay: DateTime.utc(2030, 12, 31),
                            focusedDay: _focusedDay,
                            calendarFormat: CalendarFormat.week,
                            headerStyle: const HeaderStyle(formatButtonVisible: false),
                            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                            onDaySelected: (selectedDay, focusedDay) {
                              setState(() {
                                _selectedDay = selectedDay;
                                _focusedDay = focusedDay;
                              });
                            },
                          ),
                        ),
                      ),
                      
                      // Next Event Tile
                      if (nextEvent != null)
                        StaggeredGridTile.count(
                          crossAxisCellCount: 2,
                          mainAxisCellCount: 2,
                          child: GlassContainer(
                            onTap: () => _showEventDetailsOverlay(nextEvent),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.event),
                                const Spacer(),
                                Text('Next Event', style: Theme.of(context).textTheme.labelSmall),
                                const SizedBox(height: 4),
                                Text(
                                  nextEvent['title'] ?? 'Event',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(nextEvent['time'] ?? '', style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                          ),
                        ),

                      // Rest of upcoming events
                      ...upcomingEvents.skip(1).take(4).map((event) => StaggeredGridTile.count(
                        crossAxisCellCount: 4,
                        mainAxisCellCount: 1,
                        child: GlassContainer(
                          onTap: () => _showEventDetailsOverlay(event),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  event['date'].toString().split('-').last,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(event['title'] ?? '', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                    Text(event['time'] ?? '', style: Theme.of(context).textTheme.bodySmall),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: Colors.grey),
                            ],
                          ),
                        ),
                      )),
                    ],
                  ),
                ),
              ),
            ],
          ),
    );
  }
}
