// lib/main_screen.dart

import 'dart:math' as math;
import 'dart:ui';
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
import 'widgets/gradient_button.dart';

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
          // glassy floating action button — opens quiz when tapped
          Positioned(
            right: 22.w,
            bottom: 120.h,
            child: GradientButton(
              onPressed: () => onItemTapped(2),
              borderRadius: BorderRadius.circular(999.r),
              padding: EdgeInsets.all(12.w),
              colors: [Theme.of(context).colorScheme.secondary, Theme.of(context).colorScheme.primary],
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

    final currentColor = getSelectedColor(_selectedIndex);

    // Use LayoutBuilder to compute exact available width to avoid overflow
    return SafeArea(
      bottom: true,
      child: Padding(
        padding: EdgeInsets.only(left: 12.w, right: 12.w, bottom: 6.h),
        child: LayoutBuilder(builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final itemCount = _navItems.length;
          final itemWidth = (totalWidth) / itemCount;
          final leftPaddingForHighlight = 4.w; // inside container offset used for AnimatedPositioned

          // ensure highlight left does not overflow
          double highlightLeft = leftPaddingForHighlight + (_selectedIndex * itemWidth);
          highlightLeft = highlightLeft.clamp(0.0, (totalWidth - itemWidth).clamp(0.0, totalWidth));

          // reduce highlight width a bit to avoid edge overflows on very small screens
          final double highlightWidth = (itemWidth * 0.82).clamp(56.0, (itemWidth - 8.0).clamp(56.0, totalWidth));

          return ClipRRect(
            borderRadius: BorderRadius.circular(24.r),
            clipBehavior: Clip.hardEdge,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
              child: Container(
                // further reduce height by a few px to avoid tiny bottom overflow
                height: 100.h + bottomPadding,
                padding: EdgeInsets.only(bottom: bottomPadding, top: 6.h),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colorWithOpacity(theme.colorScheme.surface, 0.10), colorWithOpacity(theme.colorScheme.surface, 0.02)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(24.r),
                  // reduce shadow offset so it doesn't contribute to visual overflow
                  boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 16.r, offset: Offset(0, 6.h))],
                  border: Border.all(color: colorWithOpacity(Colors.white, 0.04)),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // floating highlighted pill behind selected icon
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 380),
                      curve: Curves.easeOutCubic,
                      // center highlight under the selected item and use highlightWidth
                      left: math.max(0.0, (highlightLeft + (itemWidth - highlightWidth) / 2).clamp(0.0, totalWidth - highlightWidth)),
                      top: 2.h,
                      width: highlightWidth,
                      height: 62.h,
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 380),
                          curve: Curves.easeOutCubic,
                          width: highlightWidth,
                          height: 56.h,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [colorWithOpacity(currentColor, 0.18), colorWithOpacity(currentColor, 0.06)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14.r),
                            boxShadow: [BoxShadow(color: colorWithOpacity(currentColor, 0.12), blurRadius: 18.r, offset: Offset(0, 10.h))],
                            border: Border.all(color: colorWithOpacity(currentColor, 0.08)),
                          ),
                        ),
                      ),
                    ),

                    // nav items row - use Expanded + FittedBox to avoid overflow
                    Row(
                      children: _navItems.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final isSelected = _selectedIndex == index;
                        final Color itemColor = isSelected ? getSelectedColor(index) : colorWithOpacity(theme.iconTheme.color!, 0.7);

                        return Expanded(
                          child: GestureDetector(
                            onTap: () => onItemTapped(index),
                            behavior: HitTestBehavior.opaque,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ScaleTransition(
                                  scale: Tween<double>(begin: 1.0, end: 1.12).animate(CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut)),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 260),
                                    curve: Curves.easeOut,
                                    padding: EdgeInsets.all(isSelected ? 6.w : 8.w),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected ? colorWithOpacity(itemColor, 0.06) : Colors.transparent,
                                    ),
                                    child: Icon(item['icon'] as IconData, size: isSelected ? 30.sp : 26.sp, color: itemColor),
                                  ),
                                ),
                                // Removed text labels under nav icons per UX request - keep compact spacing
                                SizedBox(height: 4.h),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}