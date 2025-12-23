
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../services/api_service.dart';


class TrueFalsePage extends StatefulWidget {
  final String idToken;
  const TrueFalsePage({super.key, required this.idToken});

  @override
  State<TrueFalsePage> createState() => _TrueFalsePageState();
}

class _TrueFalsePageState extends State<TrueFalsePage> with TickerProviderStateMixin {
  List<dynamic> _questions = [];
  int _currentIndex = 0;
  int _score = 0;
  int _streak = 0; // Üst üste doğru sayısı
  bool _isLoading = true;
  bool _isGameOver = false;

  // Kart kaydırma pozisyonu (opsiyonel, swipe animasyonu için)
  Offset _dragOffset = Offset.zero;

  // Timer değişkenleri
  Timer? _timer;
  int _timeLeft = 60; // 60 saniye süre

  // Animasyon kontrolcüleri (Kart kaydırma efekti için)
  late AnimationController _swipeController;

  @override
  void initState() {
    super.initState();
    _swipeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _loadQuestions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _swipeController.dispose();
    super.dispose();
  }

  // --- 1. JSON YÜKLEME (DATA KLASÖRÜNDEN) ---
  Future<void> _loadQuestions() async {
    setState(() => _isLoading = true);
    try {
      final api = ApiService();
      final list = await api.getManualTrueFalse(idToken: widget.idToken);
      final data = list.isNotEmpty ? List<dynamic>.from(list) : <dynamic>[];
      if (data.isNotEmpty) data.shuffle();
      setState(() {
        _questions = data;
        _isLoading = false;
      });
      if (_questions.isNotEmpty) _startTimer();
    } catch (e) {
      debugPrint("Hata: manual true/false yüklenemedi: $e");
      setState(() => _isLoading = false);
    }
  }

