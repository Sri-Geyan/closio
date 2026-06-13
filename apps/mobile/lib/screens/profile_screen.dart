import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../theme.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import 'onboarding_screen.dart';
import 'split_dashboard_screen.dart';
import 'account_details_screen.dart';
import 'settings_screen.dart';
import 'health/health_dashboard_screen.dart';
import 'components/glass_container.dart';
import '../components/gaming_stats_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _username = '';
  String _email = '';
  String? _avatarUrl;
  int _hubCount = 0;
  int _eventsAttended = 0;
  Map<String, dynamic>? _gamingStats;
  String? _gamingPresence;
  String? _userId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final user = await ApiService.getUserProfile();
      final supabaseUser = AuthService.supabase.auth.currentUser;
      
      final hubs = await ApiService.getHubs();
      final events = await ApiService.getAllEvents();
      
      int attended = 0;
      for (var event in events) {
        final attendances = event['attendances'] as List<dynamic>? ?? [];
        for (var att in attendances) {
          if (att['userId'] == user['id'] && att['status'] == 'Going') {
            attended++;
            break;
          }
        }
      }

      setState(() {
        _username = user['username'] ?? 'User';
        _avatarUrl = user['avatarUrl'];
        _email = supabaseUser?.email ?? '';
        _userId = user['id'];
        _hubCount = hubs.length;
        _eventsAttended = attended;
      });
      
      // Fetch gaming status independently
      try {
        final gamingData = await ApiService.get('/gaming/status/$_userId');
        setState(() {
          _gamingStats = gamingData['stats'];
          _gamingPresence = gamingData['presence'];
        });
      } catch (e) {
        // Ignore gaming error
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _showLogoutDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Material(
              color: Colors.transparent,
              child: GlassContainer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Log out?', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 16),
                    Text('Are you sure you want to log out?', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                          onPressed: () async {
                            await AuthService.signOut();
                            if (context.mounted) {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (context) => const OnboardingScreen()),
                                (route) => false,
                              );
                            }
                          },
                          child: const Text('Log Out'),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Profile',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
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
                  top: -50,
                  left: -100,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                      gradient: RadialGradient(
                        colors: [
                          Theme.of(context).colorScheme.secondary.withOpacity(0.2),
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
                        // User Profile Tile
                        StaggeredGridTile.count(
                          crossAxisCellCount: 4,
                          mainAxisCellCount: 2,
                          child: GlassContainer(
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 40,
                                  backgroundColor: Theme.of(context).colorScheme.surface,
                                  backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                                  child: _avatarUrl == null ? Icon(Icons.person, size: 40, color: Theme.of(context).colorScheme.secondary) : null,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _username,
                                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        _email,
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.secondary),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        if (_gamingStats != null || _gamingPresence != null)
                          StaggeredGridTile.count(
                            crossAxisCellCount: 4,
                            mainAxisCellCount: _gamingStats != null && _gamingStats!.isNotEmpty ? 2 : 1,
                            child: GamingStatsCard(
                              stats: _gamingStats,
                              presence: _gamingPresence,
                            ),
                          ),

                        // Stats Tiles
                        StaggeredGridTile.count(
                          crossAxisCellCount: 2,
                          mainAxisCellCount: 1.5,
                          child: GlassContainer(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _hubCount.toString(),
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                                ),
                                const SizedBox(height: 4),
                                Text('Hubs', style: Theme.of(context).textTheme.labelMedium),
                              ],
                            ),
                          ),
                        ),

                        StaggeredGridTile.count(
                          crossAxisCellCount: 2,
                          mainAxisCellCount: 1.5,
                          child: GlassContainer(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _eventsAttended.toString(),
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                                ),
                                const SizedBox(height: 4),
                                Text('Attended', style: Theme.of(context).textTheme.labelMedium),
                              ],
                            ),
                          ),
                        ),

                        // Action Tiles
                        StaggeredGridTile.count(
                          crossAxisCellCount: 4,
                          mainAxisCellCount: 1,
                          child: GlassContainer(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const HealthDashboardScreen()),
                              );
                            },
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                const Icon(Icons.favorite, color: Colors.pink),
                                const SizedBox(width: 16),
                                Expanded(child: Text('Health Snapshot', style: Theme.of(context).textTheme.titleMedium)),
                                const Icon(Icons.chevron_right, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),

                        StaggeredGridTile.count(
                          crossAxisCellCount: 4,
                          mainAxisCellCount: 1,
                          child: GlassContainer(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const SplitDashboardScreen()),
                              );
                            },
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                const Icon(Icons.receipt_long),
                                const SizedBox(width: 16),
                                Expanded(child: Text('My Pending Splits', style: Theme.of(context).textTheme.titleMedium)),
                                const Icon(Icons.chevron_right, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),

                        StaggeredGridTile.count(
                          crossAxisCellCount: 4,
                          mainAxisCellCount: 1,
                          child: GlassContainer(
                            onTap: () async {
                              final didUpdate = await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const AccountDetailsScreen()),
                              );
                              if (didUpdate == true) {
                                _fetchProfile();
                              }
                            },
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                const Icon(Icons.person_outline),
                                const SizedBox(width: 16),
                                Expanded(child: Text('Account Details', style: Theme.of(context).textTheme.titleMedium)),
                                const Icon(Icons.chevron_right, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),



                        StaggeredGridTile.count(
                          crossAxisCellCount: 4,
                          mainAxisCellCount: 1,
                          child: GlassContainer(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const SettingsScreen()),
                              );
                            },
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                const Icon(Icons.privacy_tip_outlined),
                                const SizedBox(width: 16),
                                Expanded(child: Text('Privacy & Security', style: Theme.of(context).textTheme.titleMedium)),
                                const Icon(Icons.chevron_right, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),

                        // Logout Tile
                        StaggeredGridTile.count(
                          crossAxisCellCount: 4,
                          mainAxisCellCount: 1,
                          child: GlassContainer(
                            onTap: _showLogoutDialog,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
                                const SizedBox(width: 8),
                                Text(
                                  'Log Out',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.error,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
