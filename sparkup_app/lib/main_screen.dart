import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'l10n/app_localizations.dart';
import 'pages/challenge_page.dart';
import 'pages/info_page.dart';
import 'pages/leaderboard_page.dart';
import 'pages/quiz_page.dart';
import 'pages/settings_page.dart';

class MainScreen extends StatefulWidget {
  final String idToken;
  const MainScreen({super.key, required this.idToken});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late List<Widget> _pages;
  late final List<Map<String, dynamic>> _navItems;

  @override
  void initState() {
    super.initState();
    _pages = <Widget>[
      LeaderboardPage(idToken: widget.idToken),
      InfoPage(idToken: widget.idToken),
      QuizPage(idToken: widget.idToken),
      ChallengePage(idToken: widget.idToken),
      const SettingsPage(),
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final localizations = AppLocalizations.of(context)!;
    _navItems = [
      {'icon': Icons.leaderboard_outlined, 'label': localizations.navMainMenu},
      {'icon': Icons.lightbulb_outline, 'label': localizations.navInfo},
      {'icon': Icons.quiz_outlined, 'label': localizations.navQuiz},
      {'icon': Icons.whatshot_outlined, 'label': localizations.navChallenge},
      {'icon': Icons.settings_outlined, 'label': localizations.navSettings},
    ];
  }

  @override
  void didUpdateWidget(covariant MainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.idToken != widget.idToken) {
      _pages = <Widget>[
        LeaderboardPage(idToken: widget.idToken),
        InfoPage(idToken: widget.idToken),
        QuizPage(idToken: widget.idToken),
        ChallengePage(idToken: widget.idToken),
        const SettingsPage(),
      ];
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.98, end: 1.0).animate(animation),
              child: child,
            ),
          );
        },
        child: Container(
          key: ValueKey<int>(_selectedIndex),
          child: _pages[_selectedIndex],
        ),
      ),
      bottomNavigationBar: _buildCustomBottomNav(),
    );
  }

  Widget _buildCustomBottomNav() {
    final theme = Theme.of(context);
    final viewPadding = MediaQuery.of(context).viewPadding;
    final double bottomPadding = viewPadding.bottom > 0 ? viewPadding.bottom : 16.h;

    Color getSelectedColor(int index) {
      switch (index) {
        case 0: return theme.colorScheme.primary;
        case 1: return Colors.amberAccent.shade700;
        case 2: return theme.colorScheme.tertiary;
        case 3: return theme.colorScheme.secondary;
        case 4: return Colors.grey.shade400;
        default: return theme.colorScheme.primary;
      }
    }

    final Color currentSelectedColor = getSelectedColor(_selectedIndex);

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          height: 65.h + bottomPadding,
          padding: EdgeInsets.only(bottom: bottomPadding, left: 16.w, right: 16.w),
          decoration: BoxDecoration(
            color: theme.bottomNavigationBarTheme.backgroundColor!.withOpacity(0.85),
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
          ),
          child: Stack(
            alignment: Alignment.center, 
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                top: ((65.h - 60.h) / 2) + 4.h,
                left: (MediaQuery.of(context).size.width - 32.w) / _navItems.length * _selectedIndex,
                width: (MediaQuery.of(context).size.width - 32.w) / _navItems.length,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 60.w, 
                    height: 60.h,
                    decoration: BoxDecoration(
                      color: currentSelectedColor.withOpacity(0.2), 
                      borderRadius: BorderRadius.circular(12.r), 
                    ),
                  ),
                ),
              ),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: _navItems.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final isSelected = _selectedIndex == index;
                  final Color itemColor = isSelected ? getSelectedColor(index) : theme.bottomNavigationBarTheme.unselectedItemColor!;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => _onItemTapped(index),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedScale(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                            scale: isSelected ? 1.3 : 1.0, 
                            child: Icon(item['icon'] as IconData, size: 32.sp, color: itemColor),
                          ),
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
  }
}