import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GamingAccountsScreen extends StatefulWidget {
  const GamingAccountsScreen({super.key});

  @override
  State<GamingAccountsScreen> createState() => _GamingAccountsScreenState();
}

class _GamingAccountsScreenState extends State<GamingAccountsScreen> {
  final Map<String, String?> _accounts = {
    'discord': null,
  };
  bool _isLoading = true;
  String _privacy = 'ALL';
  bool _appearOffline = false;

  @override
  void initState() {
    super.initState();
    _fetchUserAccounts();
  }

  Future<void> _fetchUserAccounts() async {
    try {
      final user = await ApiService.getUserProfile();
      if (user != null) {
        setState(() {
          _accounts['discord'] = user['gamingDiscord'];
          _privacy = user['gamingPrivacy'] ?? 'ALL';
          _appearOffline = user['gamingAppearOffline'] ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _connectPlatform(String platform) async {
    if (platform == 'discord') {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final url = Uri.parse('${ApiService.backendUrl}/gaming/discord/auth?userId=$userId');
      try {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open Discord')));
        }
      }
      // Provide a dialog telling them to refresh after authorizing
      // Removed as per user request
      return;
    }

    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Connect ${platform.toUpperCase()}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your gamertag, username, or ID to link this account.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Gamertag'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Connect'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        await ApiService.post('/gaming/connect/$platform', body: {'username': result});
        await _fetchUserAccounts();
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _updatePrivacy() async {
    setState(() => _isLoading = true);
    try {
      await ApiService.put('/gaming/privacy', body: {
        'gamingPrivacy': _privacy,
        'gamingAppearOffline': _appearOffline,
      });
    } catch (e) {
      //
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gaming Profile')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Linked Accounts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 8),
                const Text('Connect your platforms to enable rich presence and stats across your hubs.'),
                const SizedBox(height: 16),
                ..._accounts.entries.map((e) {
                  final platform = e.key;
                  final username = e.value;
                  final isConnected = username != null;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: isConnected ? ClosioTheme.primaryColor : Colors.grey.shade800,
                      child: Icon(Icons.videogame_asset, color: Colors.white),
                    ),
                    title: Text(platform.toUpperCase()),
                    subtitle: Text(isConnected ? username : 'Not connected'),
                    trailing: TextButton(
                      onPressed: () => _connectPlatform(platform),
                      child: Text(isConnected ? 'Update' : 'Connect'),
                    ),
                  );
                }).toList(),
                const Divider(height: 32),
                const Text('Privacy Controls', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Appear Offline'),
                  subtitle: const Text('Hide your gaming status globally'),
                  value: _appearOffline,
                  onChanged: (val) {
                    setState(() => _appearOffline = val);
                    _updatePrivacy();
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Visibility'),
                  subtitle: const Text('Who can see your gaming activity'),
                  trailing: DropdownButton<String>(
                    value: _privacy,
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All Hubs')),
                      DropdownMenuItem(value: 'HUBS', child: Text('Selected Hubs')),
                      DropdownMenuItem(value: 'NOBODY', child: Text('Nobody')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _privacy = val);
                        _updatePrivacy();
                      }
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
