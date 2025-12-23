// lib/pages/quiz_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../widgets/morphing_gradient_button.dart';
import '../widgets/animated_glass_card.dart';
import '../l10n/app_localizations.dart';
import '../providers/user_provider.dart';
import '../locale_provider.dart';
import '../main_screen.dart';
import 'package:sparkup_app/utils/color_utils.dart';

enum AnswerState { unanswered, pending, revealed }

class QuizPage extends StatefulWidget {
  final String idToken;
  const QuizPage({super.key, required this.idToken});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  bool _localizeInProgress = false;
  bool _isQuizActive = false, _isLoading = true, _answered = false;
  String? _limitError;
  List<Map<String, dynamic>> _questions = [];
  int _currentIndex = 0, _sessionScore = 0;
  int? _selectedAnswerIndex;
  int? _pressedOptionIndex;
  late final AnimationController _backgroundController;
  late final Animation<Alignment> _backgroundAnimation1, _backgroundAnimation2;
  AnswerState _answerState = AnswerState.unanswered;

  // Yeni: son kullanılan locale'i takip et
  String? _lastLocale;
  // Keep a reference to the locale provider so we can listen for changes
  LocaleProvider? _localeProviderRef;

  // score award animation
  late final AnimationController _scoreAnimController;
  late final Animation<Offset> _scoreOffset;
  int _lastAwarded = 0;
  bool _showAward = false;

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

