import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../theme.dart';
import '../services/api_service.dart';

class HubSettingsScreen extends StatefulWidget {
  final String hubId;
  final String hubName;
  
  const HubSettingsScreen({
    super.key,
    required this.hubId,
    required this.hubName,
  });

  @override
  State<HubSettingsScreen> createState() => _HubSettingsScreenState();
}

class _HubSettingsScreenState extends State<HubSettingsScreen> {
  List<dynamic> _members = [];
  Map<String, String> _memberGamingStatus = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    try {
      final members = await ApiService.getHubMembers(widget.hubId);
      setState(() {
        _members = members;
        _isLoading = false;
      });
      // Fetch gaming status independently for each member
      for (var m in members) {
        final uid = m['id'];
        if (uid != null) {
          ApiService.get('/gaming/status/$uid').then((res) {
            if (res['presence'] != null && mounted) {
              setState(() {
                _memberGamingStatus[uid] = res['presence'];
              });
            }
          }).catchError((_) {});
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching members: $e')),
        );
      }
    }
  }

  Future<void> _leaveHub() async {
    try {
      await ApiService.leaveHub(widget.hubId);
      if (mounted) {
        // Pop Settings Screen
        Navigator.pop(context);
        // Pop Chat Screen to return to Hub list
        Navigator.pop(context, true); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error leaving hub: $e')),
        );
      }
    }
  }



  Future<void> _shareInviteLink() async {
    setState(() => _isLoading = true);
    try {
      final code = await ApiService.getHubInviteCode(widget.hubId);
      setState(() => _isLoading = false);
      final link = 'closio://hub/invite/$code';
      if (mounted) {
        Share.share('Join my hub on Closio: $link');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error getting invite link: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClosioTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: ClosioTheme.backgroundColor,
        elevation: 0,
        title: const Text('Hub Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: ClosioTheme.primaryColor),
            onPressed: _shareInviteLink,
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: ClosioTheme.surfaceContainerLow,
                  child: Text(
                    widget.hubName.isNotEmpty ? widget.hubName.substring(0, 1).toUpperCase() : 'H',
                    style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: ClosioTheme.onSurfaceColor),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  widget.hubName,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 32),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Members',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: ClosioTheme.surfaceContainer),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _members.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, color: ClosioTheme.surfaceContainer),
                    itemBuilder: (context, index) {
                      final member = _members[index];
                      final role = member['role'] ?? 'Member';
                      final uid = member['id'];
                      final presence = _memberGamingStatus[uid];
                      
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: ClosioTheme.surfaceContainer,
                          backgroundImage: member['avatarUrl'] != null ? NetworkImage(member['avatarUrl']) : null,
                          child: member['avatarUrl'] == null ? const Icon(Icons.person, color: ClosioTheme.secondaryColor) : null,
                        ),
                        title: Text(member['username'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: presence != null && presence.isNotEmpty
                            ? Row(
                                children: [
                                  Container(
                                    width: 8, height: 8,
                                    decoration: BoxDecoration(
                                      color: presence.contains('Online') || presence.contains('Playing') ? Colors.green : Colors.grey,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(presence, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                              )
                            : null,
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: role == 'Admin' ? ClosioTheme.primaryColor.withOpacity(0.1) : ClosioTheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(role, style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: role == 'Admin' ? ClosioTheme.primaryColor : ClosioTheme.secondaryColor,
                          )),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Leave Hub?'),
                          content: const Text('Are you sure you want to leave this hub?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _leaveHub();
                              },
                              child: const Text('Leave', style: TextStyle(color: ClosioTheme.errorColor)),
                            ),
                          ],
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ClosioTheme.errorColor,
                      side: const BorderSide(color: ClosioTheme.errorColor),
                    ),
                    child: const Text('Leave Hub'),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
