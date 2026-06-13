import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'theme.dart';
import 'screens/onboarding_screen.dart';
import 'screens/username_screen.dart';
import 'screens/main_layout.dart';
import 'services/api_service.dart';
import 'providers/app_state_provider.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://piwfnmahuwwpabccfshb.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBpd2ZubWFodXd3cGFiY2Nmc2hiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODExNDc5MDYsImV4cCI6MjA5NjcyMzkwNn0.s6ear1wG1YvM2ca1kRdl1GK4TGXRVj2RWoZj_FidQIc',
  );
  
  await Firebase.initializeApp();
  
  runApp(const ClosioApp());
}

class ClosioApp extends StatelessWidget {
  const ClosioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppStateProvider()),
      ],
      child: MaterialApp(
        title: 'Closio Minimal Social Hub',
        theme: ClosioTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final session = snapshot.data?.session;
        if (session != null) {
          return FutureBuilder<dynamic>(
            future: _checkProfile(),
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final user = profileSnapshot.data;
              if (user != null && user['username'] != null && user['username'].toString().isNotEmpty) {
                return const MainLayout();
              }
              return const UsernameScreen();
            },
          );
        }
        return const OnboardingScreen();
      },
    );
  }

  Future<dynamic> _checkProfile() async {
    try {
      return await ApiService.getUserProfile();
    } catch (e) {
      return null;
    }
  }
}
