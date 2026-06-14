import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../theme.dart';
import '../services/api_service.dart';
import 'hub_home_screen.dart';

class HubScreen extends StatefulWidget {
  const HubScreen({super.key});

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen> {
  String? _selectedHubId;
  String? _selectedHubName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppStateProvider>().fetchHubs();
    });
  }

  void _showCreateHubDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create Hub'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Hub Name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(context);
                  await ApiService.createHub(name);
                  if (mounted) {
                    context.read<AppStateProvider>().fetchHubs(forceRefresh: true);
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final hubs = appState.hubs;
    final isLoading = appState.isLoadingHubs;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth > 600;

        Widget hubListContent = isLoading
            ? Shimmer.fromColors(
                baseColor: Colors.grey[900]!,
                highlightColor: Colors.grey[800]!,
                child: ListView.separated(
                  padding: const EdgeInsets.all(24.0),
                  itemCount: 5,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) => Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              )
            : hubs.isEmpty
                ? const Center(child: Text('No hubs yet. Create one!'))
                : ListView.separated(
                    padding: const EdgeInsets.all(24.0),
                    itemCount: hubs.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final hub = hubs[index];
                      return GestureDetector(
                        onTap: () {
                          if (isTablet) {
                            setState(() {
                              _selectedHubId = hub['id'];
                              _selectedHubName = hub['name'];
                            });
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => HubHomeScreen(
                                  hubId: hub['id'],
                                  hubName: hub['name'] ?? 'Hub',
                                ),
                              ),
                            ).then((shouldRefresh) {
                              if (shouldRefresh == true) {
                                context.read<AppStateProvider>().fetchHubs(forceRefresh: true);
                              }
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: _selectedHubId == hub['id'] && isTablet
                                ? ClosioTheme.primaryColor.withOpacity(0.1)
                                : ClosioTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: _selectedHubId == hub['id'] && isTablet
                                    ? ClosioTheme.primaryColor
                                    : ClosioTheme.surfaceContainer,
                                width: 1),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: ClosioTheme.surfaceContainerLow,
                                radius: 24,
                                child: Text(
                                  (hub['name'] as String?)?.substring(0, 1).toUpperCase() ?? 'H',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      hub['name'] ?? 'Unknown Hub',
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Tap to view chat, calendar, and splits.',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: ClosioTheme.secondaryColor,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );

        Widget scaffold = Scaffold(
          backgroundColor: ClosioTheme.backgroundColor,
          appBar: AppBar(
            backgroundColor: ClosioTheme.backgroundColor,
            elevation: 0,
            title: Text(
              'Hubs',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),

          ),
          floatingActionButton: Padding(
            padding: const EdgeInsets.only(bottom: 90.0),
            child: FloatingActionButton(
              onPressed: _showCreateHubDialog,
              backgroundColor: ClosioTheme.primaryColor,
              child: const Icon(Icons.add, color: ClosioTheme.onPrimaryColor),
            ),
          ),
          body: isTablet
              ? Row(
                  children: [
                    SizedBox(
                      width: 350,
                      child: hubListContent,
                    ),
                    const VerticalDivider(width: 1, color: Colors.grey),
                    Expanded(
                      child: _selectedHubId != null
                          ? HubHomeScreen(
                              key: ValueKey(_selectedHubId), // Force rebuild on change
                              hubId: _selectedHubId!,
                              hubName: _selectedHubName ?? 'Hub',
                            )
                          : const Center(
                              child: Text('Select a hub to view details'),
                            ),
                    ),
                  ],
                )
              : hubListContent,
        );

        return scaffold;
      },
    );
  }
}
