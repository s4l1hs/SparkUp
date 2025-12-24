
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/analysis_provider.dart';
import '../widgets/morphing_gradient_button.dart';
import '../widgets/animated_glass_card.dart';
import 'package:sparkup_app/utils/color_utils.dart';


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
  bool _isQuizActive = false;

  // Timer değişkenleri
  Timer? _timer;
  int _timeLeft = 60; // 60 saniye süre

  // Animasyon kontrolcüleri (background blobs)
  late final AnimationController _backgroundController;
  late final Animation<Alignment> _backgroundAnimation1, _backgroundAnimation2;

  @override
  void initState() {
    super.initState();
    _backgroundController = AnimationController(vsync: this, duration: const Duration(seconds: 25))..repeat(reverse: true);
    _backgroundAnimation1 = TweenSequence<Alignment>([
      TweenSequenceItem(tween: AlignmentTween(begin: Alignment.topLeft, end: Alignment.bottomRight), weight: 1),
      TweenSequenceItem(tween: AlignmentTween(begin: Alignment.bottomRight, end: Alignment.topLeft), weight: 1),
    ]).animate(_backgroundController);
    _backgroundAnimation2 = TweenSequence<Alignment>([
      TweenSequenceItem(tween: AlignmentTween(begin: Alignment.topRight, end: Alignment.bottomLeft), weight: 1),
      TweenSequenceItem(tween: AlignmentTween(begin: Alignment.bottomLeft, end: Alignment.topRight), weight: 1),
    ]).animate(_backgroundController);

    _loadQuestions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _backgroundController.dispose();
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
      // Do not auto-start the session; user will start via Start button
    } catch (e) {
      debugPrint("Hata: manual true/false yüklenemedi: $e");
      setState(() => _isLoading = false);
    }
  }

  // --- 2. ZAMANLAYICI ---
  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        _timer?.cancel();
        await _handleQuizCompletion();
      }
    });
  }

  // --- 3. OYUN MANTIĞI ---
  Future<void> _answerQuestion(bool userSaidTrue) async {
    final currentQ = _questions[_currentIndex];
    final bool isCorrectAnswer = currentQ['correct_answer'];

    bool isUserCorrect = (userSaidTrue == isCorrectAnswer);

    if (isUserCorrect) {
      _score += 10 + (_streak * 2);
      _streak++;
    } else {
      _streak = 0;
    }

    // Notify analysis provider to refresh immediately after an answer
    try {
      final analysisProv = Provider.of<AnalysisProvider>(context, listen: false);
      analysisProv.refresh(widget.idToken);
    } catch (_) {}

    if (_currentIndex < _questions.length - 1) {
      setState(() => _currentIndex++);
    } else {
      await _handleQuizCompletion();
    }
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

    

    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: Center(child: Text('No true/false questions available', style: TextStyle(color: theme.colorScheme.onSurface))),
      );
    }

    // question display handled inside _buildQuizView via _currentQuestionText()

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          // animated ambient blobs
          AnimatedBuilder(
            animation: _backgroundController,
            builder: (context, child) {
              return Stack(
                children: [
                  Positioned.fill(
                    child: Align(
                      alignment: _backgroundAnimation1.value,
                      child: Container(
                        width: 400.w,
                        height: 400.h,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [colorWithOpacity(theme.colorScheme.secondary, 0.14), Colors.transparent]),
                          boxShadow: [BoxShadow(color: colorWithOpacity(theme.colorScheme.secondary, 0.06), blurRadius: 100.r, spreadRadius: 80.r)],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Align(
                      alignment: _backgroundAnimation2.value,
                      child: Container(
                        width: 300.w,
                        height: 300.h,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [colorWithOpacity(theme.colorScheme.primary, 0.12), Colors.transparent]),
                          boxShadow: [BoxShadow(color: colorWithOpacity(theme.colorScheme.primary, 0.05), blurRadius: 100.r, spreadRadius: 60.r)],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 420),
              child: !_isQuizActive ? _buildStartView(theme) : _buildQuizView(theme),
            ),
          ),
        ],
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

  // --- New: Start view and Quiz UI for True/False (button-driven) ---
  Widget _buildStartView(ThemeData theme) {
    return Center(
      key: const ValueKey('startView'),
      child: _isLoading
          ? CircularProgressIndicator(color: theme.colorScheme.primary)
          : MorphingGradientButton.icon(
              icon: Icon(Icons.play_arrow_rounded, size: 22.sp, color: Colors.white),
              label: Text('Start True/False', style: TextStyle(fontSize: 18.sp)),
              colors: [theme.colorScheme.secondary, theme.colorScheme.primary],
              onPressed: _startSession,
              padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 14.h),
            ),
    );
  }

  Widget _buildQuizView(ThemeData theme) {
    final progressValue = ((_currentIndex + 1) / (_questions.isNotEmpty ? _questions.length : 1)).clamp(0.0, 1.0);
    return Padding(
      key: ValueKey<int>(_currentIndex),
      padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 24.h),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8.r),
            child: LinearProgressIndicator(
              value: progressValue,
              minHeight: 8.h,
              backgroundColor: colorWithOpacity(theme.colorScheme.surface, 0.08),
              valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
            ),
          ),
          SizedBox(height: 10.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoChip(Icons.timer, '$_timeLeft s', _timeLeft < 10 ? Colors.red : theme.colorScheme.primary),
              Text("Streak: $_streak 🔥", style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: Colors.orange)),
              _buildInfoChip(Icons.star, '$_score', theme.colorScheme.secondary),
            ],
          ),
          SizedBox(height: 12.h),
          Flexible(
            fit: FlexFit.loose,
            child: Align(
              alignment: Alignment.topCenter,
              child: AnimatedGlassCard(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 16.h),
                borderRadius: BorderRadius.circular(16.r),
                child: SizedBox(
                  height: 220.h,
                  child: Center(child: Text(_currentQuestionText(), textAlign: TextAlign.center, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, height: 1.25))),
                ),
              ),
            ),
          ),
          SizedBox(height: 18.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(child: _buildTFButton(Icons.check, Colors.green, 'TRUE', () => _answerQuestion(true))),
              SizedBox(width: 16.w),
              Expanded(child: _buildTFButton(Icons.close, Colors.red, 'FALSE', () => _answerQuestion(false))),
            ],
          ),
        ],
      ),
    );
  }

  String _currentQuestionText() {
    if (_questions.isEmpty || _currentIndex >= _questions.length) return '';
    final q = _questions[_currentIndex];
    return q['question'] is Map ? (q['question']['en'] ?? q['question'].values.first) : (q['question'] ?? '');
  }

  Widget _buildTFButton(IconData icon, Color color, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64.h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.r),
          color: color,
          boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8.r, offset: const Offset(0, 4))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [Icon(icon, color: Colors.white), SizedBox(width: 12.w), Text(label, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18.sp))],
        ),
      ),
    );
  }

  void _startSession() {
    if (_questions.isEmpty) {
      _loadQuestions();
    }
    setState(() {
      _currentIndex = 0;
      _score = 0;
      _streak = 0;
      _timeLeft = 60;
      _isQuizActive = true;
    });
    _startTimer();
  }

  Future<void> _handleQuizCompletion() async {
    _timer?.cancel();
    final theme = Theme.of(context);
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text('Quiz finished', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
        content: Text("Your score: $_score", style: TextStyle(fontSize: 18.sp, color: theme.colorScheme.onSurface)),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Great', style: TextStyle(color: theme.colorScheme.primary)))],
      ),
    );
    if (mounted) {
      await _loadQuestions();
      setState(() => _isQuizActive = false);
    }
  }

}