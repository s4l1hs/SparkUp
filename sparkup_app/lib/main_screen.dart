// lib/main_screen.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sparkup_app/utils/color_utils.dart';
import 'l10n/app_localizations.dart';
import 'pages/challenge_page.dart';
import 'pages/subscription_page.dart';
import 'pages/leaderboard_page.dart';
import 'pages/quiz_page.dart';
import 'pages/settings_page.dart';
import 'widgets/animated_glass_card.dart';
import 'widgets/morphing_gradient_button.dart';

class MainScreen extends StatefulWidget {
  final String idToken;
  const MainScreen({super.key, required this.idToken});

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late final List<Widget> _pages; // pages are retained in memory
  late List<Map<String, dynamic>> _navItems;
  late AnimationController _bounceController;

  @override
  void initState() {
    super.initState();
    _pages = <Widget>[
      LeaderboardPage(idToken: widget.idToken),
      SubscriptionPage(idToken: widget.idToken),
      QuizPage(idToken: widget.idToken),
      ChallengePage(idToken: widget.idToken),
      const SettingsPage(),
    ];
    _bounceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final localizations = AppLocalizations.of(context)!;
    _navItems = [
      {'icon': Icons.leaderboard_outlined, 'label': localizations.navMainMenu, 'color': Colors.indigo},
      {'icon': Icons.subscriptions, 'label': localizations.subscriptions, 'color': Colors.teal},
      {'icon': Icons.quiz_outlined, 'label': localizations.navQuiz, 'color': Colors.deepOrange},
      {'icon': Icons.whatshot_outlined, 'label': localizations.navChallenge, 'color': Colors.amber},
      {'icon': Icons.settings_outlined, 'label': localizations.navSettings, 'color': Colors.grey},
    ];
  }

  void onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _bounceController.forward(from: 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    return Scaffold(
      // immersive background gradient that blends with nav styling
      extendBody: true,
      body: Stack(
        children: [
          // Full-screen vibrant gradient background (keeps subtle motion-friendly colors)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorWithOpacity(Theme.of(context).colorScheme.primary, 0.08),
                    colorWithOpacity(Theme.of(context).colorScheme.secondary, 0.06),
                    colorWithOpacity(Theme.of(context).colorScheme.surface, 0.02),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
          // main content
          IndexedStack(index: _selectedIndex, children: _pages),
          // small subtle top-right decorative gradient blob
          Positioned(
            // limit negative offset and blob size so it never paints far outside on small screens
            right: -min(60.w, screenW * 0.08),
            top: -min(60.h, MediaQuery.of(context).size.height * 0.08),
            child: Transform.rotate(
              angle: -0.5,
              child: Container(
                width: min(200.w, screenW * 0.45),
                height: min(200.w, screenW * 0.45),
                  decoration: BoxDecoration(
                  gradient: RadialGradient(colors: [colorWithOpacity(Theme.of(context).colorScheme.primary, 0.12), Colors.transparent]),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          // glassy floating action button — opens quiz when tapped (morphing CTA)
          Positioned(
            right: 22.w,
            bottom: 120.h,
            child: MorphingGradientButton(
              onPressed: () => onItemTapped(2),
              colors: [Theme.of(context).colorScheme.secondary, Theme.of(context).colorScheme.primary],
              padding: EdgeInsets.all(12.w),
              borderRadius: BorderRadius.circular(999.r),
              child: Icon(Icons.flash_on_rounded, color: Colors.white, size: 24.sp),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildCustomBottomNav(),
    );
  }

  Widget _buildCustomBottomNav() {
    final theme = Theme.of(context);
    final viewPadding = MediaQuery.of(context).viewPadding;
    final double bottomPadding = viewPadding.bottom > 0 ? viewPadding.bottom : 12.h;

    Color getSelectedColor(int index) {
      final c = _navItems[index]['color'];
      if (c is Color) return c;
      return theme.colorScheme.primary;
    }

    // Use LayoutBuilder to compute exact available width to avoid overflow
    return SafeArea(
      bottom: true,
      child: Padding(
        padding: EdgeInsets.only(left: 12.w, right: 12.w, bottom: 6.h),
        child: LayoutBuilder(builder: (context, constraints) {
          final double notchWidth = 84.w;

          return SizedBox(
            height: 120.h + bottomPadding,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // glass bar
                Positioned.fill(
                  bottom: 0,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: AnimatedGlassCard(
                      borderRadius: BorderRadius.circular(24.r),
                      padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 12.w),
                      child: Row(
                        children: [
                          for (var i = 0; i < _navItems.length; i++)
                            if (i == 2)
                              SizedBox(width: notchWidth)
                            else
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => onItemTapped(i),
                                  behavior: HitTestBehavior.opaque,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      AnimatedScale(
                                        duration: const Duration(milliseconds: 260),
                                        scale: _selectedIndex == i ? 1.12 : 1.0,
                                        child: Container(
                                          padding: EdgeInsets.all(_selectedIndex == i ? 8.w : 6.w),
                                          decoration: BoxDecoration(shape: BoxShape.circle, color: _selectedIndex == i ? colorWithOpacity(getSelectedColor(i), 0.06) : Colors.transparent),
                                          child: Icon(_navItems[i]['icon'] as IconData, size: _selectedIndex == i ? 30.sp : 26.sp, color: _selectedIndex == i ? getSelectedColor(i) : colorWithOpacity(theme.iconTheme.color!, 0.72)),
                                        ),
                                      ),
                                      SizedBox(height: 4.h),
                                    ],
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                ),

                // central morphing CTA
                Positioned(
                  bottom: 36.h,
                  child: MorphingGradientButton(
                    onPressed: () => onItemTapped(2),
                    colors: [Theme.of(context).colorScheme.secondary, Theme.of(context).colorScheme.primary],
                    padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 12.h),
                    borderRadius: BorderRadius.circular(999.r),
                    child: Icon(Icons.flash_on_rounded, color: Colors.white, size: 28.sp),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}