  // --- 2. ZAMANLAYICI ---
  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        _endGame();
      }
    });
  }

  // --- 3. OYUN MANTIĞI ---
  void _handleSwipe(bool userSaidTrue) {
    final currentQ = _questions[_currentIndex];
    final bool isCorrectAnswer = currentQ['correct_answer'];
    
    // Kullanıcının cevabı doğru mu?
    // userSaidTrue (Evet dedi) == isCorrectAnswer (Cevap Evet) -> Doğru
    bool isUserCorrect = (userSaidTrue == isCorrectAnswer);

    if (isUserCorrect) {
      _score += 10 + (_streak * 2); // Streak bonusu
      _streak++;
    } else {
      _streak = 0; // Hata yapınca seri bozulur
      // İstersen yanlış yapınca süreden düşebilirsin: _timeLeft -= 5;
    }

    // Sonraki soruya geç
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _dragOffset = Offset.zero; // Kartı merkeze getir
      });
    } else {
      _endGame(); // Sorular bitti
    }
  }

  void _endGame() {
    _timer?.cancel();
    setState(() => _isGameOver = true);
    
    // Sonuçları Provider'a kaydet (Opsiyonel)
    // Provider.of<AnalysisProvider>(context, listen: false).addResult(...);
  }

  // --- 4. UI: KART YAPISI ---
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
      );
    }

    if (_isGameOver) {
      return _buildGameOverScreen(theme);
    }

    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: Center(child: Text('No true/false questions available', style: TextStyle(color: theme.colorScheme.onSurface))),
      );
    }

    final currentQuestion = _questions[_currentIndex];
    
    // Çoklu dil desteği (Varsayılan EN, yoksa ilk dili al)
    // JSON yapısı: "question": { "en": "...", "tr": "..." }
    // Burada basitçe 'en' alıyoruz, cihaz diline göre 'tr' vb. seçebilirsin.
    final questionText = currentQuestion['question']['en'] ?? currentQuestion['question'].values.first;
    final category = currentQuestion['category'] ?? 'General';

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Üst Bar: Süre ve Skor
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildInfoChip(Icons.timer, '$_timeLeft s', _timeLeft < 10 ? Colors.red : theme.colorScheme.primary),
                  Text("Streak: $_streak 🔥", style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: Colors.orange)),
                  _buildInfoChip(Icons.star, '$_score', theme.colorScheme.secondary),
                ],
              ),
            ),
            
            Spacer(),

            // --- SWIPE ALANI ---
            // Draggable widget kullanarak manuel swipe yapıyoruz
            // Stack kullanarak arkadaki kartı da gösterebilirsin (derinlik hissi için)
            SizedBox(
              height: 0.5.sh,
              width: 0.85.sw,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Arkadaki Kart (Gelecek soru - Sadece görsel dekor)
                  if (_currentIndex < _questions.length - 1)
                    Transform.scale(
                      scale: 0.9,
                      child: Opacity(
                        opacity: 0.6,
                        child: _buildCardContent(theme, "Next Question...", "...", Colors.grey[300]!),
                      ),
                    ),
                  
                  // Öndeki Kart (Aktif Soru)
                  Dismissible(
                    key: ValueKey(_currentIndex),
                    direction: DismissDirection.horizontal,
                    onDismissed: (direction) {
                      bool isRightSwipe = direction == DismissDirection.startToEnd;
                      _handleSwipe(isRightSwipe); // Sağ: True, Sol: False
                    },
                    background: _buildSwipeBackground(true), // Sağ Arka Plan (Yeşil/True)
                    secondaryBackground: _buildSwipeBackground(false), // Sol Arka Plan (Kırmızı/False)
                    child: _buildCardContent(theme, category, questionText, theme.cardColor),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 30.h),

            // Kontrol Butonları (Swipe yapmak istemeyenler için)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildActionButton(Icons.close, Colors.red, () => _manualSwipe(false)),
                  Text("OR", style: TextStyle(color: Colors.grey, fontSize: 12.sp)),
                  _buildActionButton(Icons.check, Colors.green, () => _manualSwipe(true)),
                ],
              ),
            ),
            
            Spacer(),
            
            Text(
              "Swipe Right for TRUE, Left for FALSE",
              style: TextStyle(color: Colors.grey[500], fontSize: 12.sp),
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }

  // Dismissible ile manuel tetikleme zor olduğu için butonlar bir sonraki karta geçişi simüle eder
  // Burada basitçe fonksiyonu çağırıyoruz, Dismissible animasyonu olmadan geçer.
  // Animasyonlu yapmak istersen Dismissible yerine Draggable kullanmak gerekir.
  void _manualSwipe(bool value) {
    _handleSwipe(value);
  }

  Widget _buildCardContent(ThemeData theme, String category, String text, Color bgColor) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, 8)),
        ],
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Text(category.toUpperCase(), style: TextStyle(color: theme.colorScheme.primary, fontSize: 12.sp, fontWeight: FontWeight.bold)),
          ),
          SizedBox(height: 24.h),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface, height: 1.3),
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeBackground(bool isTrue) {
    return Container(
      decoration: BoxDecoration(
        color: isTrue ? Colors.green.withOpacity(0.8) : Colors.red.withOpacity(0.8),
        borderRadius: BorderRadius.circular(24.r),
      ),
      alignment: isTrue ? Alignment.centerLeft : Alignment.centerRight,
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Icon(
        isTrue ? Icons.check_circle_outline : Icons.cancel_outlined,
        color: Colors.white,
        size: 40.sp,
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18.sp),
          SizedBox(width: 6.w),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16.sp)),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64.w,
        height: 64.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, offset: Offset(0, 4))],
          border: Border.all(color: color.withOpacity(0.1), width: 2),
        ),
        child: Icon(icon, color: color, size: 32.sp),
      ),
    );
  }

  Widget _buildGameOverScreen(ThemeData theme) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events, size: 80.sp, color: Colors.amber),
            SizedBox(height: 20.h),
            Text("Time's Up!", style: TextStyle(fontSize: 28.sp, fontWeight: FontWeight.bold)),
            SizedBox(height: 10.h),
            Text("Final Score", style: TextStyle(color: Colors.grey)),
            Text("$_score", style: TextStyle(fontSize: 48.sp, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
            SizedBox(height: 30.h),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 15.h),
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: Text("Back to Menu"),
            )
          ],
        ),
      ),
    );
  }
}