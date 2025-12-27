// lib/pages/quiz_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/analysis_provider.dart';
import '../l10n/app_localizations.dart';
import '../widgets/animated_glass_card.dart';
import '../widgets/morphing_gradient_button.dart';
import '../services/api_service.dart';
import '../locale_provider.dart';
import '../utils/color_utils.dart';
import 'dart:ui' as ui;

enum AnswerState { unanswered, pending, revealed }

class QuizPage extends StatefulWidget {
  final String idToken;
  const QuizPage({super.key, required this.idToken});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _questions = [];
  int _currentIndex = 0, _sessionScore = 0;
  int? _selectedAnswerIndex;
  int? _pressedOptionIndex;
  late final AnimationController _backgroundController;
  late final Animation<Alignment> _backgroundAnimation1, _backgroundAnimation2;
  AnswerState _answerState = AnswerState.unanswered;

  // Feedback Animasyonu için değişkenler
  late final AnimationController _feedbackAnimController;
  bool _showFeedback = false;
  bool _lastAnswerCorrect = false;
  bool _isLoading = false;
  bool _isQuizActive = false;
  bool _answered = false;
  bool _localizeInProgress = false;
  final ApiService _apiService = ApiService();

  // Yeni: son kullanılan locale'i takip et
  String? _lastLocale;
  // Keep a reference to the locale provider so we can listen for changes
  LocaleProvider? _localeProviderRef;

  // score award animation
  late final AnimationController _scoreAnimController;
  late final Animation<Offset> _scoreOffset;
  int _lastAwarded = 0;
  bool _showAward = false;
  int _wrongAnswers = 0;
  // session timer
  Timer? _sessionTimer;

  // Timer state
  int _timeLeft = 0;
  int _sessionDuration = 0;

