import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:io' show Platform;

class AuthService {
  static final supabase = Supabase.instance.client;

  static String get backendUrl {
    const String envUrl = String.fromEnvironment('API_URL');
    if (envUrl.isNotEmpty) return envUrl;

    if (kIsWeb) return 'http://localhost:3000';
    if (Platform.isAndroid) return 'http://10.0.2.2:3000';
    return 'http://localhost:3000';
  }

  static Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'http://localhost:5000',
      );
      return;
    }

    const webClientId = '44674425993-r8bja4dgse0eeiig7ubk2fo49l4l39ac.apps.googleusercontent.com';
    const iosClientId = 'YOUR_GOOGLE_IOS_CLIENT_ID';
    const androidClientId = '44674425993-jl8luti0qu99eods92fg2u0p4l4u7f7q.apps.googleusercontent.com';

    String? getClientId() {
      switch (defaultTargetPlatform) {
        case TargetPlatform.iOS:
          return iosClientId;
        case TargetPlatform.android:
          return androidClientId;
        default:
          return webClientId;
      }
    }

    final GoogleSignIn googleSignIn = GoogleSignIn(
      clientId: getClientId(),
      serverClientId: webClientId,
    );
    
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) throw 'Login canceled';
    
    final googleAuth = await googleUser.authentication;
    final accessToken = googleAuth.accessToken;
    final idToken = googleAuth.idToken;

    if (accessToken == null) throw 'No Access Token found.';
    if (idToken == null) throw 'No ID Token found.';

    await supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
    
    await syncUserWithBackend();
  }

  static Future<void> syncUserWithBackend({String? username, String? avatarUrl, String? upiId, String? bio}) async {
    final session = supabase.auth.currentSession;
    if (session == null) throw 'Not logged in';

    String? fcmToken;
    try {
      // Request permission for iOS/Web and fetch token
      await FirebaseMessaging.instance.requestPermission().timeout(const Duration(seconds: 3));
      fcmToken = await FirebaseMessaging.instance.getToken().timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('Failed to get FCM token: $e');
    }

    final response = await http.post(
      Uri.parse('$backendUrl/users/sync'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.accessToken}',
      },
      body: jsonEncode({
        if (username != null) 'username': username,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        if (fcmToken != null) 'fcmToken': fcmToken,
        if (upiId != null) 'upiId': upiId,
        if (bio != null) 'bio': bio,
      }),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw 'Failed to sync user with backend: ${response.body}';
    }
  }

  static Future<void> signOut() async {
    await supabase.auth.signOut();
  }
}
