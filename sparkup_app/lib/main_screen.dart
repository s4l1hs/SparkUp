import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'l10n/app_localizations.dart';
// Yeni Spark Up sayfalarını import ediyoruz
import 'pages/challenge_page.dart';
import 'pages/info_page.dart';
import 'pages/leaderboard_page.dart';
import 'pages/quiz_page.dart';
import 'pages/settings_page.dart';

class MainScreen extends StatefulWidget {
  // 1. Backend API çağrıları için gerekli olan idToken'ı alıyoruz.
  final String idToken;
  const MainScreen({super.key, required this.idToken});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // Sayfalar listesi dinamik olarak oluşturulmalı, çünkü idToken'a ihtiyacı var.
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    // 2. idToken'ı tüm yetkilendirilmiş sayfalara iletiyoruz.
    _pages = <Widget>[
      LeaderboardPage(idToken: widget.idToken), // Konu Tercihleri/Liderlik
      InfoPage(idToken: widget.idToken),        // Günlük Bilgi Kartı
      QuizPage(idToken: widget.idToken),         // Quizler
      ChallengePage(idToken: widget.idToken),    // Meydan Okumalar
      const SettingsPage(),                     // Ayarlar (token'ı arka planda yönetebilir)
    ];
  }
  
  // Widget'ın idToken'ı değişirse sayfaları yenilemek için (çok nadir gerekir)
  @override
  void didUpdateWidget(covariant MainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.idToken != widget.idToken) {
      // idToken değişirse, sayfa listesini yeniden oluştururuz.
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
    

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // 5 öğe için sabit tip
        backgroundColor: Colors.grey.shade900,
        selectedItemColor: Colors.amber,
        unselectedItemColor: Colors.grey.shade600,
        selectedLabelStyle: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold),
        unselectedLabelStyle: TextStyle(fontSize: 9.sp),
        
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.leaderboard_outlined, size: 24.sp),
            label: localizations.navMainMenu, // 'Leaderboard' yerine daha genel
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.lightbulb_outline, size: 24.sp),
            label: localizations.navInfo, 
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.quiz_outlined, size: 24.sp),
            label: localizations.navQuiz, 
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center_rounded, size: 24.sp),
            label: localizations.navChallenge, 
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined, size: 24.sp),
            label: localizations.navSettings, 
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}