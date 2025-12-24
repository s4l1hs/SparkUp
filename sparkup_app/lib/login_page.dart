import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'l10n/app_localizations.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'utils/color_utils.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  // --- Animasyon Controller'ları ---
  late final AnimationController
      _entryController; // Elementlerin giriş animasyonu için
  late final AnimationController
      _backgroundController; // Arka plan ışıltılarının hareketi için
  late final AnimationController
      _breathingController; // İkonun nefes alma efekti için
  late final AnimationController
      _gradientController; // Butonun gradyan animasyonu için
  late final AnimationController _pulseController; // buton içi pulse

  // --- Animasyon Değerleri ---
  late final Animation<double> _iconFadeAnimation;
  late final Animation<double> _iconScaleAnimation;
  late final Animation<Offset> _textSlideAnimation;
  late final Animation<double> _textFadeAnimation;
  late final Animation<Offset> _buttonSlideAnimation;
  late final Animation<double> _breathingAnimation;
  // ignore: unused_field
  late final Animation<double> _pulseAnimation;

  bool _isButtonPressed = false;
  bool _isSigningIn = false;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _backgroundController =
        AnimationController(vsync: this, duration: const Duration(seconds: 30))
          ..repeat();
    _breathingController =
        AnimationController(vsync: this, duration: const Duration(seconds: 4))
          ..repeat(reverse: true);
    _gradientController =
        AnimationController(vsync: this, duration: const Duration(seconds: 6))
          ..repeat();
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);

    // Kademeli giriş animasyonları
    _iconFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _entryController,
            curve: const Interval(0.0, 0.5, curve: Curves.easeOut)));
    _iconScaleAnimation = Tween<double>(begin: 0.86, end: 1.0).animate(
        CurvedAnimation(
            parent: _entryController,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic)));
    _textFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _entryController,
            curve: const Interval(0.2, 0.7, curve: Curves.easeOut)));
    _textSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _entryController,
                curve: const Interval(0.2, 0.7, curve: Curves.easeOut)));
    _buttonSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _entryController,
                curve: const Interval(0.55, 1.0, curve: Curves.easeOutCubic)));

    // Arka plan ışıltılarının gezinme animasyonları (farklı yönlerde)

    // İkonun nefes alma animasyonu
    _breathingAnimation = Tween<double>(begin: 0.985, end: 1.02).animate(
        CurvedAnimation(
            parent: _breathingController, curve: Curves.easeInOutSine));
    _pulseAnimation = Tween<double>(begin: 0.98, end: 1.03).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _backgroundController.dispose();
    _breathingController.dispose();
    _gradientController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> signInWithGoogle(BuildContext context) async {
    if (_isSigningIn) return;
    setState(() => _isSigningIn = true);
    try {
      if (kIsWeb) {
        GoogleAuthProvider authProvider = GoogleAuthProvider();
        await FirebaseAuth.instance.signInWithPopup(authProvider);
      } else {
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) {
          setState(() => _isSigningIn = false);
          return;
        }
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);
      }
    } catch (e) {
      debugPrint('Google Sign-In hatası: $e');
      if (!mounted) return;
      final msg = AppLocalizations.of(this.context)?.loginFailedMessage ??
          'Login failed';
      _showErrorSnackBar(this.context, msg);
    } finally {
      if (mounted) {
        setState(() => _isSigningIn = false);
      }
    }
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
      backgroundColor: Colors.transparent,
      elevation: 0,
      content: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.error,
            borderRadius: BorderRadius.circular(14.r)),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 12.w),
            Expanded(
                child: Text(message,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold))),
          ],
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;
    final media = MediaQuery.of(context);
    final animate = !media.accessibleNavigation;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // header icon + title
                    Column(
                      children: [
                        animate
                            ? FadeTransition(
                                opacity: _iconFadeAnimation,
                                child: ScaleTransition(
                                  scale: _iconScaleAnimation,
                                  child: ScaleTransition(
                                    scale: _breathingAnimation,
                                    child: Container(
                                      width: 96.w,
                                      height: 96.w,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(colors: [
                                          theme.colorScheme.secondary,
                                          theme.colorScheme.primary
                                        ]),
                                        boxShadow: [
                                          BoxShadow(
                                              color: colorWithOpacity(
                                                  Colors.black, 0.22),
                                              blurRadius: 20.r,
                                              offset: Offset(0, 8.h))
                                        ],
                                      ),
                                      child: Icon(Icons.lightbulb_outline,
                                          size: 44.sp, color: Colors.white),
                                    ),
                                  ),
                                ),
                              )
                            : Container(
                                width: 96.w,
                                height: 96.w,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(colors: [
                                    theme.colorScheme.secondary,
                                    theme.colorScheme.primary
                                  ]),
                                  boxShadow: [
                                    BoxShadow(
                                        color: colorWithOpacity(
                                            Colors.black, 0.16),
                                        blurRadius: 18.r,
                                        offset: Offset(0, 6.h))
                                  ],
                                ),
                                child: Icon(Icons.lightbulb_outline,
                                    size: 44.sp, color: Colors.white),
                              ),
                        SizedBox(height: 18.h),
                        FadeTransition(
                          opacity: _textFadeAnimation,
                          child: animate
                              ? SlideTransition(
                                  position: _textSlideAnimation,
                                  child: Column(
                                    children: [
                                      // gradient title for a more premium look
                                      ShaderMask(
                                        shaderCallback: (bounds) =>
                                            LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            theme.colorScheme.secondary,
                                            theme.colorScheme.primary
                                          ],
                                        ).createShader(Rect.fromLTWH(0, 0,
                                                bounds.width, bounds.height)),
                                        blendMode: BlendMode.srcIn,
                                        child: Text(
                                          localizations.appName,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              fontSize: 34.sp,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white),
                                        ),
                                      ),
                                      SizedBox(height: 6.h),
                                      Text(
                                        localizations.appSlogan,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 13.sp,
                                            color: Colors.white70,
                                            fontStyle: FontStyle.italic),
                                      ),
                                    ],
                                  ),
                                )
                              : Column(
                                  children: [
                                    ShaderMask(
                                      shaderCallback: (bounds) =>
                                          LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          theme.colorScheme.secondary,
                                          theme.colorScheme.primary
                                        ],
                                      ).createShader(Rect.fromLTWH(0, 0,
                                              bounds.width, bounds.height)),
                                      blendMode: BlendMode.srcIn,
                                      child: Text(
                                        localizations.appName,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 34.sp,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white),
                                      ),
                                    ),
                                    SizedBox(height: 6.h),
                                    Text(
                                      localizations.appSlogan,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 13.sp,
                                          color: Colors.white70,
                                          fontStyle: FontStyle.italic),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),

                    // CTA area (kept compact and bounded)
                    SlideTransition(
                      position: animate
                          ? _buttonSlideAnimation
                          : const AlwaysStoppedAnimation(Offset.zero),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18.r),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                                horizontal: 20.w, vertical: 18.h),
                            decoration: BoxDecoration(
                              color: colorWithOpacity(Colors.white, 0.03),
                              borderRadius: BorderRadius.circular(18.r),
                              border: Border.all(
                                  color: colorWithOpacity(Colors.white, 0.04)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(height: 8.h),
                                GestureDetector(
                                  onTapDown: (_) =>
                                      setState(() => _isButtonPressed = true),
                                  onTapUp: (_) =>
                                      setState(() => _isButtonPressed = false),
                                  onTapCancel: () =>
                                      setState(() => _isButtonPressed = false),
                                  onTap: () => signInWithGoogle(context),
                                  child: AnimatedScale(
                                    scale: _isButtonPressed ? 0.985 : 1.0,
                                    duration: const Duration(milliseconds: 160),
                                    curve: Curves.easeOutCubic,
                                    child: AnimatedBuilder(
                                      animation: Listenable.merge([
                                        _gradientController,
                                        _pulseController
                                      ]),
                                      builder: (context, child) {
                                        return Container(
                                          height: 56.h,
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            // smoother continuous oscillation using sine -> no sudden flip at loop boundary
                                            gradient: LinearGradient(
                                              colors: [
                                                colorWithOpacity(
                                                    theme.colorScheme.primary,
                                                    0.98),
                                                colorWithOpacity(
                                                    theme.colorScheme.tertiary,
                                                    0.95),
                                                colorWithOpacity(
                                                    theme.colorScheme.secondary,
                                                    0.95)
                                              ],
                                              begin: Alignment(
                                                  -math.sin(_gradientController
                                                          .value *
                                                      2 *
                                                      math.pi),
                                                  -0.35),
                                              end: Alignment(
                                                  math.sin(_gradientController
                                                          .value *
                                                      2 *
                                                      math.pi),
                                                  0.35),
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(12.r),
                                            boxShadow: [
                                              BoxShadow(
                                                  color: colorWithOpacity(
                                                      Colors.black, 0.18),
                                                  blurRadius: 10.r,
                                                  offset: Offset(0, 6.h))
                                            ],
                                            // Outer border removed per design request
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Container(
                                                margin: EdgeInsets.only(
                                                    right: 12.w),
                                                width: 36.w,
                                                height: 36.w,
                                                decoration: const BoxDecoration(
                                                    color: Colors.white,
                                                    shape: BoxShape.circle),
                                                child: Padding(
                                                  padding: EdgeInsets.all(6.w),
                                                  child: Image.asset(
                                                      'assets/images/google_logo.png',
                                                      fit: BoxFit.contain,
                                                      errorBuilder: (c, e, s) {
                                                    return Center(
                                                        child: Icon(Icons.login,
                                                            color:
                                                                Colors.black54,
                                                            size: 18.sp));
                                                  }),
                                                ),
                                              ),
                                              Flexible(
                                                child: Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                    Opacity(
                                                      opacity: _isSigningIn
                                                          ? 0.0
                                                          : 1.0,
                                                      child: Text(
                                                          localizations
                                                              .continueWithGoogle,
                                                          style: TextStyle(
                                                              color: Colors
                                                                  .black87,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 16.sp)),
                                                    ),
                                                    if (_isSigningIn)
                                                      Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          SizedBox(
                                                              width: 16.w,
                                                              height: 16.w,
                                                              child: CircularProgressIndicator(
                                                                  strokeWidth:
                                                                      2.2,
                                                                  color: theme
                                                                      .colorScheme
                                                                      .primary)),
                                                          SizedBox(width: 10.w),
                                                          Text(
                                                              localizations
                                                                  .loading,
                                                              style: TextStyle(
                                                                  color: Colors
                                                                      .black87,
                                                                  fontSize:
                                                                      14.sp)),
                                                        ],
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                SizedBox(height: 12.h),
                                SizedBox(height: 6.h),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
