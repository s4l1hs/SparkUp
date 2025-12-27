import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/api_service.dart';
import 'main_screen.dart'; // Yeni ana ekran yapısı
import 'login_page.dart';
import 'pages/onboarding.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<bool> _shouldShowOnboarding(String token, String uid) async {
    // Prefer local preference first for fast response, then fall back to server check.
    try {
      final prefs = await SharedPreferences.getInstance();
      final seenGlobal = prefs.getBool('seen_onboarding') ?? false;
      final seenPerUser = prefs.getBool('seen_onboarding_uid_${uid}') ?? false;
      if (seenGlobal || seenPerUser) return false;
      // If not marked locally, ask backend for authoritative status.
      final seenServer = await ApiService().getOnboardingStatus(token);
      return !seenServer;
    } catch (_) {
      // On any error, fall back to local-only decision (show only if not seen locally)
      final prefs = await SharedPreferences.getInstance();
      final seenGlobal = prefs.getBool('seen_onboarding') ?? false;
      final seenPerUser = prefs.getBool('seen_onboarding_uid_${uid}') ?? false;
      return !(seenGlobal || seenPerUser);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Kullanıcının oturum durumunu dinle
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Bağlantı bekleniyor
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Colors.amber)),
          );
        }

        // Kullanıcı giriş yapmamışsa
        if (!snapshot.hasData) {
          return const LoginPage();
        }

        // 2. Kullanıcı giriş yapmışsa (snapshot.data bir User objesidir)
        final user = snapshot.data!;

        // 3. Backend için gerekli olan ID Token'ı asenkron olarak al
        return FutureBuilder<String?>(
          future: user.getIdToken(), // Firebase'den geçerli token'ı al
          builder: (context, tokenSnapshot) {
            // Token bekleniyor
            if (tokenSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                  body: Center(
                      child: CircularProgressIndicator(color: Colors.amber)));
            }

            final token = tokenSnapshot.data; // Yeni değişken adı: 'token'

            // Token başarılı bir şekilde alınmışsa
            if (token != null) {
              return FutureBuilder<bool>(
                future: _shouldShowOnboarding(token, user.uid),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator(color: Colors.amber)),
                    );
                  }
                  final shouldShow = snap.data ?? false;
                  if (shouldShow) return const OnboardingScreen();
                  return MainScreen(idToken: token);
                },
              );
            }

            // Token alınamazsa (çok nadir, ağ sorunu vb.) Login'e dön
            return const LoginPage();
          },
        );
      },
    );
  }
}
