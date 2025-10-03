import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';

class InfoPage extends StatefulWidget {
  final String idToken;
  const InfoPage({super.key, required this.idToken});

  @override
  State<InfoPage> createState() => _InfoPageState();
}

// DEĞİŞİKLİK: Animasyonlar için TickerProviderStateMixin eklendi
class _InfoPageState extends State<InfoPage> with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  String? _dailyInfoText;
  String? _dailyInfoSource;
  bool _isLoadingInfo = true;
  String? _error;

  // --- ANİMASYON CONTROLLER'LARI ---
  late final AnimationController _backgroundController;
  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    _fetchDailyInfo();

    // Arka plan animasyon controller'ı
    _backgroundController = AnimationController(vsync: this, duration: const Duration(seconds: 30))..repeat(reverse: true);
    
    // Kart çevirme animasyon controller'ı
    _flipController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _flipController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _flipController.dispose();
    super.dispose();
  }

  // DEĞİŞİKLİK: Veri çekme ve animasyon tetikleme mantığı güncellendi
  Future<void> _triggerRefresh() async {
    if (_isLoadingInfo) return; // Zaten yükleniyorsa tekrar tetikleme

    setState(() => _isLoadingInfo = true);
    _flipController.forward(); // Kartın dönmesini başlat

    try {
      final infoData = await _apiService.getRandomInfo(widget.idToken);
      if (mounted) {
        setState(() {
          _error = null;
          setState(() {
              _dailyInfoText = infoData['info_text']; 
              _dailyInfoSource = infoData['source'];    
            });
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Info could not be loaded: $e";
          _dailyInfoText = null;
          _dailyInfoSource = null;
        });
      }
    } finally {
      _flipController.reverse(); // Yeni veriyle kartı geri çevir
      // Geri dönme animasyonu bittiğinde yükleme durumunu kapat
      _flipController.addStatusListener((status) {
        if (status == AnimationStatus.dismissed) {
          if (mounted) setState(() => _isLoadingInfo = false);
        }
      });
    }
  }

  // Sayfa ilk açıldığında veriyi çekmek için
  Future<void> _fetchDailyInfo() async {
    // ... (_triggerRefresh ile benzer, ancak animasyonsuz ilk yükleme için)
    if (!mounted) return;
    setState(() => _isLoadingInfo = true);
    try {
      final infoData = await _apiService.getRandomInfo(widget.idToken);
      if (mounted) {
        setState(() async {
          if (mounted) {
            setState(() {
              _dailyInfoText = infoData['info_text']; 
              _dailyInfoSource = infoData['source'];    
            });
          }
        });
      }
    } catch (e) { if (mounted) setState(() => _error = "Info could not load: $e");
    } finally { if (mounted) setState(() => _isLoadingInfo = false); }
  }


  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Hareketli Arka Plan
          // ... (LoginPage'deki gibi bir AnimatedBuilder buraya eklenebilir)

          // 2. Ana İçerik
          Center(
            child: Padding(
              padding: EdgeInsets.all(32.w),
              child: AnimatedBuilder(
                animation: _flipAnimation,
                builder: (context, child) {
                  // Kartın önünü mü arkasını mı göstereceğimizi belirle
                  final isFront = _flipAnimation.value < 0.5;
                  // Döndürme açısını hesapla
                  final rotationValue = isFront ? _flipAnimation.value : -(1 - _flipAnimation.value);

                  return Transform(
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001) // 3D perspektif için
                      ..rotateY(pi * rotationValue),
                    alignment: Alignment.center,
                    child: isFront ? _buildCardFront(theme, localizations) : _buildCardBack(theme),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _triggerRefresh,
        tooltip: localizations.refresh,
        backgroundColor: theme.colorScheme.tertiary,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
          child: _isLoadingInfo
              ? CircularProgressIndicator(key: const ValueKey('spinner'), strokeWidth: 2.5, color: theme.colorScheme.onTertiary)
              : Icon(Icons.refresh_rounded, key: const ValueKey('icon'), color: theme.colorScheme.onTertiary),
        ),
      ),
    );
  }

  // Kartın ön yüzünü oluşturan Widget
  Widget _buildCardFront(ThemeData theme, AppLocalizations localizations) {
    return _buildCardBase(
      theme,
      child: _error != null
        ? Text("${localizations.error}: $_error", textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.error, fontSize: 18.sp))
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                localizations.dailyFact,
                style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary),
              ),
              SizedBox(height: 24.h),
              Icon(Icons.lightbulb_outline_rounded, color: theme.colorScheme.tertiary, size: 40.sp),
              SizedBox(height: 16.h),
              Text(
                _dailyInfoText ?? localizations.infoNotFound,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 18.sp, height: 1.5),
              ),
              SizedBox(height: 16.h),
              if (_dailyInfoSource != null && _dailyInfoSource!.isNotEmpty)
                Text(
                  "${localizations.source}: $_dailyInfoSource",
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12.sp, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
    );
  }

  // Kartın arka yüzünü (yüklenirken) oluşturan Widget
  Widget _buildCardBack(ThemeData theme) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..rotateY(pi), // Arka yüzü doğru göstermek için ters çevir
      child: _buildCardBase(theme, child: CircularProgressIndicator(color: theme.colorScheme.tertiary)),
    );
  }

  // Kartların ortak temelini oluşturan Widget (Glassmorphism)
  Widget _buildCardBase(ThemeData theme, {required Widget child}) {
    return AspectRatio(
      aspectRatio: 3/4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withOpacity(0.2),
              borderRadius: BorderRadius.circular(24.r),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}