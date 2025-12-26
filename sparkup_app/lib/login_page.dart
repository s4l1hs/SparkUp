import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'l10n/app_localizations.dart';
import 'utils/color_utils.dart'; // colorWithOpacity fonksiyonun burada olduğunu varsayıyorum

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  // --- Animasyon Controller'ları ---
  late final AnimationController _backgroundController; // Arka plan blob hareketi
  late final AnimationController _entryController; // Sayfa açılış animasyonu
  late final AnimationController _pulseController; // İkon/Buton nefes alma

  // --- Animasyon Değerleri ---
  late final Animation<Alignment> _backgroundAnimation1;
  late final Animation<Alignment> _backgroundAnimation2;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _scaleAnimation;

  bool _isSigningIn = false;
  bool _isButtonPressed = false;

  @override
  void initState() {
    super.initState();

    // 1. Arka Plan Animasyonu (Sürekli dönen renkli toplar)
    _backgroundController =
        AnimationController(vsync: this, duration: const Duration(seconds: 25))
          ..repeat(reverse: true);

    _backgroundAnimation1 = TweenSequence<Alignment>([
      TweenSequenceItem(
          tween: AlignmentTween(
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          weight: 1),
      TweenSequenceItem(
          tween: AlignmentTween(
              begin: Alignment.bottomRight, end: Alignment.topLeft),
          weight: 1),
    ]).animate(CurvedAnimation(
        parent: _backgroundController, curve: Curves.easeInOutSine));

    _backgroundAnimation2 = TweenSequence<Alignment>([
      TweenSequenceItem(
          tween: AlignmentTween(
              begin: Alignment.bottomRight, end: Alignment.topLeft),
          weight: 1),
      TweenSequenceItem(
          tween: AlignmentTween(
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          weight: 1),
    ]).animate(CurvedAnimation(
        parent: _backgroundController, curve: Curves.easeInOutSine));

    // 2. Giriş Animasyonu (Elemanların sahneye gelişi)
    _entryController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _entryController,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOut)));

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _entryController,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic)));

    // 3. Pulse (Nefes Alma) Animasyonu
    _pulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 4))
          ..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    // Animasyonu başlat
    _entryController.forward();
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _entryController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn(BuildContext context) async {
    if (_isSigningIn) return;

    setState(() => _isSigningIn = true);

    try {
      if (kIsWeb) {
        GoogleAuthProvider authProvider = GoogleAuthProvider();
        await FirebaseAuth.instance.signInWithPopup(authProvider);
      } else {
        final GoogleSignIn googleSignIn = GoogleSignIn();
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

        if (googleUser != null) {
          final GoogleSignInAuthentication googleAuth =
              await googleUser.authentication;
          final AuthCredential credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );
          await FirebaseAuth.instance.signInWithCredential(credential);
        }
      }
    } catch (e) {
      debugPrint("Login Error: $e");
      if (!mounted) return;
      final msg = AppLocalizations.of(context)?.loginFailedMessage ??
          'Login failed. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSigningIn = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context);
    final animate = !MediaQuery.of(context).accessibleNavigation;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          // --- 1. AMBIENT BACKGROUND BLOBS ---
          AnimatedBuilder(
            animation:
                animate ? _backgroundController : const AlwaysStoppedAnimation(0),
            builder: (context, child) {
              return Stack(
                children: [
                  Positioned.fill(
                    child: Align(
                      alignment: _backgroundAnimation1.value,
                      child: Container(
                        width: 400.w,
                        height: 400.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              colorWithOpacity(theme.colorScheme.primary, 0.25),
                              Colors.transparent
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colorWithOpacity(
                                  theme.colorScheme.primary, 0.1),
                              blurRadius: 100,
                              spreadRadius: 50,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Align(
                      alignment: _backgroundAnimation2.value,
                      child: Container(
                        width: 300.w,
                        height: 300.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              colorWithOpacity(theme.colorScheme.secondary, 0.2),
                              Colors.transparent
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colorWithOpacity(
                                  theme.colorScheme.secondary, 0.08),
                              blurRadius: 80,
                              spreadRadius: 40,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Hafif blur ile blob'ları yumuşatıyoruz
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                ],
              );
            },
          ),

          // --- 2. MAIN CONTENT ---
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 2),

                      // --- HERO ICON & TITLE ---
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: Container(
                          padding: EdgeInsets.all(24.r),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                theme.colorScheme.primary.withAlpha(51),
                                theme.colorScheme.secondary.withAlpha(51),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.white.withAlpha(51),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary.withAlpha(77),
                                blurRadius: 40,
                                spreadRadius: 0,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.lightbulb_outline_rounded,
                            size: 64.sp,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(height: 32.h),

                      // App Name Gradient Text
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [
                            theme.colorScheme.secondary,
                            theme.colorScheme.primary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds),
                        child: Text(
                          localizations?.appName ?? 'SparkUp',
                          style: TextStyle(
                            fontSize: 42.sp,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -1.0,
                          ),
                        ),
                      ),
                      SizedBox(height: 12.h),

                      // Slogan
                      Text(
                        localizations?.appSlogan ?? 'Ignite your mind',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: Colors.white.withAlpha(179),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),

                      const Spacer(flex: 3),

                      // --- LOGIN CARD (GLASSMORPHISM) ---
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24.r),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                                horizontal: 24.w, vertical: 32.h),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(20),
                              borderRadius: BorderRadius.circular(24.r),
                              border: Border.all(
                                color: Colors.white.withAlpha(31),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                // Google Sign In Button
                                GestureDetector(
                                  onTapDown: (_) =>
                                      setState(() => _isButtonPressed = true),
                                  onTapUp: (_) =>
                                      setState(() => _isButtonPressed = false),
                                  onTapCancel: () =>
                                      setState(() => _isButtonPressed = false),
                                  onTap: () => _handleGoogleSignIn(context),
                                  child: AnimatedScale(
                                    scale: _isButtonPressed ? 0.96 : 1.0,
                                    duration: const Duration(milliseconds: 100),
                                    child: Container(
                                      height: 56.h,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            theme.colorScheme.secondary,
                                            theme.colorScheme.primary,
                                          ],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(16.r),
                                        boxShadow: [
                                          BoxShadow(
                                            color: theme.colorScheme.primary
                                                .withAlpha(102),
                                            blurRadius: 16,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          // White circle container for Google Logo
                                          Container(
                                            margin: EdgeInsets.all(4.w),
                                            width: 48.w,
                                            height: 48.w,
                                            decoration: const BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Padding(
                                              padding: EdgeInsets.all(8.w),
                                              child: Image.asset(
                                                'assets/images/google_logo.png',
                                                fit: BoxFit.contain,
                                                // Fallback icon if asset missing
                                                errorBuilder: (c, e, s) => Icon(
                                                    Icons.login,
                                                    color: theme
                                                        .colorScheme.primary,
                                                    size: 20.sp),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Center(
                                              child: _isSigningIn
                                                  ? SizedBox(
                                                      width: 20.w,
                                                      height: 20.w,
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth: 2.5,
                                                        color: Colors.white,
                                                      ),
                                                    )
                                                  : Text(
                                                      localizations
                                                              ?.continueWithGoogle ??
                                                          'Continue with Google',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 16.sp,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                            ),
                                          ),
                                          SizedBox(width: 16.w),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      const Spacer(flex: 1),
                      // Alt boşluk (Bottom safe area için)
                      SizedBox(height: 12.h),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}