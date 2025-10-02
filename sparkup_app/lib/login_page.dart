// login_page.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'l10n/app_localizations.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  Future<void> signInWithGoogle(BuildContext context) async {
    try {
      if (kIsWeb) {
        GoogleAuthProvider authProvider = GoogleAuthProvider();
        await FirebaseAuth.instance.signInWithPopup(authProvider);
      } else {
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) return;
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);
      }
    } catch (e) {
      print('Google Sign-In hatası: $e');
      if (context.mounted) {
        _showErrorSnackBar(context, "Login Failed"); // Daha uygun bir hata metni
      }
    }
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.red.shade700, Colors.redAccent.shade400]),
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12.w),
              Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.grey.shade900, Colors.black], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 40.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                // ⚠️ DEĞİŞİKLİK: İkon Spark Up temasını yansıtmalı
                Icon(Icons.lightbulb_outline, size: 80.sp, color: Colors.amber.shade400, shadows: [
                  BoxShadow(color: Colors.amber.shade400.withOpacity(0.5), blurRadius: 18.0, spreadRadius: 2.0)
                ]),
                SizedBox(height: 16.h),
                // ⚠️ DEĞİŞİKLİK: Başlık appName olarak değiştirildi (Lokalizasyon dosyanızda düzenleyin)
                Text("Spark Up", textAlign: TextAlign.center, style: TextStyle(fontSize: 40.sp, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2)),
                SizedBox(height: 8.h),
                // ⚠️ DEĞİŞİKLİK: Slogan değiştirildi
                Text("Spark Your Mind", textAlign: TextAlign.center, style: TextStyle(fontSize: 16.sp, color: Colors.grey.shade400)),
                const Spacer(flex: 3),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Colors.amber, Colors.orangeAccent], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(16.r),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 8, offset: const Offset(0, 4))],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16.r),
                      onTap: () => signInWithGoogle(context),
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 24.w),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset('assets/images/google_logo.png', height: 24.h), // Logo dosyası proje kökünde olmalı
                            SizedBox(width: 12.w),
                            Text(localizations.continueWithGoogle, style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: Colors.black)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(flex: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}