    _scoreAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _scoreOffset = Tween<Offset>(begin: const Offset(0, 0.6), end: const Offset(0, -0.6)).animate(CurvedAnimation(parent: _scoreAnimController, curve: Curves.easeOut));
    _scoreAnimController.addStatusListener((st) {
      if (st == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) { setState(() => _showAward = false); }
        });
      }
    });

    // Defer the initial fetch until after the first frame so inherited
    // widgets (Theme, Localizations, ScaffoldMessenger, Providers) are
    // available. Calling them from initState can cause the "dependOnInheritedWidgetOfExactType"
    // error in debug/dev builds.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchQuizData(isInitialLoad: true);
      // register locale change listener so active pages update when provider locale changes
      try {
        _localeProviderRef = Provider.of<LocaleProvider>(context, listen: false);
        _localeProviderRef?.addListener(_onLocaleChanged);
      } catch (_) {}
    });
  }

  // Choose effective language for API calls: prefer explicit user choice if supported,
  // otherwise use device/app locale if supported; finally fallback to 'en'.
  String _selectSupportedLanguage(String? userLang, String deviceLang, {required bool allowBackendEn}) {
    const supported = {'en','tr','de','fr','es','it','ru','zh','hi','ja','ar'};
    // Use backend/user language only if supported and either it's not 'en' or the user explicitly chose it
    if (userLang != null && supported.contains(userLang) && (allowBackendEn || userLang != 'en')) return userLang;
    if (supported.contains(deviceLang)) return deviceLang;
    return 'en';
  }

  void _onLocaleChanged() {
    final localeCode = _localeProviderRef?.locale.languageCode;
    if (localeCode == null) return;
    if (_lastLocale == localeCode) return;
    _lastLocale = localeCode;
    if (!_isLoading && _isQuizActive && _questions.isNotEmpty && !_localizeInProgress) {
      final ids = _questions.map((q) => q['id'] as int).toList();
      _localizeInProgress = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final localized = await _apiService.getLocalizedQuizQuestions(widget.idToken, ids, lang: localeCode);
          if (!mounted) return;
          if (localized.isNotEmpty) {
            setState(() {
              final Map<int, Map<String, dynamic>> byId = { for (var q in localized) (q['id'] as int) : Map<String, dynamic>.from(q) };
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
        WidgetsBinding.instance.addPostFrameCallback((_) => _fetchQuizData(isInitialLoad: false, isPreview: true));
      }
      if (_limitError != null && !_isLoading) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _fetchQuizData(isInitialLoad: false, isPreview: true));
      }
    }
  }

                @override
                void dispose() {
                  _backgroundController.dispose();
                  _scoreAnimController.dispose();
                  try { _localeProviderRef?.removeListener(_onLocaleChanged); } catch (_) {}
                  super.dispose();
                }

                String _cleanLimitMessage(String raw) {
                  var s = raw.trim();
                  // Eğer "SomePrefix : actual message" şeklinde geliyorsa prefix'i at
                  final idx = s.indexOf(':');
                  if (idx != -1 && idx < 40) {
                    s = s.substring(idx + 1).trim();
                  }
                  return s;
                }

                Future<void> _fetchQuizData({bool isInitialLoad = false, bool isPreview = false}) async {
                  if (!mounted) return;
                final localizations = AppLocalizations.of(context);
                final theme = Theme.of(context);
                final messenger = ScaffoldMessenger.of(context);
                final userProvider = Provider.of<UserProvider>(context, listen: false);
                // Ensure we have the latest profile so we can use user's language preference
                await userProvider.loadProfile(widget.idToken);
                final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
                  setState(() {
                    _isLoading = true;
                    _limitError = null;
                  });
                  try {
                  final deviceLang = localeProvider.locale.languageCode;
                  final lang = _selectSupportedLanguage(userProvider.profile?.languageCode, deviceLang, allowBackendEn: localeProvider.userSetLanguage);
                  final questions = await _apiService.getQuizQuestions(widget.idToken, limit: 3, lang: lang, preview: isPreview);
                if (!mounted) return;

                    if (questions.isNotEmpty) {
                        setState(() {
                        _questions = questions.map((q) => Map<String, dynamic>.from(q as Map)).toList();
                        final profile = userProvider.profile;
                        _currentIndex = 0;
                        _sessionScore = profile?.dailyPoints ?? 0;
                        _isQuizActive = true;
                        _answered = false;
                        _selectedAnswerIndex = null;
                        _answerState = AnswerState.unanswered;
                        _limitError = null;
                      });
                    } else {
                      setState(() {
                        _isQuizActive = false;
                      });
                    }
                  } catch (e) {
                    final err = e.toString().toLowerCase();
                    if (err.contains('limit') || err.contains('quota')) {
                      if (mounted) {
                        setState(() {
                        _limitError = _cleanLimitMessage(e.toString());
                        _isQuizActive = false;
                      });
                      }
                    } else {
                      final msg = localizations?.quizCouldNotStart ?? 'Quiz could not be started';
                      if (mounted) {
                        messenger.showSnackBar(SnackBar(content: Text("$msg: ${e.toString()}"), backgroundColor: theme.colorScheme.error));
                        setState(() => _isQuizActive = false);
                      }
                    }
                  } finally {
                    if (mounted) { setState(() => _isLoading = false); }
                  }
                }

                void _startQuizSession() {
                  _sessionScore = 0;
                  _fetchQuizData(isInitialLoad: false, isPreview: false);
                }

                Future<void> _answerQuestion(int selectedIndex) async {
                  if (_answered || _questions.isEmpty) return;

                  setState(() {
                    _selectedAnswerIndex = selectedIndex;
                    _answered = true;
                    _answerState = AnswerState.pending;
                  });
                  await Future.delayed(const Duration(milliseconds: 700));
                  if (!mounted) return;

                final localizations = AppLocalizations.of(context);
                final userProvider = Provider.of<UserProvider>(context, listen: false);
                try {
                    final questionId = _questions[_currentIndex]['id'] as int;
                final response = await _apiServiceSafe(() => _apiService.submitQuizAnswer(widget.idToken, questionId, selectedIndex), const Duration(seconds: 8));
                    if (response is Map) {
                      final newScore = response['new_score'] as int? ?? 0;
                      final awarded = response['score_awarded'] as int? ?? 0;

                      setState(() {
                        _answerState = AnswerState.revealed;
                        if (awarded > 0) {
                          _sessionScore += awarded;
                          _lastAwarded = awarded;
                          _showAward = true;
                          _scoreAnimController.forward(from: 0);
                        }
                      });

                userProvider.updateScore(newScore);
                await userProvider.loadProfile(widget.idToken);

                      await Future.delayed(const Duration(milliseconds: 900));
                      if (!mounted) return;

                      if (_currentIndex >= _questions.length - 1) {
                        await _handleQuizCompletion();
                      } else {
                        _nextQuestion();
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

                Future<dynamic> _apiServiceSafe(Future<dynamic> Function() fn, Duration timeout) {
                  return fn().timeout(timeout, onTimeout: () => throw TimeoutException("API timeout"));
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                      title: Text(localizations?.quizFinished ?? 'Quiz finished', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                      content: Text("${localizations?.yourScore ?? 'Your score'}: $_sessionScore ${localizations?.pointsEarned ?? 'points'}",
                          style: TextStyle(fontSize: 18.sp, color: theme.colorScheme.onSurface)),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(localizations?.great ?? 'Great', style: TextStyle(color: theme.colorScheme.primary)))
                      ],
                    ),
                  );

                  if (mounted) {
                    await _fetchQuizData(isInitialLoad: true);
                  }
                }

                void _showErrorSnackBar(String message) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Theme.of(context).colorScheme.error, duration: const Duration(seconds: 3)));
                }

                Color _getOptionColor(int index) {
                  final theme = Theme.of(context);
                  if (_questions.isEmpty || _currentIndex >= _questions.length) { return colorWithOpacity(theme.colorScheme.surface, 0.5); }
                  final correctIndex = _questions[_currentIndex]['correct_answer_index'] as int;
                  switch (_answerState) {
                    case AnswerState.unanswered:
                      return Colors.white10;
                    case AnswerState.pending:
                      return index == _selectedAnswerIndex ? Colors.yellow.shade700 : Colors.white10;
                    case AnswerState.revealed:
                      if (index == correctIndex) {
                        return Colors.green.shade600;
                      } else if (index == _selectedAnswerIndex) { return Colors.red.shade600; }
                      else { return Colors.white12; }
                  }
                }

                Border _getOptionBorder(int index) {
                  final theme = Theme.of(context);
                  if (_questions.isEmpty || _currentIndex >= _questions.length) { return Border.all(color: colorWithOpacity(theme.colorScheme.primary, 0.5)); }
                  final correctIndex = _questions[_currentIndex]['correct_answer_index'] as int;
                  if (_answerState == AnswerState.revealed && index == correctIndex) { return Border.all(color: Colors.green.shade300, width: 2.5); }
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

                        // floating award
                        if (_showAward)
                          Positioned(
                            top: 120.h,
                            right: 28.w,
                            child: SlideTransition(
                              position: _scoreOffset,
                              child: FadeTransition(
                                opacity: _scoreAnimController,
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                                  decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(10.r), boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 8.r)]),
                                  child: Row(children: [
                                    Icon(Icons.add, color: Colors.white, size: 16.sp),
                                    SizedBox(width: 8.w),
                                    Text("+$_lastAwarded ${localizations?.points ?? 'pts'}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ]),
                                ),
                              ),
                            ),
                          ),

                        // main content
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 420),
                          child: _isQuizActive && _questions.isNotEmpty
                              ? _buildQuizView(context, localizations, theme, currentStreak)
                              : _buildStartView(context, localizations, theme),
                        ),
                      ],
                    ),
                  );
                }

                Widget _buildStartView(BuildContext context, AppLocalizations? localizations, ThemeData theme) {
                  if (_limitError != null) return _buildLimitExceededView(context, localizations, theme);
                  return Center(
                    key: const ValueKey('startView'),
                    child: _isLoading
                        ? CircularProgressIndicator(color: theme.colorScheme.primary)
                        : MorphingGradientButton.icon(
                            icon: Icon(Icons.play_arrow_rounded, size: 22.sp, color: Colors.white),
                            label: Text(localizations?.startNewQuiz ?? 'Start Quiz', style: TextStyle(fontSize: 18.sp)),
                            colors: [theme.colorScheme.secondary, theme.colorScheme.primary],
                            onPressed: _startQuizSession,
                            padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 14.h),
                          ),
                  );
                }

                Widget _buildLimitExceededView(BuildContext context, AppLocalizations? localizations, ThemeData theme) {
                  return Center(
                    key: const ValueKey('limitExceededView'),
                    child: Padding(
                      padding: EdgeInsets.all(32.w),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_outline_rounded, size: 60.sp, color: theme.colorScheme.error),
                          SizedBox(height: 20.h),
                          Text(localizations?.limitExceeded ?? 'Limit exceeded', style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.error)),
                          SizedBox(height: 10.h),
                          Text(_limitError ?? (localizations?.upgrade ?? 'Upgrade'), textAlign: TextAlign.center, style: TextStyle(color: colorWithOpacity(theme.colorScheme.onSurface, 0.7), fontSize: 16.sp)),
                          SizedBox(height: 30.h),
                          MorphingGradientButton(
                            onPressed: () {
                              final mainScreenState = context.findAncestorStateOfType<MainScreenState>();
                              if (mainScreenState != null) mainScreenState.onItemTapped(1);
                            },
                            padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 12.h),
                            colors: [theme.colorScheme.secondary, theme.colorScheme.primary],
                            child: Text(localizations?.upgrade ?? 'Upgrade', style: TextStyle(fontSize: 14.sp)),
                          )
                        ],
                      ),
                    ),
                  );
                }

                Widget _buildQuizView(BuildContext context, AppLocalizations? localizations, ThemeData theme, int currentStreak) {
                  final userProvider = Provider.of<UserProvider>(context);
                  final profile = userProvider.profile;
                  final dailyPoints = profile?.dailyPoints ?? 0;

                  final int dailyUsed = profile?.dailyQuizUsed ?? 0;
                  final int displayIndex = dailyUsed + 1;
                  final int? dailyLimit = profile?.dailyQuizLimit;
                  final bool overLimit = dailyLimit != null && displayIndex > dailyLimit;
                  final double progressValue = (() {
                    final denom = (dailyLimit != null && dailyLimit > 0) ? dailyLimit.toDouble() : _questions.length.toDouble();
                    return (displayIndex.toDouble() / denom).clamp(0.0, 1.0);
                  })();

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
                              // rounded linear progress
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8.r),
                                child: LinearProgressIndicator(
                                  value: progressValue,
                                  minHeight: 8.h,
                                  backgroundColor: colorWithOpacity(theme.colorScheme.surface, 0.08),
                                  valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                                ),
                              ),
                              SizedBox(height: 10.h), // reduced from 14.h
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  if (!overLimit)
                                    Text("${localizations?.question ?? 'Question'} $displayIndex/${dailyLimit ?? _questions.length}", style: TextStyle(color: theme.colorScheme.primary, fontSize: 17.sp, fontWeight: FontWeight.bold))
                                  else
                                    const SizedBox.shrink(),
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                                        decoration: BoxDecoration(color: colorWithOpacity(theme.colorScheme.primary, 0.95), borderRadius: BorderRadius.circular(10.r)),
                                        child: Row(children: [
                                          Icon(Icons.star_rounded, color: Colors.yellow.shade700, size: 14.sp),
                                          SizedBox(width: 6.w),
                                          Text("$dailyPoints ${localizations?.points ?? 'pts'}", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.sp)),
                                        ]),
                                      ),
                                      SizedBox(width: 10.w),
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                        decoration: BoxDecoration(
                                          color: colorWithOpacity(theme.colorScheme.secondary, 0.18),
                                          borderRadius: BorderRadius.circular(10.r),
                                          border: Border.all(color: colorWithOpacity(theme.colorScheme.secondary, 0.22)),
                                        ),
                                        child: Text("${localizations?.streak ?? 'Streak'}: ${profile?.currentStreak ?? 0}", style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold, fontSize: 14.sp)),
                                      ),
                                    ],
                                  ),
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
                  final options = List<String>.from(currentQuestion['options'] as List<dynamic>);
                  final questionText = currentQuestion['question_text'] as String? ?? '';

                final theme = Theme.of(context);

                return Column(
                    key: key,
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
                          child: Center(child: Text(questionText, textAlign: TextAlign.center, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, height: 1.25))),
                        ),
                      ),
                      SizedBox(height: 16.h), // biraz artırıldı: soru ile seçenekler arası mesafe
                      ...List.generate(options.length, (index) {
                        final isCorrect = index == (currentQuestion['correct_answer_index'] as int);
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
                                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h), // iç padding azaltıldı
                                decoration: BoxDecoration(
                                  color: _getOptionColor(index),
                                  borderRadius: BorderRadius.circular(16.r),
                                  border: _getOptionBorder(index),
                                  boxShadow: isSelected ? [BoxShadow(color: Colors.black45, blurRadius: 10.r, offset: Offset(0, 6.h))] : null,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36.w,
                                      height: 36.w,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected ? Colors.white24 : Colors.white10,
                                        border: Border.all(color: colorWithOpacity(Theme.of(context).colorScheme.primary, 0.12)),
                                      ),
                                      child: Center(child: Text(String.fromCharCode(65 + index), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                    ),
                                    SizedBox(width: 12.w),
                                    Expanded(child: Text(options[index], style: TextStyle(fontSize: 18.sp, color: Colors.white, fontWeight: FontWeight.w700))),
                                    AnimatedOpacity(
                                      opacity: _answerState == AnswerState.revealed ? 1.0 : 0.0,
                                      duration: const Duration(milliseconds: 320),
                                      child: isCorrect
                                          ? const Icon(Icons.check_circle_outline_rounded, color: Colors.white)
                                          : (isSelected ? const Icon(Icons.highlight_off_rounded, color: Colors.white) : const SizedBox.shrink()),
                                    )
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                }
              }