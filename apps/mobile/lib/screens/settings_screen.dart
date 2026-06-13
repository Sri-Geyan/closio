import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/auth_service.dart';
import 'onboarding_screen.dart';
import 'gaming_accounts_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotifications = true;
  bool _emailNotifications = false;
  bool _vanishModeDefault = false;

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Log out?'),
          content: const Text('Are you sure you want to log out?'),
          actions: [
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClosioTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: ClosioTheme.backgroundColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
            child: Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          SwitchListTile(
            title: const Text('Push Notifications'),
            subtitle: const Text('Get notified when people message you'),
            value: _pushNotifications,
            onChanged: (val) => setState(() => _pushNotifications = val),
            activeColor: ClosioTheme.primaryColor,
          ),
          SwitchListTile(
            title: const Text('Email Notifications'),
            subtitle: const Text('Receive event reminders and recaps via email'),
            value: _emailNotifications,
            onChanged: (val) => setState(() => _emailNotifications = val),
            activeColor: ClosioTheme.primaryColor,
          ),
          const Divider(height: 32),
          
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
            child: Text('Privacy & Security', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          SwitchListTile(
            title: const Text('Vanish Mode by Default'),
            subtitle: const Text('Start all new chats with vanish mode enabled'),
            value: _vanishModeDefault,
            onChanged: (val) => setState(() => _vanishModeDefault = val),
            activeColor: ClosioTheme.primaryColor,
          ),

          
          const Divider(height: 32),
          
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
            child: Text('Integrations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          ListTile(
            title: const Text('Gaming Profile & Privacy'),
            leading: const Icon(Icons.videogame_asset),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GamingAccountsScreen()),
              );
            },
          ),
          
          const Divider(height: 32),
          
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
            child: Text('Account Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          ListTile(
            title: const Text('Log Out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            leading: const Icon(Icons.logout, color: Colors.red),
            onTap: _showLogoutDialog,
          ),
        ],
      ),
    );
  }
}
