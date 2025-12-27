import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main_screen.dart'; // Yeni ana ekran yapısı
import 'login_page.dart';
import 'pages/onboarding.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

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
              // Check local prefs to decide whether to show onboarding.
              return FutureBuilder<SharedPreferences>(
                future: SharedPreferences.getInstance(),
                builder: (context, spSnap) {
                  if (spSnap.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator(color: Colors.amber)),
                    );
                  }
                  final prefs = spSnap.data;
                  final userId = user.uid;
                  final seenGlobal = prefs?.getBool('seen_onboarding') ?? false;
                  final seenPerUser = prefs?.getBool('seen_onboarding_uid_${userId}') ?? false;
                  final shouldShowOnboarding = !(seenGlobal || seenPerUser);
                  if (shouldShowOnboarding) {
                    return const OnboardingScreen();
                  }
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
