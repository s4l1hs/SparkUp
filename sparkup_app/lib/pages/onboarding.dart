import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth_gate.dart';
// localization temporarily unused in onboarding; using plain text for now
import '../services/api_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  final PageController _pc = PageController();
  double _currentPage = 0;
  // Prevent multiple taps while page transition / navigation is ongoing
  bool _isTransitioning = false;

  @override
  void initState() {
    super.initState();
    _pc.addListener(() {
      setState(() => _currentPage = _pc.page ?? 0);
    });
  }

  final List<OnboardingData> _content = [
    OnboardingData(
      title: '',
      body: '',
      emoji: '💡',
      color: const Color(0xFF00B8D4), // darker cyan
    ),
    OnboardingData(
      title: '',
      body: '',
      emoji: '🔥',
      color: const Color(0xFFFF5722), // deeper purple
    ),
    OnboardingData(
      title: '',
      body: '',
      emoji: '📈',
      color: const Color.fromARGB(255, 121, 83, 0), // darker teal
    ),
    OnboardingData(
      title: '',
      body: '',
      emoji: '⚡',
      color: const Color.fromARGB(255, 46, 125, 50), // richer green
    ),
    OnboardingData(
      title: '',
      body: '',
      emoji: '👑',
      color: const Color(0xFFFFD700), // muted accent
      isIntroToData: true,
    ),
  ];

  void _finish() async {
    HapticFeedback.heavyImpact();
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    // Always set a local global flag (covers non-signed-in flows)
    await prefs.setBool('seen_onboarding', true);

    if (user != null) {
      // Set per-user local flag
      await prefs.setBool('seen_onboarding_uid_${user.uid}', true);

      // Also notify backend so server-side checks work consistently
      try {
        final token = await user.getIdToken();
        // Use ApiService so we don't import main.dart here and avoid circular imports
        try {
          await ApiService().updateOnboarding(token!, true);
        } catch (_) {
          // ignore backend failures; local prefs still prevent re-showing
        }
      } catch (_) {
        // ignore token failures
      }
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, anim, second) => const AuthGate(),
        transitionsBuilder: (context, anim, second, child) => FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Stack(
        children: [
          // Arka plan soft geçişi
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _content[_currentPage.round()].color.withAlpha((0.10 * 255).round()),
                  Theme.of(context).colorScheme.surface,
                ],
              ),
            ),
          ),
          _buildBackgroundOrbs(),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: PageView.builder(
                    controller: _pc,
                    itemCount: _content.length,
                    onPageChanged: (int page) => HapticFeedback.selectionClick(),
                    itemBuilder: (context, index) => _buildPageContent(index),
                  ),
                ),
                _buildBottomControls(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageContent(int index) {
    bool isLast = _content[index].isIntroToData;
    double delta = index - _currentPage;
    double opacity = (1 - delta.abs()).clamp(0.0, 1.0);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 40.w),
      child: Opacity(
        opacity: opacity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!isLast) _buildAestheticGraphic(index, delta) else _buildDataInfoGraphic(index),
            SizedBox(height: 60.h),
            // Metinler için Slide-up efekti simülasyonu
            Transform.translate(
              offset: Offset(0, delta * 20),
              child: Column(
                children: [
                    Text(
                      _localizedTitle(context, index),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 32.sp,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                        color: Colors.white,
                      ),
                    ),
                  SizedBox(height: 18.h),
                    Text(
                      _localizedBody(context, index),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16.sp,
                        color: Colors.white70,
                        height: 1.6,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Yenilenmiş Estetik Grafik Yapısı (1-4. Sayfalar için)
  Widget _buildAestheticGraphic(int index, double delta) {
    return Container(
      height: 260.h,
      width: 260.w,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Arka Plan Dekoratif Halka
          Transform.rotate(
            angle: delta * 2,
            child: Container(
              height: 200.h,
              width: 200.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _content[index].color.withAlpha((0.2 * 255).round()), width: 2),
              ),
            ),
          ),
          // Glassmorphism Ana Katman
          Transform.scale(
            scale: 1 - delta.abs() * 0.2,
            child: Container(
              height: 180.h,
              width: 180.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: _content[index].color.withAlpha((0.3 * 255).round()),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withAlpha((0.8 * 255).round()),
                          _content[index].color.withAlpha((0.1 * 255).round()),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Text(
                      _content[index].emoji,
                      style: TextStyle(fontSize: 95.sp, shadows: [
                        Shadow(
                          color: Colors.black.withAlpha((0.1 * 255).round()),
                          blurRadius: 10,
                          offset: const Offset(0, 10),
                        )
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Hareketli Küçük Parçacıklar
          _buildFloatingParticle(delta, -80, -80, 20, _content[index].color),
          _buildFloatingParticle(delta, 90, 60, 15, _content[index].color.withAlpha((0.5 * 255).round())),
        ],
      ),
    );
  }

  Widget _buildFloatingParticle(double delta, double x, double y, double size, Color color) {
    return Transform.translate(
      offset: Offset(x + (delta * 50), y + (delta * 20)),
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }

  // 5. Sayfa: Veri Gerekliliğini Anlatan Güncellenmiş Estetik Grafik
  Widget _buildDataInfoGraphic(int index) {
    double delta = index - _currentPage;
    
    return Container(
      height: 260.h,
      width: 260.w,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Arka planda dönen hafif bir halka (Tutarlılık için)
          Transform.rotate(
            angle: -delta * 3,
            child: Container(
              height: 210.h,
              width: 210.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _content[index].color.withAlpha((0.15 * 255).round()),
                  width: 1.5,
                  style: BorderStyle.solid,
                ),
              ),
            ),
          ),
          
          // Ana Glassmorphism Küre
          Container(
            height: 160.h,
            width: 160.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _content[index].color.withAlpha((0.2 * 255).round()),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.surface.withAlpha((0.95 * 255).round()),
                          _content[index].color.withAlpha((0.12 * 255).round()),
                        ],
                      ),
                  ),
                  child: Text(
                    _content[index].emoji,
                      style: TextStyle(fontSize: 75.sp, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),

          // Yüzen Etiketler - Artık daha estetik ve ana yapıya uygun
          _aestheticFloatingTag('', -85.w, -75.h, Icons.timer, const Color.fromARGB(255, 67, 34, 255)),
          _aestheticFloatingTag('', 95.w, -35.h, Icons.favorite, const Color.fromARGB(255, 255, 23, 23)),
          _aestheticFloatingTag('', 60.w, 90.h, Icons.energy_savings_leaf, const Color.fromARGB(255, 244, 140, 3)),
        ],
      ),
    );
  }

  // 5. Sayfaya özel, diğer sayfalarla uyumlu "Glass" etiketler
  Widget _aestheticFloatingTag(String label, double x, double y, IconData icon, Color color) {
    return Transform.translate(
      offset: Offset(x, y),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha((0.1 * 255).round()),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha((0.8 * 255).round()),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withAlpha((0.5 * 255).round())),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16.sp, color: color),
                  SizedBox(width: 6.w),
                  Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'SparkUp',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 26.sp,
              color: _content[_currentPage.round()].color,
              letterSpacing: -1,
            ),
          ),
          if (_currentPage.round() < _content.length - 1)
            GestureDetector(
              onTap: _finish,
              child: Text(
                'Skip',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.grey[400],
                  fontWeight: FontWeight.bold,
                  fontSize: 14.sp,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    bool isLast = _currentPage.round() == _content.length - 1;
    return Padding(
      padding: EdgeInsets.fromLTRB(30.w, 0, 30.w, 40.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: List.generate(_content.length, (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(right: 8),
              height: 6, width: _currentPage.round() == i ? 28 : 6,
              decoration: BoxDecoration(
                color: _currentPage.round() == i ? _content[i].color : _content[i].color.withAlpha((0.2 * 255).round()),
                borderRadius: BorderRadius.circular(10),
              ),
            )),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            child: ElevatedButton(
              onPressed: _isTransitioning
                  ? null
                  : () async {
                      if (_isTransitioning) return;
                      setState(() => _isTransitioning = true);
                      if (isLast) {
                        _finish();
                      } else {
                        try {
                          await _pc.nextPage(duration: const Duration(milliseconds: 600), curve: Curves.easeInOutExpo);
                        } finally {
                          if (mounted) setState(() => _isTransitioning = false);
                        }
                      }
                    },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                  // Always use the same background color even when disabled
                  return _content[_currentPage.round()].color;
                }),
                foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
                padding: WidgetStateProperty.all<EdgeInsets>(
                    EdgeInsets.symmetric(horizontal: isLast ? 35.w : 25.w, vertical: 18.h)),
                shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                elevation: WidgetStateProperty.all<double>(10),
                shadowColor: WidgetStateProperty.all<Color>(_content[_currentPage.round()].color.withAlpha((0.4 * 255).round())),
              ),
                child: Text(
                isLast ? 'Get Started' : 'Next',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15.sp),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundOrbs() {
    return Stack(
      children: [
        Positioned(top: -100.h, right: -100.w, child: _Orb(color: _content[_currentPage.round()].color, size: 350)),
        Positioned(bottom: -50.h, left: -100.w, child: _Orb(color: _content[_currentPage.round()].color, size: 400)),
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  final Color color;
  final double size;
  const _Orb({required this.color, this.size = 200});
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 1000),
      height: size, width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withAlpha((0.12 * 255).round()), Colors.transparent],
        ),
      ),
    );
  }
}

class OnboardingData {
  final String title, body, emoji;
  final Color color;
  final bool isIntroToData;
  OnboardingData({required this.title, required this.body, required this.emoji, required this.color, this.isIntroToData = false});
}

// Localization helpers
extension _OnboardingLocalizations on _OnboardingScreenState {
  String _localizedTitle(BuildContext context, int index) {
    switch (index) {
      case 0:
        return 'Welcome to SparkUp';
      case 1:
        return 'Solve fun quizzes';
      case 2:
        return 'Analyze yourself';
      case 3:
        return 'Be the best';
      case 4:
        return 'Cheap subscriptions';
      default:
        return '';
    }
  }

  String _localizedBody(BuildContext context, int index) {
    switch (index) {
      case 0:
        return 'Learn new things while having fun, broaden your horizons, and take your place on the leadership board';
      case 1:
        return 'Challenge time with quiz and true-false questions, aim for record-breaking scores, and whatever you do, do not get 3 wrong!';
      case 2:
        return 'See how knowledgeable you are with the analytics page.';
      case 3:
        return 'You have 3 energy points per day, use them sparingly!';
      case 4:
        return 'Upgrade your subscription plan to get more daily energy and time on true-false and quiz questions.';
      default:
        return '';
    }
  }
}