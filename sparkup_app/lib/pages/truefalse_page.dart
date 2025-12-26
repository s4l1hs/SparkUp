import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/analysis_provider.dart';
import '../services/api_service.dart';
import '../l10n/app_localizations.dart';
import '../widgets/animated_glass_card.dart';
import '../widgets/morphing_gradient_button.dart';
import '../utils/color_utils.dart';

class TrueFalsePage extends StatefulWidget {
  final String idToken;
  const TrueFalsePage({super.key, required this.idToken});

  @override
  State<TrueFalsePage> createState() => _TrueFalsePageState();
}

class _TrueFalsePageState extends State<TrueFalsePage>
  with TickerProviderStateMixin {
  bool _isLoading = false;
  bool _isQuizActive = false;
  Timer? _timer;
  List<dynamic> _questions = [];
  int _currentIndex = 0;
  int _score = 0;
  int _streak = 0;
  int _wrongCount = 0;
  bool _processingAnswer = false;
  bool _sessionEnding = false;
  // Session token used to invalidate in-flight fetches when a session ends.
  int _sessionToken = 0;
  bool _forceEnded = false;
  bool _showFeedback = false;
  bool _lastAnswerCorrect = false;
  late final AnimationController _feedbackAnimController;
  int _timeLeft = 0;
  int _sessionDuration = 60;

  late final AnimationController _backgroundController;
  late final Animation<Alignment> _backgroundAnimation1;
  late final Animation<Alignment> _backgroundAnimation2;

  @override
  void initState() {
    super.initState();
    _backgroundController =
        AnimationController(vsync: this, duration: const Duration(seconds: 25))
          ..repeat(reverse: true);
    _backgroundAnimation1 = TweenSequence<Alignment>([
      TweenSequenceItem(
          tween: AlignmentTween(
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          weight: 1),
      TweenSequenceItem(
          tween: AlignmentTween(
              begin: Alignment.bottomRight, end: Alignment.topLeft),
          weight: 1),
    ]).animate(_backgroundController);
    _backgroundAnimation2 = TweenSequence<Alignment>([
      TweenSequenceItem(
          tween: AlignmentTween(
              begin: Alignment.topRight, end: Alignment.bottomLeft),
          weight: 1),
      TweenSequenceItem(
          tween: AlignmentTween(
              begin: Alignment.bottomLeft, end: Alignment.topRight),
          weight: 1),
    ]).animate(_backgroundController);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Intentionally left blank; do not auto-start the session here.
    });
    _feedbackAnimController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _backgroundController.dispose();
    _feedbackAnimController.dispose();
    super.dispose();
  }

  // --- 1. JSON YÜKLEME (DATA KLASÖRÜNDEN) ---
  Future<void> _loadQuestions() async {
    setState(() => _isLoading = true);
    // Capture localization and user provider before any awaits to avoid using BuildContext across async gaps
    final loc = AppLocalizations.of(context);
    final userProvNow = Provider.of<UserProvider>(context, listen: false);
    final int token = _sessionToken;
    try {
      final api = ApiService();
      final list = await api.getManualTrueFalse(idToken: widget.idToken);
      final data = list.isNotEmpty ? List<dynamic>.from(list) : <dynamic>[];
      if (data.isNotEmpty) data.shuffle();
      // If session is ending or not active anymore, or token invalidated, discard fetched data
      if (_sessionEnding || !_isQuizActive || token != _sessionToken || _wrongCount >= 3 || _forceEnded) {
        setState(() => _isLoading = false);
        return;
      }
      setState(() {
        _questions = data;
        _isLoading = false;
      });
      // Do not auto-start the session; user will start via Start button
    } catch (e) {
      debugPrint("Hata: manual true/false yüklenemedi: $e");
      setState(() {
        _isLoading = false;
        _questions = [];
      });

      // Prepare dialog text before showing dialog
      final bool isLimitErr = (userProvNow.profile?.remainingEnergy ?? 0) <= 0;

      // Try to refresh user profile to correct optimistic energy changes
      try {
        await userProvNow.loadProfile(widget.idToken);
      } catch (_) {}

      // Show a user-friendly dialog (limit or generic) without throwing further
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (ctx) => AlertDialog(
            title: Text(isLimitErr
                ? (loc?.insufficientEnergy ?? 'Insufficient energy ⚡')
                : (loc?.error ?? 'Error')),
            content: Text(isLimitErr
                ? (loc?.insufficientEnergy ?? 'Insufficient energy ⚡')
                : (loc?.quizCouldNotStart ?? 'Could not load questions.')),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(loc?.cancel ?? 'OK'))
            ],
          ),
        );
      }
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
    if (!_isQuizActive || _processingAnswer || _sessionEnding) return;
    setState(() => _processingAnswer = true);

    try {
      final currentQ = _questions[_currentIndex];
      // Cevap kontrolü (Mevcut kodun aynısı)
      bool isCorrectAnswer;
      final rawCorrect = currentQ['correct_answer'];
      if (rawCorrect is bool) {
        isCorrectAnswer = rawCorrect;
      } else if (rawCorrect is String) {
        final lc = rawCorrect.toLowerCase().trim();
        isCorrectAnswer = (lc == 'true' || lc == '1' || lc == 't');
      } else if (rawCorrect is num) {
        isCorrectAnswer = rawCorrect.toInt() != 0;
      } else {
        isCorrectAnswer = false;
      }

      final bool isUserCorrect = (userSaidTrue == isCorrectAnswer);
      bool isGameOver = false;

      // Puanlama ve Yanlış Kontrolü
      if (isUserCorrect) {
        setState(() {
          _score += 10 + (_streak * 2);
          _streak++;
        });
      } else {
        setState(() {
          _streak = 0;
          _wrongCount++;
        });
        
        // 3. Yanlışı yaptığı an isGameOver TRUE oluyor
        if (_wrongCount >= 3) {
          isGameOver = true;
        }
      }

      // 1. ÖNCE Feedback Göster (Kullanıcı ekranda dev kırmızı çarpıyı görsün)
      _lastAnswerCorrect = isUserCorrect;
      setState(() => _showFeedback = true);
      try {
        _feedbackAnimController.forward(from: 0);
      } catch (_) {}

      // 2. EĞER OYUN BİTTİYSE:
      if (isGameOver) {
        // Kullanıcının "Hata yaptım" ekranını algılaması için çok kısa (0.6sn) bekle
        // Bunu kaldırırsan kullanıcı ne olduğunu anlamadan popup çıkar, bu süre iyidir.
        await Future.delayed(const Duration(milliseconds: 600)); 
        
        if (mounted) setState(() => _showFeedback = false); // Kırmızı ekranı kaldır
        
        if (!_forceEnded) _forceEnded = true;
        await _endSessionNow(); // VE ANINDA BİTİR (Soru geçişi yapma)
        return; 
      }

      // Oyun bitmediyse feedback süresi kadar bekle ve devam et
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) setState(() => _showFeedback = false);

      // Analysis provider güncellemesi
      try {
        if (mounted) {
          final analysisProv = Provider.of<AnalysisProvider>(context, listen: false);
          analysisProv.refresh(widget.idToken);
        }
      } catch (_) {}

      // Bir sonraki soruya geçiş
      if (_currentIndex < _questions.length - 1) {
        setState(() => _currentIndex++);
      } else {
        try {
          await _fetchMoreQuestionsTF();
        } catch (e) {
          await _handleQuizCompletion();
        }
      }
    } finally {
      if (mounted) setState(() => _processingAnswer = false);
    }
  }

  Future<void> _endSessionNow() async {
    // Mark session as ending and invalidate any in-flight fetches.
    _sessionToken++;
    _forceEnded = true;
    if (!_sessionEnding) {
      setState(() => _sessionEnding = true);
    }
    setState(() {
      _isQuizActive = false;
    });
    _cancelTimer();
    try {
      await _handleQuizCompletion();
    } finally {
      if (mounted) setState(() => _sessionEnding = false);
    }
  }

  Future<void> _fetchMoreQuestionsTF() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final userProv = Provider.of<UserProvider>(context, listen: false);
    final int token = _sessionToken;
    try {
      final api = ApiService();
      final list = await api.getManualTrueFalse(idToken: widget.idToken);
      final data = list.isNotEmpty ? List<dynamic>.from(list) : <dynamic>[];
      if (data.isNotEmpty) data.shuffle();
      if (!mounted) return;
      // If session ended while fetching, token invalidated, or 3 wrongs reached, do not apply fetched questions
      if (_sessionEnding || !_isQuizActive || token != _sessionToken || _wrongCount >= 3 || _forceEnded) {
        setState(() => _isLoading = false);
        return;
      }
      setState(() {
        _questions = data;
        _currentIndex = 0;
        _isLoading = false;
      });

      // Reset/continue timer using profile/session seconds
      final secFromProfile = userProv.profile?.sessionSeconds;
      int sec = secFromProfile ?? 60;
      if (_questions.isNotEmpty) {
        final first = _questions.firstWhere(
            (e) => e.containsKey('session_seconds'),
            orElse: () => null);
        if (first != null && first['session_seconds'] is int)
          sec = first['session_seconds'] as int;
      }
      setState(() {
        _timeLeft = sec;
        _sessionDuration = sec;
      });
      _cancelTimer();
      _startTimer();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      rethrow;
    }
  }

  // --- 4. UI: KART YAPISI ---
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: Center(
            child: CircularProgressIndicator(color: theme.colorScheme.primary)),
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
                Text(loc?.noDataAvailable ?? 'No data available',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: theme.colorScheme.onSurface, fontSize: 16.sp)),
                SizedBox(height: 12.h),
                Text(loc?.quizCouldNotStart ?? 'Quiz could not start',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color:
                            colorWithOpacity(theme.colorScheme.onSurface, 0.7),
                        fontSize: 14.sp)),
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
                          gradient: RadialGradient(colors: [
                            colorWithOpacity(theme.colorScheme.secondary, 0.14),
                            Colors.transparent
                          ]),
                          boxShadow: [
                            BoxShadow(
                                color: colorWithOpacity(
                                    theme.colorScheme.secondary, 0.06),
                                blurRadius: 100.r,
                                spreadRadius: 80.r)
                          ],
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
                          gradient: RadialGradient(colors: [
                            colorWithOpacity(theme.colorScheme.primary, 0.12),
                            Colors.transparent
                          ]),
                          boxShadow: [
                            BoxShadow(
                                color: colorWithOpacity(
                                    theme.colorScheme.primary, 0.05),
                                blurRadius: 100.r,
                                spreadRadius: 60.r)
                          ],
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
              child: !_isQuizActive
                  ? _buildStartView(theme)
                  : _buildQuizView(theme),
            ),
          ),
          // --- TRUE/FALSE PAGE FEEDBACK (COMBO MODU) ---
          if (_showFeedback)
            Positioned.fill(
              child: Stack(
                children: [
                  // 1. Arka Plan
                  BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                    child: Container(
                      color: _lastAnswerCorrect
                          ? Colors.green.withAlpha(38)
                          : Colors.red.withAlpha(38),
                    ),
                  ),
                  
                  // 2. Animasyonlu İçerik
                  Center(
                    child: AnimatedBuilder(
                      animation: _feedbackAnimController,
                      builder: (context, child) {
                        final double animValue =
                            CurvedAnimation(parent: _feedbackAnimController, curve: Curves.elasticOut).value;
                        final double opacityValue = 
                            CurvedAnimation(parent: _feedbackAnimController, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)).value;

                        // Başlık Mantığı
                        String titleText;
                        if (!_lastAnswerCorrect) {
                          titleText = AppLocalizations.of(context)?.incorrect ?? 'OOPS!';
                        } else if (_streak >= 2) {
                          titleText = AppLocalizations.of(context)?.unstoppable ?? 'UNSTOPPABLE 🔥';
                        } else {
                          titleText = AppLocalizations.of(context)?.correct ?? 'AWESOME!';
                        }

                        return Opacity(
                          opacity: opacityValue,
                          child: Transform.scale(
                            scale: 0.5 + (animValue * 0.5),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 30.h),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface.withAlpha(243),
                                borderRadius: BorderRadius.circular(30.r),
                                border: Border.all(
                                  color: _lastAnswerCorrect 
                                    ? (_streak >= 2 ? Colors.orange : Colors.green.withAlpha(128)) 
                                    : Colors.red.withAlpha(128),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _lastAnswerCorrect 
                                      ? (_streak >= 2 ? Colors.orange.withAlpha(153) : Colors.green.withAlpha(153)) 
                                      : Colors.red.withAlpha(153),
                                    blurRadius: 40,
                                    spreadRadius: 5,
                                  ),
                                  const BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 20,
                                    offset: Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // İkon
                                  Container(
                                    padding: EdgeInsets.all(16.r),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _lastAnswerCorrect ? Colors.green.withAlpha(26) : Colors.red.withAlpha(26),
                                    ),
                                    child: Icon(
                                      _lastAnswerCorrect
                                          ? (_streak >= 2 ? Icons.whatshot : Icons.check_rounded)
                                          : Icons.close_rounded,
                                      size: 80.sp,
                                      color: _lastAnswerCorrect 
                                        ? (_streak >= 2 ? Colors.orange : Colors.greenAccent) 
                                        : Colors.redAccent,
                                    ),
                                  ),
                                  SizedBox(height: 20.h),
                                  
                                  // Ana Metin
                                  Text(
                                    titleText,
                                    style: TextStyle(
                                      color: _lastAnswerCorrect 
                                        ? (_streak >= 2 ? Colors.orange : Colors.green) 
                                        : Colors.red,
                                      fontSize: 28.sp,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  
                                  SizedBox(height: 8.h),

                                  // Alt Bilgi (Puan)
                                  if (_lastAnswerCorrect)
                                    Builder(builder: (ctx) {
                                      final pts = 10 + (_streak > 0 ? (_streak - 1) * 2 : 0);
                                      final localized = AppLocalizations.of(ctx)?.pointsGain(pts.toString());
                                      return Text(
                                        localized ?? '+$pts Points',
                                        style: TextStyle(
                                          color: theme.colorScheme.onSurface,
                                          fontSize: 20.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      );
                                    })
                                  else
                                    Builder(builder: (ctx) {
                                      final lives = 3 - _wrongCount;
                                      final localized = AppLocalizations.of(ctx)?.livesLeft(lives.toString());
                                      return Text(
                                        localized ?? '$lives lives left',
                                        style: TextStyle(
                                          color: theme.colorScheme.onSurface.withAlpha(153),
                                          fontSize: 16.sp,
                                        ),
                                      );
                                    }),

                                  // STREAK BONUS KUTUSU
                                  if (_lastAnswerCorrect && _streak > 1) 
                                    Container(
                                      margin: EdgeInsets.only(top: 12.h),
                                      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                                      decoration: BoxDecoration(
                                        color: Colors.deepOrange.withAlpha(26),
                                        borderRadius: BorderRadius.circular(12.r),
                                        border: Border.all(color: Colors.deepOrange.withAlpha(153)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.bolt, color: Colors.deepOrange, size: 18.sp),
                                          SizedBox(width: 4.w),
                                          Builder(builder: (ctx) {
                                            final localized = AppLocalizations.of(ctx)?.streakBonus(_streak.toString());
                                            return Text(
                                              localized ?? 'Streak Bonus x$_streak',
                                              style: TextStyle(
                                                color: Colors.deepOrange,
                                                fontSize: 16.sp,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            );
                                          }),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
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
        color: colorWithOpacity(color, 0.1),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18.sp),
          SizedBox(width: 6.w),
          Text(text,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 16.sp)),
        ],
      ),
    );
  }

  Widget _buildStartView(ThemeData theme) {
    final userProv = Provider.of<UserProvider>(context);
    final loc = AppLocalizations.of(context);
    final sessionSec = userProv.profile?.sessionSeconds ?? 60;

    return Align(
      alignment: const Alignment(0, -0.1), 
      key: const ValueKey('startView'),
      child: _isLoading
          ? CircularProgressIndicator(color: theme.colorScheme.primary)
          : TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, 30 * (1 - value)),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.w),
                      child: AnimatedGlassCard(
                        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 32.h),
                        borderRadius: BorderRadius.circular(28.r),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 1. İKON
                            AnimatedBuilder(
                              animation: _backgroundController,
                              builder: (context, child) {
                                final scale = 1.0 + (0.04 * (_backgroundAnimation1.value.x).abs());
                                return Transform.scale(
                                  scale: scale,
                                  child: Container(
                                    padding: EdgeInsets.all(22.r),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.orange.withAlpha(26),
                                      border: Border.all(color: Colors.orange.withAlpha(77), width: 1),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.orange.withAlpha(64),
                                          blurRadius: 30,
                                          spreadRadius: 8,
                                        )
                                      ],
                                    ),
                                    child: Icon(Icons.flaky_rounded, size: 52.sp, color: Colors.orangeAccent),
                                  ),
                                );
                              },
                            ),
                            SizedBox(height: 24.h),

                            // 2. BAŞLIK
                            Text(
                              loc?.startTrueFalseProblems ?? 'True or False?',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 26.sp,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.8,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              loc?.startTrueFalseSubtitle ?? 'Think fast and win 🔥',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),

                            SizedBox(height: 28.h),

                            // 3. DASHBOARD (YENİLENDİ: 3 CAN GÖSTERGESİ)
                            Container(
                              padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(51),
                                borderRadius: BorderRadius.circular(16.r),
                                border: Border.all(color: Colors.white.withAlpha(20)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  // Brain icon only (no text)
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.rocket_launch_rounded, color: Colors.orangeAccent, size: 22.sp),
                                    ],
                                  ),
                                  Container(width: 1, height: 24.h, color: Colors.white12),
                                  _buildDashboardItem(Icons.timer_outlined, "${sessionSec}${loc?.secondsSuffix ?? 's'}", Colors.greenAccent),
                                  Container(width: 1, height: 24.h, color: Colors.white12),
                                  
                                  // --- YENİ: YAZISIZ CAN GÖSTERGESİ ---
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Üst ikon
                                      Icon(Icons.favorite_border_rounded, color: Colors.redAccent, size: 22.sp),
                                      SizedBox(height: 6.h),
                                      // Alt görsel (3 tane dolu kalp)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.favorite, size: 12.sp, color: Colors.redAccent),
                                          SizedBox(width: 2.w),
                                          Icon(Icons.favorite, size: 12.sp, color: Colors.redAccent),
                                          SizedBox(width: 2.w),
                                          Icon(Icons.favorite, size: 12.sp, color: Colors.redAccent),
                                        ],
                                      )
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: 32.h),

                            // 4. BUTON
                            MorphingGradientButton.icon(
                              icon: Icon(Icons.play_arrow_rounded, size: 30.sp, color: Colors.white),
                              label: Text(
                                  loc?.startWithOneBolt ?? 'Start Game',
                                  style: TextStyle(fontSize: 19.sp, fontWeight: FontWeight.bold)),
                              colors: [Colors.orange, Colors.deepOrange],
                              onPressed: () {
                                final userProv = Provider.of<UserProvider>(context, listen: false);
                                final rem = userProv.profile?.remainingEnergy;
                                if (rem != null && rem <= 0) {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: Text(loc?.insufficientEnergy ?? 'Insufficient energy ⚡'),
                                      content: Text(loc?.insufficientEnergy ?? 'Insufficient energy ⚡'),
                                      actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(loc?.cancel ?? 'OK'))],
                                    ),
                                  );
                                  return;
                                }
                                _startSession();
                              },
                              padding: EdgeInsets.symmetric(horizontal: 56.w, vertical: 20.h),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildQuizView(ThemeData theme) {
    return Padding(
      key: ValueKey<int>(_currentIndex),
      padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 24.h),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6.r),
            child: LinearProgressIndicator(
              value: _sessionDuration > 0
                  ? (_timeLeft / _sessionDuration).clamp(0.0, 1.0)
                  : 0.0,
              minHeight: 6.h,
              backgroundColor:
                  colorWithOpacity(theme.colorScheme.surface, 0.06),
              valueColor: AlwaysStoppedAnimation(theme.colorScheme.tertiary),
            ),
          ),
          SizedBox(height: 10.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
                _buildInfoChip(Icons.timer, '$_timeLeft${AppLocalizations.of(context)?.secondsSuffix ?? 's'}',
                  _timeLeft < 10 ? Colors.red : theme.colorScheme.primary),
              Flexible(
                child: Center(
                  child: Text(
                    '${AppLocalizations.of(context)?.streak ?? 'Streak'}: $_streak 🔥',
                    style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              _buildInfoChip(
                  Icons.star, '$_score', theme.colorScheme.secondary),
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
                  child: Center(
                      child: Text(_currentQuestionText(),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900, height: 1.25))),
                ),
              ),
            ),
          ),
          SizedBox(height: 18.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
                Expanded(
                  child: _buildTFButton(Icons.check, Colors.green,
                    AppLocalizations.of(context)?.trueLabel ?? 'True', () {
                  if (!_isQuizActive || _processingAnswer || _sessionEnding || _forceEnded) return;
                  _answerQuestion(true);
                  })),
              SizedBox(width: 16.w),
                Expanded(
                  child: _buildTFButton(Icons.close, Colors.red,
                    AppLocalizations.of(context)?.falseLabel ?? 'False', () {
                  if (!_isQuizActive || _processingAnswer || _sessionEnding || _forceEnded) return;
                  _answerQuestion(false);
                  })),
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
      if (raw.containsKey(lang) &&
          (raw[lang] ?? '').toString().trim().isNotEmpty) {
        return raw[lang].toString();
      }
      if (raw.containsKey('en') &&
          (raw['en'] ?? '').toString().trim().isNotEmpty) {
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

  Widget _buildTFButton(
      IconData icon, Color color, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64.h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.r),
          color: color,
          boxShadow: [
            BoxShadow(
                color: colorWithOpacity(color, 0.3),
                blurRadius: 8.r,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            SizedBox(width: 12.w),
            Text(label,
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18.sp))
          ],
        ),
      ),
    );
  }

  // Dashboard item helper
  Widget _buildDashboardItem(IconData icon, String text, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 22.sp),
        SizedBox(height: 6.h),
        Text(text, style: TextStyle(color: Colors.white.withAlpha(230), fontSize: 13.sp, fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _startSession() {
    setState(() {
      _currentIndex = 0;
      _score = 0;
      _wrongCount = 0;
      _streak = 0;
      _isQuizActive = true;
      _isLoading = true;
    });
    // Invalidate any previous in-flight fetches and mark a new session token.
    _sessionToken++;
    _forceEnded = false;
    final userProv = Provider.of<UserProvider>(context, listen: false);
    final loc = AppLocalizations.of(context);
    // optimistic UI update: consume 1 energy locally
    userProv.consumeEnergyOptimistic();

    // Load questions from server (this call will consume 1 energy on the backend)
    _loadQuestions().then((_) {
      final secFromProfile = userProv.profile?.sessionSeconds;
      int sec = secFromProfile ?? 60;
      if (_questions.isNotEmpty) {
        final first = _questions.firstWhere(
            (e) => e.containsKey('session_seconds'),
            orElse: () => null);
        if (first != null && first['session_seconds'] is int)
          sec = first['session_seconds'] as int;
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
        // On error, refresh profile from server to correct optimistic change
        try {
          userProv.loadProfile(widget.idToken);
        } catch (_) {}
        final bool isLimitErr = (userProv.profile?.remainingEnergy ?? 0) <= 0;
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (ctx) => AlertDialog(
            backgroundColor: Theme.of(ctx).colorScheme.surface,
            title: Text(
              isLimitErr
                  ? (loc?.insufficientEnergy ?? 'Insufficient energy ⚡')
                  : (loc?.error ?? 'Error'),
              style: TextStyle(
                  color: Theme.of(ctx).colorScheme.primary,
                  fontWeight: FontWeight.bold),
            ),
            content: Text(
              isLimitErr
                  ? (loc?.insufficientEnergy ?? 'Insufficient energy ⚡')
                  : (loc?.quizCouldNotStart ??
                      'Could not start quiz. Please try again later.'),
              style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(loc?.cancel ?? 'OK')),
            ],
          ),
        );
      }
    });
  }

  Future<void> _handleQuizCompletion() async {
    _cancelTimer();
    
    // Oyunun neden bittiğini yakala (Süre mi bitti, Yanlış mı?)
    final bool isGameOverByLives = _wrongCount >= 3;

    // Quiz'i inaktif yap ama wrongCount'u henüz sıfırlama
    setState(() {
      _isQuizActive = false;
    });

    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context);

    // Dialog Başlığı ve İçeriğini duruma göre ayarla
    final String title = (loc?.quizFinished ?? 'Quiz Finished');
        
    final String message = "${loc?.yourScore ?? 'Your score'}: $_score";

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text(
            title,
            style: TextStyle(
                color: isGameOverByLives ? Colors.red : theme.colorScheme.primary, 
                fontWeight: FontWeight.bold)),
        content: Text(
            message,
            style: TextStyle(fontSize: 18.sp, color: theme.colorScheme.onSurface)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                  loc?.great ?? 'Great', // "Great" yerine OK daha uygun olabilir
                  style: TextStyle(color: theme.colorScheme.primary)))
        ],
      ),
    );

    if (mounted) {
      // Dialog kapandıktan sonra temizlik yap
      setState(() {
        _questions = [];
        _currentIndex = 0;
        _wrongCount = 0; // ŞİMDİ sıfırla
        _score = 0;
      });
    }
  }
}