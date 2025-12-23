// lib/pages/truefalse_page.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/user_provider.dart';
import '../providers/analysis_provider.dart';
import '../locale_provider.dart';
import 'package:sparkup_app/utils/color_utils.dart';

enum TFAnswerState { unanswered, pending, revealed }

class TrueFalsePage extends StatefulWidget {
  final String idToken;
  const TrueFalsePage({super.key, required this.idToken});

  @override
  State<TrueFalsePage> createState() => _TrueFalsePageState();
}

class _TrueFalsePageState extends State<TrueFalsePage> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _questions = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _answered = false;
  TFAnswerState _answerState = TFAnswerState.unanswered;
  bool? _selectedAnswer; // true/false

  // score animation
  late final AnimationController _scoreAnimController;
  late final Animation<Offset> _scoreOffset;
  int _lastAwarded = 0;
  bool _showAward = false;

  LocaleProvider? _localeProviderRef;
  String? _lastLocale;

  @override
  void initState() {
    super.initState();
    _scoreAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _scoreOffset = Tween<Offset>(begin: const Offset(0, 0.6), end: const Offset(0, -0.6)).animate(CurvedAnimation(parent: _scoreAnimController, curve: Curves.easeOut));
    _scoreAnimController.addStatusListener((st) {
      if (st == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) setState(() => _showAward = false);
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        _localeProviderRef = Provider.of<LocaleProvider>(context, listen: false);
        _localeProviderRef?.addListener(_onLocaleChanged);
      } catch (_) {}
      await _loadQuestions();
    });
  }

  @override
  void dispose() {
    _scoreAnimController.dispose();
    try { _localeProviderRef?.removeListener(_onLocaleChanged); } catch (_) {}
    super.dispose();
  }

  void _onLocaleChanged() {
    final localeCode = _localeProviderRef?.locale.languageCode;
    if (localeCode == null) return;
    if (_lastLocale == localeCode) return;
    _lastLocale = localeCode;
    if (!_isLoading && !_answered) {
      _loadQuestions();
    }
  }

  String _selectSupportedLanguage(String? userLang, String deviceLang, {required bool allowBackendEn}) {
    const supported = {'en','tr','de','fr','es','it','ru','zh','hi','ja','ar'};
    if (userLang != null && supported.contains(userLang) && (allowBackendEn || userLang != 'en')) return userLang;
    if (supported.contains(deviceLang)) return deviceLang;
    return 'en';
  }

  Future<void> _loadQuestions() async {
    setState(() { _isLoading = true; });
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    await userProvider.loadProfile(widget.idToken);
    try {
      final deviceLang = localeProvider.locale.languageCode;
      final lang = _selectSupportedLanguage(userProvider.profile?.languageCode, deviceLang, allowBackendEn: localeProvider.userSetLanguage);
      final raw = await rootBundle.loadString('data/manual_truefalse.json');
      final parsed = json.decode(raw) as List<dynamic>;
      final loaded = parsed.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      // map to localized structure
      final localized = loaded.map((q) {
        final qm = q['question'] as Map<String, dynamic>;
        final text = (qm[lang] as String?) ?? (qm['en'] as String? ?? '');
        return {
          'id': loaded.indexOf(q),
          'category': q['category'] ?? 'General',
          'question_text': text,
          'correct_answer': q['correct_answer'] ?? false,
        };
      }).toList();

      setState(() {
        _questions = localized;
        _currentIndex = 0;
        _answered = false;
        _answerState = TFAnswerState.unanswered;
        _selectedAnswer = null;
      });
    } catch (e) {
      debugPrint('Failed to load true/false questions: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _answerQuestion(bool selected) async {
    if (_answered || _questions.isEmpty) return;
    setState(() { _selectedAnswer = selected; _answered = true; _answerState = TFAnswerState.pending; });
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final localizations = AppLocalizations.of(context);
    try {
      final current = _questions[_currentIndex];
      final correct = current['correct_answer'] as bool;
      final bool isCorrect = selected == correct;
      final awarded = isCorrect ? 10 : 0;

      // Update local user profile (score, dailyPoints, streak)
      final profile = userProvider.profile;
      final newScore = (profile?.score ?? 0) + awarded;
      final newDaily = (profile?.dailyPoints ?? 0) + awarded;
      final newStreak = isCorrect ? ((profile?.currentStreak ?? 0) + 1) : 0;
      if (profile != null) {
        userProvider.setProfile(profile.copyWith(score: newScore, dailyPoints: newDaily, currentStreak: newStreak));
      } else {
        userProvider.setProfile(UserProfile(username: null, score: newScore, currentStreak: newStreak, subscriptionLevel: 'free', dailyPoints: newDaily));
      }

      setState(() {
        _answerState = TFAnswerState.revealed;
        if (awarded > 0) {
          _lastAwarded = awarded;
          _showAward = true;
          _scoreAnimController.forward(from: 0);
        }
      });

      // Notify analysis provider to refresh
      try { Provider.of<AnalysisProvider>(context, listen: false).refresh(widget.idToken); } catch (_) {}

      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      if (_currentIndex >= _questions.length - 1) {
        await _handleCompletion();
      } else {
        setState(() {
          _currentIndex++;
          _selectedAnswer = null;
          _answered = false;
          _answerState = TFAnswerState.unanswered;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(localizations?.error ?? 'An error occurred'), backgroundColor: Theme.of(context).colorScheme.error));
      setState(() { _answered = false; _answerState = TFAnswerState.unanswered; _selectedAnswer = null; });
    }
  }

  Future<void> _handleCompletion() async {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text(localizations?.quizFinished ?? 'Finished', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
        content: Text(localizations?.yourScore ?? 'Your score', style: TextStyle(color: theme.colorScheme.onSurface)),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(localizations?.great ?? 'Great', style: TextStyle(color: theme.colorScheme.primary)))]
      )
    );

    if (mounted) await _loadQuestions();
  }

  Color _getButtonColor(bool value) {
    if (_answerState == TFAnswerState.unanswered) return Colors.white10;
    if (_answerState == TFAnswerState.pending) return _selectedAnswer == value ? Colors.yellow.shade700 : Colors.white10;
    // revealed
    final correct = _questions[_currentIndex]['correct_answer'] as bool;
    if (value == correct) return Colors.green.shade600;
    if (_selectedAnswer == value) return Colors.red.shade600;
    return Colors.white12;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context);
    final userProvider = Provider.of<UserProvider>(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 8.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(localizations?.trueFalseTitle ?? 'True / False', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                      decoration: BoxDecoration(color: colorWithOpacity(theme.colorScheme.primary, 0.95), borderRadius: BorderRadius.circular(10.r)),
                      child: Row(children: [Icon(Icons.star_rounded, color: Colors.yellow.shade700, size: 14.sp), SizedBox(width: 6.w), Text('${userProvider.profile?.dailyPoints ?? 0} ${localizations?.points ?? 'pts'}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.sp))]),
                    ),
                  ],
                ),
                SizedBox(height: 14.h),

              if (_isLoading) Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),

              if (!_isLoading && _questions.isEmpty) Center(child: Text(localizations?.noDataFound ?? 'No questions available', style: TextStyle(color: colorWithOpacity(theme.colorScheme.onSurface, 0.7)))),

                if (!_isLoading && _questions.isNotEmpty)
                  Expanded(
                    child: Column(
                      children: [
                        // question card
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 360),
                          padding: EdgeInsets.all(14.w),
                          decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(14.r), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8.r, offset: Offset(0,2))]),
                          child: SizedBox(height: 180.h, child: Center(child: Text(_questions[_currentIndex]['question_text'] ?? '', textAlign: TextAlign.center, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)))),
                        ),
                        SizedBox(height: 18.h),

                        // True / False buttons
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: _answered ? null : () => _answerQuestion(true),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  padding: EdgeInsets.symmetric(vertical: 16.h),
                                  decoration: BoxDecoration(color: _getButtonColor(true), borderRadius: BorderRadius.circular(12.r), border: Border.all(color: colorWithOpacity(theme.colorScheme.primary, 0.12))),
                                  child: Center(child: Text(localizations?.trueLabel ?? 'True', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18.sp))),
                                ),
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: GestureDetector(
                                onTap: _answered ? null : () => _answerQuestion(false),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  padding: EdgeInsets.symmetric(vertical: 16.h),
                                  decoration: BoxDecoration(color: _getButtonColor(false), borderRadius: BorderRadius.circular(12.r), border: Border.all(color: colorWithOpacity(theme.colorScheme.primary, 0.12))),
                                  child: Center(child: Text(localizations?.falseLabel ?? 'False', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18.sp))),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 18.h),
                        // small footer showing category & streak
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('${localizations?.categoryLabel ?? 'Category'}: ${_questions[_currentIndex]['category']}', style: TextStyle(color: colorWithOpacity(theme.colorScheme.onSurface, 0.7))), Text('${localizations?.streak ?? 'Streak'}: ${userProvider.profile?.currentStreak ?? 0}', style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold))]),
                      ],
                    ),
                  ),
              ],
            ),
          ),

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
                        child: Row(children: [Icon(Icons.add, color: Colors.white, size: 16.sp), SizedBox(width: 8.w), Text('+$_lastAwarded ${localizations?.points ?? 'pts'}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
