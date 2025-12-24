
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:sparkup_app/l10n/app_localizations.dart';
import '../providers/user_provider.dart';
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
  bool _isLoading = false;
  bool _isQuizActive = false;

  // Timer değişkenleri
  Timer? _timer;
  int _timeLeft = 60; // 60 saniye süre
  int _sessionDuration = 60;

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

    // Do not pre-load questions here because the backend now consumes 1 energy per session
    // when `/manual/truefalse/` is requested. Questions will be loaded when the user starts a session.
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
      // Rethrow so the caller (_startSession) can handle the failure
      rethrow;
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

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
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

    

    // If questions are empty but user hasn't started a session yet, show start view.
    // Only show the 'no questions' message when a session is active but nothing loaded.
    if (_isQuizActive && _questions.isEmpty) {
      final loc = AppLocalizations.of(context);
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(loc?.noDataAvailable ?? 'No data available', textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16.sp)),
                SizedBox(height: 12.h),
                Text(loc?.quizCouldNotStart ?? 'Quiz could not start', textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7), fontSize: 14.sp)),
                SizedBox(height: 18.h),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isQuizActive = false;
                      _questions = [];
                    });
                  },
                  child: Text(loc?.cancel ?? 'Back'),
                ),
              ],
            ),
          ),
        ),
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
          : Builder(builder: (c) {
              final userProv = Provider.of<UserProvider>(c, listen: false);
              final rem = userProv.profile?.remainingEnergy;
              final loc = AppLocalizations.of(c);
              final bool disabled = rem != null && rem <= 0;
              final maxLabelWidth = MediaQuery.of(c).size.width * 0.65;
              return MorphingGradientButton.icon(
                icon: Icon(Icons.play_arrow_rounded, size: 26.sp, color: Colors.white),
                label: SizedBox(
                  width: maxLabelWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        loc?.startTrueFalseProblems ?? 'Start True/False Problems',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10.r)),
                            child: Row(children: [Icon(Icons.bolt, color: Colors.yellow.shade200, size: 16.sp), SizedBox(width: 6.w), Text('1 energy', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
                          ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        loc?.trueFalseTitle ?? '',
                        style: TextStyle(fontSize: 12.sp, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                colors: disabled ? [Colors.grey.shade600, Colors.grey.shade500] : [theme.colorScheme.secondary, theme.colorScheme.primary],
                onPressed: () {
                  if (disabled) {
                    final loc = AppLocalizations.of(context);
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(loc?.limitExceeded ?? 'Limit Exceeded'),
                        content: Text(loc?.limitExceeded ?? 'You do not have enough energy to start.'),
                        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(loc?.cancel ?? 'OK'))],
                      ),
                    );
                    return;
                  }
                  _startSession();
                },
                padding: EdgeInsets.symmetric(horizontal: 36.w, vertical: 18.h),
              );
            }),
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
          SizedBox(height: 8.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(6.r),
            child: LinearProgressIndicator(
              value: _sessionDuration > 0 ? (_timeLeft / _sessionDuration).clamp(0.0, 1.0) : 0.0,
              minHeight: 6.h,
              backgroundColor: colorWithOpacity(theme.colorScheme.surface, 0.06),
              valueColor: AlwaysStoppedAnimation(theme.colorScheme.tertiary),
            ),
          ),
          SizedBox(height: 10.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoChip(Icons.timer, '$_timeLeft s', _timeLeft < 10 ? Colors.red : theme.colorScheme.primary),
              Flexible(
                child: Center(
                  child: Text(
                    '${AppLocalizations.of(context)?.streak ?? 'Streak'}: $_streak 🔥',
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: Colors.orange),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
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
    final raw = q['question'];
    if (raw == null) return '';
    // determine current app language
    String lang = 'en';
    try {
      lang = Localizations.localeOf(context).languageCode;
    } catch (_) {}

    if (raw is Map) {
      // prefer exact language, then english, then first available
      if (raw.containsKey(lang) && (raw[lang] ?? '').toString().trim().isNotEmpty) {
        return raw[lang].toString();
      }
      if (raw.containsKey('en') && (raw['en'] ?? '').toString().trim().isNotEmpty) {
        return raw['en'].toString();
      }
      // fallback to first non-empty value
      for (final v in raw.values) {
        if (v != null && v.toString().trim().isNotEmpty) return v.toString();
      }
      return '';
    }
    return raw.toString();
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
    setState(() {
      _currentIndex = 0;
      _score = 0;
      _streak = 0;
      _isQuizActive = true;
      _isLoading = true;
    });

    // Load questions from server (this call will consume 1 energy on the backend)
    _loadQuestions().then((_) {
      final userProv = Provider.of<UserProvider>(context, listen: false);
      final secFromProfile = userProv.profile?.sessionSeconds;
      int sec = secFromProfile ?? 60;
      if (_questions.isNotEmpty) {
        final first = _questions.firstWhere((e) => e.containsKey('session_seconds'), orElse: () => null);
        if (first != null && first['session_seconds'] is int) sec = first['session_seconds'] as int;
      }
      setState(() {
        _timeLeft = sec;
        _sessionDuration = sec;
        _isLoading = false;
      });
      _cancelTimer();
      _startTimer();
    }).catchError((e) {
      setState(() {
        _isLoading = false;
        _isQuizActive = false;
      });
      // Show a user-friendly dialog for rate-limit / energy errors
      if (mounted) {
        final loc = AppLocalizations.of(context);
        final msg = e?.toString() ?? '';
        final bool isLimitErr = e is QuizLimitException || msg.toLowerCase().contains('429') || msg.toLowerCase().contains('limit');
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (ctx) => AlertDialog(
            backgroundColor: Theme.of(ctx).colorScheme.surface,
            title: Text(
              isLimitErr ? (loc?.limitExceeded ?? 'Limit Exceeded') : (loc?.error ?? 'Error'),
              style: TextStyle(color: Theme.of(ctx).colorScheme.primary, fontWeight: FontWeight.bold),
            ),
            content: Text(
              isLimitErr
                  ? (loc?.limitExceeded ?? 'You have reached your session limit. Please upgrade or wait until your energy resets.')
                  : (loc?.quizCouldNotStart ?? 'Could not start quiz. Please try again later.'),
              style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(loc?.cancel ?? 'OK')),
            ],
          ),
        );
      }
    });
  }

  Future<void> _handleQuizCompletion() async {
    _cancelTimer();
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