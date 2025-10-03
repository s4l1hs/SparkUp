import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'l10n/app_localizations.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  // --- Animasyon Controller'ları ---
  late final AnimationController _entryController; // Elementlerin giriş animasyonu için
  late final AnimationController _backgroundController; // Arka plan ışıltılarının hareketi için
  late final AnimationController _breathingController; // İkonun nefes alma efekti için
  late final AnimationController _gradientController; // Butonun gradyan animasyonu için

  // --- Animasyon Değerleri ---
  late final Animation<double> _iconFadeAnimation;
  late final Animation<double> _iconScaleAnimation;
  late final Animation<Offset> _textSlideAnimation;
  late final Animation<double> _textFadeAnimation;
  late final Animation<Offset> _buttonSlideAnimation;
  late final Animation<Alignment> _backgroundAnimation1;
  late final Animation<Alignment> _backgroundAnimation2;
  late final Animation<double> _breathingAnimation;

  bool _isButtonPressed = false;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _backgroundController = AnimationController(vsync: this, duration: const Duration(seconds: 30))..repeat();
    _breathingController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    _gradientController = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();

    // Kademeli giriş animasyonları
    _iconFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _entryController, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)));
    _iconScaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _entryController, curve: const Interval(0.0, 0.5, curve: Curves.elasticOut)));
    _textFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _entryController, curve: const Interval(0.3, 0.8, curve: Curves.easeOut)));
    _textSlideAnimation = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(CurvedAnimation(parent: _entryController, curve: const Interval(0.3, 0.8, curve: Curves.easeOut)));
    _buttonSlideAnimation = Tween<Offset>(begin: const Offset(0, 2), end: Offset.zero).animate(CurvedAnimation(parent: _entryController, curve: const Interval(0.7, 1.0, curve: Curves.easeOut)));

    // Arka plan ışıltılarının gezinme animasyonları (farklı yönlerde)
    _backgroundAnimation1 = TweenSequence<Alignment>([
      TweenSequenceItem(tween: AlignmentTween(begin: Alignment.topLeft, end: Alignment.bottomRight), weight: 1),
      TweenSequenceItem(tween: AlignmentTween(begin: Alignment.bottomRight, end: Alignment.topLeft), weight: 1),
    ]).animate(_backgroundController);

    _backgroundAnimation2 = TweenSequence<Alignment>([
      TweenSequenceItem(tween: AlignmentTween(begin: Alignment.topRight, end: Alignment.bottomLeft), weight: 1),
      TweenSequenceItem(tween: AlignmentTween(begin: Alignment.bottomLeft, end: Alignment.topRight), weight: 1),
    ]).animate(_backgroundController);
    
    // İkonun nefes alma animasyonu
    _breathingAnimation = Tween<double>(begin: 0.98, end: 1.02).animate(CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut));

    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _backgroundController.dispose();
    _breathingController.dispose();
    _gradientController.dispose();
    super.dispose();
  }

  // Google Sign-In fonksiyonları aynı kalıyor
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
        _showErrorSnackBar(context, "Login Failed"); 
      }
    }
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), backgroundColor: Colors.transparent, elevation: 0, content: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(color: Theme.of(context).colorScheme.error, borderRadius: BorderRadius.circular(16.r)), child: Row(children: [const Icon(Icons.error_outline, color: Colors.white), SizedBox(width: 12.w), Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))]))));
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          // 1. Arka Plan
          Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1A1A1A), Colors.black], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
          
          // 2. Hareketli Işıltı Katmanları
          AnimatedBuilder(
            animation: _backgroundController,
            builder: (context, child) {
              return Stack(
                children: [
                  // Işıltı 1 (Tertiary Renk)
                  Positioned.fill(
                    child: Align(
                      alignment: _backgroundAnimation1.value,
                      child: Container(width: 400.w, height: 400.h, decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.tertiary.withOpacity(0.15), boxShadow: [BoxShadow(color: theme.colorScheme.tertiary.withOpacity(0.1), blurRadius: 100.r, spreadRadius: 80.r)])),
                    ),
                  ),
                  // Işıltı 2 (Primary Renk)
                  Positioned.fill(
                     child: Align(
                      alignment: _backgroundAnimation2.value,
                      child: Container(width: 300.w, height: 300.h, decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.primary.withOpacity(0.15), boxShadow: [BoxShadow(color: theme.colorScheme.primary.withOpacity(0.1), blurRadius: 100.r, spreadRadius: 60.r)])),
                    ),
                  ),
                ],
              );
            },
          ),
          
          // 3. İçerik Katmanı
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 40.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  // "Nefes Alan" ve Kademeli Gelen İkon
                  FadeTransition(
                    opacity: _iconFadeAnimation,
                    child: ScaleTransition(
                      scale: _iconScaleAnimation,
                      child: ScaleTransition(
                        scale: _breathingAnimation,
                        child: Icon(Icons.lightbulb_outline, size: 80.sp, color: theme.colorScheme.primary, shadows: [BoxShadow(color: theme.colorScheme.primary.withOpacity(0.5), blurRadius: 24.0, spreadRadius: 4.0)]),
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  // Kademeli Gelen Metinler
                  FadeTransition(
                    opacity: _textFadeAnimation,
                    child: SlideTransition(
                      position: _textSlideAnimation,
                      child: Column(
                        children: [
                           Text(localizations.appName, textAlign: TextAlign.center, style: TextStyle(fontSize: 40.sp, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2)),
                           SizedBox(height: 8.h),
                           Text("Spark your mind", textAlign: TextAlign.center, style: TextStyle(fontSize: 16.sp, color: Colors.grey.shade400)),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(flex: 3),
                  // Kademeli Gelen ve Animasyonlu Gradyanlı Buton
                  SlideTransition(
                    position: _buttonSlideAnimation,
                    child: GestureDetector(
                      onTapDown: (_) => setState(() => _isButtonPressed = true),
                      onTapUp: (_) => setState(() => _isButtonPressed = false),
                      onTapCancel: () => setState(() => _isButtonPressed = false),
                      onTap: () => signInWithGoogle(context),
                      child: AnimatedScale(
                        scale: _isButtonPressed ? 0.97 : 1.0,
                        duration: const Duration(milliseconds: 150),
                        child: AnimatedBuilder(
                          animation: _gradientController,
                          builder: (context, child) {
                            return Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [theme.colorScheme.primary, theme.colorScheme.tertiary, theme.colorScheme.secondary],
                                  transform: GradientRotation(_gradientController.value * 2 * pi),
                                ),
                                borderRadius: BorderRadius.circular(16.r),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 8, offset: const Offset(0, 4))],
                              ),
                              child: child,
                            );
                          },
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 24.w),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset('assets/images/google_logo.png', height: 32.h),
                                SizedBox(width: 12.w),
                                Text(localizations.continueWithGoogle, style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: Colors.black)),
                              ],
                            ),
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
        ],
      ),
    );
  }
}