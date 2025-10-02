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

  @override
  void initState() {
    super.initState();
    _pages = <Widget>[
      LeaderboardPage(idToken: widget.idToken), // Konu Tercihleri/Liderlik
      InfoPage(idToken: widget.idToken),        // Günlük Bilgi Kartı
      QuizPage(idToken: widget.idToken),         // Quizler
      ChallengePage(idToken: widget.idToken),    // Meydan Okumalar
      const SettingsPage(),                     // Ayarlar (token'ı arka planda yönetebilir)
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
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final navItems = [
      {
        'icon': Icons.leaderboard_outlined,
        'activeIcon': Icons.leaderboard,
        'label': localizations.navMainMenu,
      },
      {
        'icon': Icons.lightbulb_outline,
        'activeIcon': Icons.lightbulb,
        'label': localizations.navInfo,
      },
      {
        'icon': Icons.quiz_outlined,
        'activeIcon': Icons.quiz,
        'label': localizations.navQuiz,
      },
      {
        'icon': Icons.whatshot_outlined,
        'activeIcon': Icons.whatshot,
        'label': localizations.navChallenge,
      },
      {
        'icon': Icons.settings_outlined,
        'activeIcon': Icons.settings,
        'label': localizations.navSettings,
      },
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        // DEĞİŞİKLİK: Renkleri artık manuel olarak kontrol ettiğimiz için
        // temadaki renkleri geçersiz kılıyoruz.
        selectedItemColor: theme.colorScheme.primary, 
        unselectedItemColor: theme.bottomNavigationBarTheme.unselectedItemColor,
        selectedLabelStyle:
            TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold),
        unselectedLabelStyle: TextStyle(fontSize: 9.sp),
        
        // DEĞİŞİKLİK: items listesini dinamik olarak oluşturuyoruz.
        items: navItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          
          final isSelected = _selectedIndex == index;

          Color itemColor;
          if (isSelected) {
            // Eğer özel sekme seçiliyse tertiary, değilse primary rengini kullan.
            itemColor = theme.colorScheme.tertiary;
          } else {
            // Eğer seçili değilse, normal sönük rengi kullan.
            itemColor = theme.bottomNavigationBarTheme.unselectedItemColor!;
          }

          return BottomNavigationBarItem(
            icon: Icon(item['icon'] as IconData, size: 24.sp, color: itemColor),
            // activeIcon, sekme seçildiğinde gösterilecek ikondur.
            // Bu, daha modern bir görünüm sağlar.
            activeIcon: Icon(item['activeIcon'] as IconData, size: 24.sp, color: itemColor),
            label: item['label'] as String,
          );
        }).toList(),
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}