  void _startSessionTimer() {
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        _cancelSessionTimer();
        _handleQuizCompletion();
      }
    });
  }

  void _cancelSessionTimer() {
    try {
      _sessionTimer?.cancel();
    } catch (_) {}
    _sessionTimer = null;
  }

  @override
  void initState() {
    super.initState();
    _feedbackAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
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

    _scoreAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _scoreOffset =
        Tween<Offset>(begin: const Offset(0, 0.6), end: const Offset(0, -0.6))
            .animate(CurvedAnimation(
                parent: _scoreAnimController, curve: Curves.easeOut));
    _scoreAnimController.addStatusListener((st) {
      if (st == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() => _showAward = false);
          }
        });
      }
    });

    // Defer the initial fetch until after the first frame so inherited
    // widgets (Theme, Localizations, ScaffoldMessenger, Providers) are
    // available. Calling them from initState can cause the "dependOnInheritedWidgetOfExactType"
    // error in debug/dev builds.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Do not auto-start a quiz session on page load; fetch preview data only when needed.
      try {
        _localeProviderRef =
            Provider.of<LocaleProvider>(context, listen: false);
        _localeProviderRef?.addListener(_onLocaleChanged);
      } catch (_) {}
    });
  }

  // Choose effective language for API calls: prefer explicit user choice if supported,
  // otherwise use device/app locale if supported; finally fallback to 'en'.
  String _selectSupportedLanguage(String? userLang, String deviceLang,
      {required bool allowBackendEn}) {
    const supported = {
      'en',
      'tr',
      'de',
      'fr',
      'es',
      'it',
      'ru',
      'zh',
      'hi',
      'ja',
      'ar'
    };
    // Use backend/user language only if supported and either it's not 'en' or the user explicitly chose it
    if (userLang != null &&
        supported.contains(userLang) &&
        (allowBackendEn || userLang != 'en')) {
      return userLang;
    }
    if (supported.contains(deviceLang)) return deviceLang;
    return 'en';
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

  void _onLocaleChanged() {
    final localeCode = _localeProviderRef?.locale.languageCode;
    if (localeCode == null) return;
    if (_lastLocale == localeCode) return;
    _lastLocale = localeCode;
    if (!_isLoading &&
        _isQuizActive &&
        _questions.isNotEmpty &&
        !_localizeInProgress) {
      final ids = _questions.map((q) => q['id'] as int).toList();
      _localizeInProgress = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final localized = await _apiService
              .getLocalizedQuizQuestions(widget.idToken, ids, lang: localeCode);
          if (!mounted) return;
          if (localized.isNotEmpty) {
            setState(() {
              final Map<int, Map<String, dynamic>> byId = {
                for (var q in localized)
                  (q['id'] as int): Map<String, dynamic>.from(q)
              };
              _questions = _questions.map((q) {
                final id = q['id'] as int;
                final loc = byId[id];
                if (loc != null) {
                  return {
                    'id': id,
                    'question_text': loc['question_text'],
                    'options': List<dynamic>.from(loc['options'] as List),
                    'correct_answer_index': loc['correct_answer_index'],
                  };
                }
                return q;
              }).toList();
            });
          }
        } catch (e) {
          debugPrint("Failed to localize active quiz: $e");
        } finally {
          _localizeInProgress = false;
        }
      });
    } else {
      if (!_isLoading && !_isQuizActive) {
        WidgetsBinding.instance.addPostFrameCallback(
            (_) => _fetchQuizData(isInitialLoad: false, isPreview: true));
      }
    }
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _scoreAnimController.dispose();
    _feedbackAnimController.dispose();
    try {
      _sessionTimer?.cancel();
    } catch (_) {}
    try {
      _localeProviderRef?.removeListener(_onLocaleChanged);
    } catch (_) {}
    super.dispose();
  }

  Future<void> _fetchQuizData(
      {bool isInitialLoad = false, bool isPreview = false}) async {
    if (!mounted) return;
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    // Only refresh profile from server for initial/preview loads.
    // Preserve any local optimistic remainingEnergy when merging so the
    // UI never increases energy unexpectedly (for example after session end).
    if (isInitialLoad || isPreview) {
      final preserve = userProvider.profile?.remainingEnergy != null;
      await userProvider.loadProfile(widget.idToken,
          preserveRemainingEnergy: preserve);
    }
    setState(() {
      _isLoading = true;
    });
    try {
      final deviceLang = localeProvider.locale.languageCode;
      final lang = _selectSupportedLanguage(
          userProvider.profile?.languageCode, deviceLang,
          allowBackendEn: localeProvider.userSetLanguage);
      final questions = await _apiService.getQuizQuestions(widget.idToken,
          limit: 3, lang: lang, preview: isPreview, consume: !isPreview);
      if (!mounted) return;

      if (questions.isNotEmpty) {
        setState(() {
          _questions = questions
              .map((q) => Map<String, dynamic>.from(q as Map))
              .toList();
          final profile = userProvider.profile;
          _currentIndex = 0;
          // If this is a preview load (not starting a live session), show
          // the user's daily total; otherwise keep/reset session score
          _sessionScore = isPreview ? (profile?.dailyPoints ?? 0) : 0;
          _wrongAnswers = 0;
          _answered = false;
          _selectedAnswerIndex = null;
          _answerState = AnswerState.unanswered;
        });
        // set session timer from server hint or profile
        int sec = userProvider.profile?.sessionSeconds ?? 60;
        if (_questions.isNotEmpty &&
            _questions.first.containsKey('session_seconds')) {
          final s = _questions.first['session_seconds'];
          if (s is int) sec = s;
        }
        // If this fetch is a preview, do not start the session or timer. Actual session starts via _startQuizSession which calls _fetchQuizData with isPreview=false.
        if (!isPreview) {
          _cancelSessionTimer();
          setState(() {
            _timeLeft = sec;
            _sessionDuration = sec;
            _isQuizActive = true;
          });
          _startSessionTimer();
        }
      } else {
        setState(() {
          if (!isPreview) _isQuizActive = false;
        });
      }
    } catch (e) {
      final msg =
          localizations?.quizCouldNotStart ?? 'Quiz could not be started';
      if (mounted) {
        messenger.showSnackBar(SnackBar(
            content: Text("$msg: ${e.toString()}"),
            backgroundColor: theme.colorScheme.error));
        setState(() => _isQuizActive = false);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _startQuizSession() {
    _sessionScore = 0;
    final userProv = Provider.of<UserProvider>(context, listen: false);
    _wrongAnswers = 0;
    _fetchQuizData(isInitialLoad: false, isPreview: false).catchError((e) {
      // sync profile from server to correct optimistic change on error
      try {
        userProv.loadProfile(widget.idToken);
      } catch (_) {}
      throw e;
    });
  }

  Future<void> _answerQuestion(int selectedIndex) async {
    if (_answered || _questions.isEmpty) return;

    setState(() {
      _selectedAnswerIndex = selectedIndex;
      _answered = true;
      _answerState = AnswerState.pending;
    });
    
    // API isteği öncesi hafif bir bekleme (opsiyonel, UI hissi için)
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    final localizations = AppLocalizations.of(context);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final analysisProv = Provider.of<AnalysisProvider>(context, listen: false);

    try {
      final questionId = _questions[_currentIndex]['id'] as int;
      // Cevabın doğruluğunu lokal olarak kontrol et (Animasyon için erken bilgi)
      final correctIndex = _questions[_currentIndex]['correct_answer_index'] as int;
      final bool isLocallyCorrect = (selectedIndex == correctIndex);

      final response = await _apiServiceSafe(
          () => _apiService.submitQuizAnswer(
              widget.idToken, questionId, selectedIndex),
          const Duration(seconds: 8));

      if (response is Map) {
        final newScore = response['new_score'] as int? ?? 0;
        final awarded = response['score_awarded'] as int? ?? 0;

        // 1. Durumu ve Puanı Güncelle
        setState(() {
          _answerState = AnswerState.revealed;
          if (awarded > 0) {
            _sessionScore += awarded;
            _lastAwarded = awarded;
            // _showAward = true; // Eski küçük animasyonu kapatalım, yenisi daha büyük
          }
          // Yanlış sayısı takibi
          if (!isLocallyCorrect) {
            _wrongAnswers++;
          }
        });

        // 2. User Provider & Analysis Update
        userProvider.updateScore(newScore);
        try {
          await userProvider.loadProfile(widget.idToken, preserveRemainingEnergy: true);
          analysisProv.refresh(widget.idToken);
        } catch (_) {}

        // 3. FEEDBACK ANİMASYONUNU BAŞLAT
        _lastAnswerCorrect = isLocallyCorrect;
        setState(() => _showFeedback = true);
        try {
          _feedbackAnimController.forward(from: 0);
        } catch (_) {}

        // 4. OYUN SONU KONTROLÜ (Animasyon sürerken bekle)
        // Kullanıcının feedback'i görmesi için süre tanı (800ms ideal)
        await Future.delayed(const Duration(milliseconds: 800));

        if (!mounted) return;
        setState(() => _showFeedback = false); // Feedback'i kapat

        if (_wrongAnswers >= 3) {
          // 3 Yanlış -> Oyun Biter
          await _handleQuizCompletion();
        } else {
          // Devam -> Sonraki Soru
          if (_currentIndex >= _questions.length - 1) {
            try {
              await _fetchMoreQuestions();
            } catch (e) {
              await _handleQuizCompletion();
            }
          } else {
            _nextQuestion();
          }
        }
      } else {
        throw Exception('Unexpected response');
      }
    } catch (e) {
      _showErrorSnackBar(localizations?.error ?? 'An error occurred');
      if (mounted) {
        setState(() {
          _answered = false;
          _answerState = AnswerState.unanswered;
          _selectedAnswerIndex = null;
        });
      }
    }
  }

  Future<void> _fetchMoreQuestions() async {
    if (!mounted) return;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    try {
      // Ensure profile is reasonably fresh for language/session hints.
      // Preserve any recent optimistic energy decrement so the UI isn't
      // overwritten when fetching more questions mid-session.
      await userProvider.loadProfile(widget.idToken,
          preserveRemainingEnergy: true);
    } catch (_) {}

    final deviceLang = localeProvider.locale.languageCode;
    final lang = _selectSupportedLanguage(
        userProvider.profile?.languageCode, deviceLang,
        allowBackendEn: localeProvider.userSetLanguage);

    try {
      final questions = await _apiService.getQuizQuestions(widget.idToken,
          limit: 3, lang: lang, preview: false, consume: false);
      if (!mounted) return;
      if (questions.isNotEmpty) {
        setState(() {
          _questions = questions
              .map((q) => Map<String, dynamic>.from(q as Map))
              .toList();
          _currentIndex = 0;
          _selectedAnswerIndex = null;
          _answered = false;
          _answerState = AnswerState.unanswered;
        });
      } else {
        throw Exception('No questions available');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> _apiServiceSafe(
      Future<dynamic> Function() fn, Duration timeout) {
    return fn().timeout(timeout,
        onTimeout: () => throw TimeoutException("API timeout"));
  }

  void _nextQuestion() {
    if (!mounted) return;
    setState(() {
      _currentIndex++;
      _selectedAnswerIndex = null;
      _answered = false;
      _answerState = AnswerState.unanswered;
    });
  }

  Future<void> _handleQuizCompletion() async {
    _cancelSessionTimer();
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    setState(() {
      _isQuizActive = false;
    });

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text(localizations?.quizFinished ?? 'Quiz finished',
            style: TextStyle(
                color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
        content: Text(
            "${localizations?.yourScore ?? 'Your score'}: $_sessionScore ${localizations?.pointsEarned ?? 'points'}",
            style:
                TextStyle(fontSize: 18.sp, color: theme.colorScheme.onSurface)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(localizations?.great ?? 'Great',
                  style: TextStyle(color: theme.colorScheme.primary)))
        ],
      ),
    );

    if (mounted) {
      // Fetch preview data only so the Start menu is shown again and
      // we do not auto-start a new session when the results dialog is closed.
      await _fetchQuizData(isInitialLoad: true, isPreview: true);
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 3)));
  }

  Color _getOptionColor(int index) {
    final theme = Theme.of(context);
    if (_questions.isEmpty || _currentIndex >= _questions.length) {
      return colorWithOpacity(theme.colorScheme.surface, 0.5);
    }
    final correctIndex =
        _questions[_currentIndex]['correct_answer_index'] as int;
    switch (_answerState) {
      case AnswerState.unanswered:
        return Colors.white10;
      case AnswerState.pending:
        return index == _selectedAnswerIndex
            ? Colors.yellow.shade700
            : Colors.white10;
      case AnswerState.revealed:
        if (index == correctIndex) {
          return Colors.green.shade600;
        } else if (index == _selectedAnswerIndex) {
          return Colors.red.shade600;
        } else {
          return Colors.white12;
        }
    }
  }

  Border _getOptionBorder(int index) {
    final theme = Theme.of(context);
    if (_questions.isEmpty || _currentIndex >= _questions.length) {
      return Border.all(
          color: colorWithOpacity(theme.colorScheme.primary, 0.5));
    }
    final correctIndex =
        _questions[_currentIndex]['correct_answer_index'] as int;
    if (_answerState == AnswerState.revealed && index == correctIndex) {
      return Border.all(color: Colors.green.shade300, width: 2.5);
    }
    return Border.all(color: colorWithOpacity(theme.colorScheme.primary, 0.18));
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final userProvider = Provider.of<UserProvider>(context);
    final currentStreak = userProvider.profile?.currentStreak ?? 0;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          // ambient animated blobs
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

          SafeArea( // <-- BURAYA SafeArea EKLENDİ
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 420),
              child: _isQuizActive && _questions.isNotEmpty
                  ? _buildQuizView(context, localizations, theme, currentStreak)
                  : _buildStartView(context, localizations, theme),
            ),
          ),
          // floating award (moved after main content so it sits above popups)
          if (_showAward)
            Positioned(
              top: 120.h,
              right: 28.w,
              child: SlideTransition(
                position: _scoreOffset,
                child: FadeTransition(
                  opacity: _scoreAnimController,
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(10.r),
                        boxShadow: [
                          BoxShadow(color: Colors.black38, blurRadius: 8.r)
                        ]),
                    child: Row(children: [
                      Icon(Icons.add, color: Colors.white, size: 16.sp),
                      SizedBox(width: 8.w),
                      Text("+$_lastAwarded ${localizations?.points ?? 'pts'}",
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ),
              ),
            ),
           // --- QUIZ PAGE FEEDBACK (COMBO MODU) ---
          if (_showFeedback)
            Positioned.fill(
              child: Stack(
                children: [
                  // 1. Arka Plan Bulanıklığı
                  BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
                    child: Container(
                      color: _lastAnswerCorrect
                          ? Colors.green.withAlpha(26)
                          : Colors.red.withAlpha(26),
                    ),
                  ),

                  // 2. Animasyonlu Kart
                  Center(
                    child: AnimatedBuilder(
                      animation: _feedbackAnimController,
                      builder: (context, child) {
                        // Elastik efekt
                        final double animValue = CurvedAnimation(
                                parent: _feedbackAnimController,
                                curve: Curves.elasticOut)
                            .value;
                        final double opacityValue = CurvedAnimation(
                                parent: _feedbackAnimController,
                                curve: const Interval(0.0, 0.5,
                                    curve: Curves.easeOut))
                            .value;

                        // Streak durumuna göre başlık belirle
                        String titleText;
                        if (!_lastAnswerCorrect) {
                          titleText = localizations?.incorrect ?? 'WRONG!';
                        } else if (currentStreak >= 2) {
                          titleText = localizations?.unstoppable ?? 'UNSTOPPABLE 🔥';
                        } else {
                          titleText = localizations?.correct ?? 'CORRECT!';
                        }

                        return Opacity(
                          opacity: opacityValue,
                          child: Transform.scale(
                            scale: 0.6 + (animValue * 0.4),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 40.w, vertical: 32.h),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface.withAlpha(243),
                                borderRadius: BorderRadius.circular(24.r),
                                border: Border.all(
                                  color: _lastAnswerCorrect
                                      ? (currentStreak >= 2 ? Colors.orange : Colors.green.withAlpha(128))
                                      : Colors.red.withAlpha(128),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _lastAnswerCorrect
                                        ? (currentStreak >= 2 ? Colors.orange.withAlpha(128) : Colors.green.withAlpha(128))
                                        : Colors.red.withAlpha(128),
                                    blurRadius: 30,
                                    spreadRadius: 2,
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
                                  // İKON
                                  Container(
                                    padding: EdgeInsets.all(16.r),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _lastAnswerCorrect
                                          ? Colors.green.withAlpha(38)
                                          : Colors.red.withAlpha(38),
                                    ),
                                    child: Icon(
                                      _lastAnswerCorrect
                                          ? (currentStreak >= 2 ? Icons.whatshot_rounded : Icons.check_rounded)
                                          : Icons.close_rounded,
                                      size: 72.sp,
                                      color: _lastAnswerCorrect
                                          ? (currentStreak >= 2 ? Colors.orange : Colors.greenAccent)
                                          : Colors.redAccent,
                                    ),
                                  ),
                                  SizedBox(height: 16.h),

                                  // ANA METİN (Duygu)
                                  Text(
                                    titleText,
                                    style: TextStyle(
                                      color: _lastAnswerCorrect
                                          ? (currentStreak >= 2 ? Colors.orange : Colors.green)
                                          : Colors.red,
                                      fontSize: 26.sp,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  
                                  SizedBox(height: 8.h),
                                  
                                  // ALT BİLGİ (Puan - Ödül)
                                  if (_lastAnswerCorrect)
                                     Text(
                                      "+$_lastAwarded Points",
                                      style: TextStyle(
                                        color: theme.colorScheme.onSurface,
                                        fontSize: 20.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  else
                                    Text(
                                      "${3 - _wrongAnswers} chances left",
                                      style: TextStyle(
                                        color: theme.colorScheme.onSurface
                                            .withAlpha(153),
                                        fontSize: 16.sp,
                                      ),
                                    ),

                                  // STREAK BONUS ETİKETİ (Statü - Sadece seri varsa)
                                  if (_lastAnswerCorrect && currentStreak > 1)
                                    Container(
                                      margin: EdgeInsets.only(top: 12.h),
                                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withAlpha(38),
                                        borderRadius: BorderRadius.circular(10.r),
                                        border: Border.all(color: Colors.orange.withAlpha(128)),
                                      ),
                                      child: Builder(builder: (ctx) {
                                        final localized = AppLocalizations.of(ctx)?.streakBonusFire(currentStreak).replaceAll('{streak}', currentStreak.toString());
                                        return Text(
                                          localized ?? 'Streak Bonus x$currentStreak 🔥',
                                          style: TextStyle(
                                            color: Colors.orange,
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        );
                                      }),
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

  Widget _buildStartView(
      BuildContext context, AppLocalizations? localizations, ThemeData theme) {
    final userProv = Provider.of<UserProvider>(context);
    final streak = userProv.profile?.currentStreak ?? 0;

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
                            // 1. NEFES ALAN HERO İKON
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
                                      color: theme.colorScheme.primary.withAlpha(26),
                                      border: Border.all(color: theme.colorScheme.primary.withAlpha(77), width: 1),
                                      boxShadow: [
                                        BoxShadow(
                                          color: theme.colorScheme.primary.withAlpha(64),
                                          blurRadius: 30,
                                          spreadRadius: 8,
                                        )
                                      ],
                                    ),
                                    child: Icon(Icons.quiz_rounded, size: 52.sp, color: theme.colorScheme.primary),
                                  ),
                                );
                              },
                            ),
                            SizedBox(height: 24.h),

                            // 2. BAŞLIK
                            Text(
                              localizations?.startNewQuiz ?? 'Ready to Quiz?',
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
                              localizations?.startNewQuizSubtitle ?? (streak > 2 ? "Keep the fire burning! 🔥" : "Challenge yourself!"),
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
                                      Icon(Icons.psychology, color: theme.colorScheme.primary, size: 22.sp),
                                    ],
                                  ),
                                  Container(width: 1, height: 24.h, color: Colors.white12),
                                    _buildDashboardItem(
                                      Icons.timer_outlined,
                                      '${userProv.profile?.sessionSeconds ?? 60}${localizations?.secondsSuffix ?? 's'}',
                                      theme.colorScheme.tertiary),
                                  Container(width: 1, height: 24.h, color: Colors.white12),
                                  
                                  // --- YENİ: YAZISIZ CAN GÖSTERGESİ ---
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Üst ikon (Kalkan/Koruma veya Kalp çerçevesi)
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

                            // 4. START BUTONU
                            MorphingGradientButton.icon(
                              icon: Icon(Icons.play_arrow_rounded, size: 30.sp, color: Colors.white),
                              label: Text(
                                  localizations?.startWithOneBolt ?? 'Start Quiz',
                                  style: TextStyle(fontSize: 19.sp, fontWeight: FontWeight.bold)),
                              colors: [theme.colorScheme.secondary, theme.colorScheme.primary],
                              onPressed: () {
                                final userProv = Provider.of<UserProvider>(context, listen: false);
                                final rem = userProv.profile?.remainingEnergy;
                                if (rem != null && rem <= 0) {
                                  final loc = AppLocalizations.of(context);
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: Text(loc?.insufficientEnergy ?? 'Insufficient energy ⚡'),
                                      content: Text(loc?.insufficientEnergyBody ?? 'You can try again when your energy refills, or earn energy by watching a video.'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(loc?.cancel ?? 'OK')),
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            Navigator.of(ctx).pop();
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Watch an ad to earn energy')));
                                          },
                                          icon: const Icon(Icons.ondemand_video),
                                          label: const Text('Watch Ad'),
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                                        ),
                                      ],
                                    ),
                                  );
                                  return;
                                }
                                userProv.consumeEnergyOptimistic();
                                _startQuizSession();
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

  Widget _buildQuizView(BuildContext context, AppLocalizations? localizations,
      ThemeData theme, int currentStreak) {
    final userProvider = Provider.of<UserProvider>(context);
    final profile = userProvider.profile;

    return Padding(
      key: ValueKey<int>(_currentIndex),
      // reduce top padding so content sits higher on screen
      padding: EdgeInsets.fromLTRB(24.w, 0.h, 24.w, 24.h),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(top: 12.h),
            child: Column(
              children: [
                SizedBox(height: 4.h),
                // session time slider
                ClipRRect(
                  borderRadius: BorderRadius.circular(6.r),
                  child: LinearProgressIndicator(
                    value: _sessionDuration > 0
                        ? (_timeLeft / _sessionDuration).clamp(0.0, 1.0)
                        : 0.0,
                    minHeight: 6.h,
                    backgroundColor:
                        colorWithOpacity(theme.colorScheme.surface, 0.06),
                    valueColor:
                        AlwaysStoppedAnimation(theme.colorScheme.tertiary),
                  ),
                ),
                SizedBox(height: 10.h), // reduced from 14.h
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInfoChip(
                      Icons.timer,
                      '$_timeLeft${localizations?.secondsSuffix ?? 's'}',
                      _timeLeft < 10
                        ? Colors.red
                        : theme.colorScheme.primary),
                    Flexible(
                      child: Center(
                        child: Text(
                          '${localizations?.streak ?? 'Streak'}: ${profile?.currentStreak ?? 0} 🔥',
                          style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    _buildInfoChip(Icons.star, '$_sessionScore',
                        theme.colorScheme.secondary),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 0.h), // remove extra gap
          // allow question card to size naturally and align to top so it moves up
          Flexible(
            fit: FlexFit.loose,
            child: Align(
              alignment: Alignment.topCenter,
              child: _buildQuestionCard(key: ValueKey<int>(_currentIndex)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard({required Key key}) {
    if (_questions.isEmpty || _currentIndex >= _questions.length) {
      return const Center(child: CircularProgressIndicator());
    }
    final currentQuestion = _questions[_currentIndex];
    final options =
        List<String>.from(currentQuestion['options'] as List<dynamic>);
    final questionText = currentQuestion['question_text'] as String? ?? '';

    final theme = Theme.of(context);

    return SingleChildScrollView(
      key: key,
      child: Column(
        // place items from top so question container height increase pushes content downward naturally
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SizedBox(height: 12.h), // push question box slightly down
          // question container (glass)
          AnimatedGlassCard(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 16.h),
            borderRadius: BorderRadius.circular(16.r),
            child: SizedBox(
              height: 220.h, // increased fixed height so options don't shift
              child: Center(
                  child: Text(questionText,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900, height: 1.25))),
            ),
          ),
          SizedBox(
              height: 16.h), // biraz artırıldı: soru ile seçenekler arası mesafe
          ...List.generate(options.length, (index) {
          final isCorrect =
              index == (currentQuestion['correct_answer_index'] as int);
          final isSelected = index == _selectedAnswerIndex;
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h), // hafif arttırıldı
            child: GestureDetector(
              onTapDown: (_) => setState(() => _pressedOptionIndex = index),
              onTapUp: (_) => setState(() => _pressedOptionIndex = null),
              onTapCancel: () => setState(() => _pressedOptionIndex = null),
              onTap: _answered ? null : () => _answerQuestion(index),
              child: AnimatedScale(
                duration: const Duration(milliseconds: 120),
                scale: _pressedOptionIndex == index ? 0.985 : 1.0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 360),
                  padding: EdgeInsets.symmetric(
                      horizontal: 16.w, vertical: 12.h), // iç padding azaltıldı
                  decoration: BoxDecoration(
                    color: _getOptionColor(index),
                    borderRadius: BorderRadius.circular(16.r),
                    border: _getOptionBorder(index),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                                color: Colors.black45,
                                blurRadius: 10.r,
                                offset: Offset(0, 6.h))
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36.w,
                        height: 36.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? Colors.white24 : Colors.white10,
                          border: Border.all(
                              color: colorWithOpacity(
                                  Theme.of(context).colorScheme.primary, 0.12)),
                        ),
                        child: Center(
                            child: Text(String.fromCharCode(65 + index),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold))),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                          child: Text(options[index],
                              style: TextStyle(
                                  fontSize: 18.sp,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700))),
                      AnimatedOpacity(
                        opacity:
                            _answerState == AnswerState.revealed ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 320),
                        child: isCorrect
                            ? const Icon(Icons.check_circle_outline_rounded,
                                color: Colors.white)
                            : (isSelected
                                ? const Icon(Icons.highlight_off_rounded,
                                    color: Colors.white)
                                : const SizedBox.shrink()),
                      )
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        ],
      ),
    );
  }
}
