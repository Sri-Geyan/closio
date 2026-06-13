import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/auth_service.dart';
import 'main_layout.dart';
import 'username_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClosioTheme.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              Text(
                'Closio',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: ClosioTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'A calmer way to stay close.',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: ClosioTheme.secondaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      await AuthService.signInWithGoogle();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                    }
                  },
                  icon: const Icon(Icons.g_mobiledata, size: 32),
                  label: const Text('Continue with Google'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
