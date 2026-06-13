import 'package:flutter/material.dart';
import '../theme.dart';
import 'chat_screen.dart';
import 'hub_settings_screen.dart';
import 'hub_calendar_tab.dart';
import 'hub_splits_tab.dart';
import 'jukebox_screen.dart';
import 'zomato_auth_screen.dart';

class HubHomeScreen extends StatefulWidget {
  final String hubId;
  final String hubName;

  const HubHomeScreen({super.key, required this.hubId, required this.hubName});

  @override
  State<HubHomeScreen> createState() => _HubHomeScreenState();
}

class _HubHomeScreenState extends State<HubHomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClosioTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: ClosioTheme.backgroundColor,
        elevation: 0,
        title: Text(widget.hubName, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.music_note_rounded), 
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => JukeboxScreen(
                    hubId: widget.hubId,
                    hubName: widget.hubName,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.fastfood_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ZomatoAuthScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline), 
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HubSettingsScreen(
                    hubId: widget.hubId,
                    hubName: widget.hubName,
                  ),
                ),
              ).then((leftHub) {
                if (leftHub == true && context.mounted) {
                  Navigator.pop(context, true); // Pop back to main Hub list to refresh
                }
              });
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: ClosioTheme.primaryColor,
          unselectedLabelColor: ClosioTheme.outlineColor,
          indicatorColor: ClosioTheme.primaryColor,
          tabs: const [
            Tab(text: 'Chat', icon: Icon(Icons.chat_bubble_outline)),
            Tab(text: 'Calendar', icon: Icon(Icons.calendar_today_outlined)),
            Tab(text: 'Splits', icon: Icon(Icons.receipt_long)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Chat Tab
          ChatScreen(hubId: widget.hubId, hubName: widget.hubName, isEmbedded: true),
          // Calendar Tab (Filtered)
          HubCalendarTab(hubId: widget.hubId, hubName: widget.hubName),
          // Splits Tab
          HubSplitsTab(hubId: widget.hubId, hubName: widget.hubName),
        ],
      ),
    );
  }
}
