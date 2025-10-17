// lib/pages/quiz_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../l10n/app_localizations.dart';
import '../providers/user_provider.dart';
import '../main_screen.dart'; 

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
  late final AnimationController _backgroundController;
  late final Animation<Alignment> _backgroundAnimation1, _backgroundAnimation2;
  AnswerState _answerState = AnswerState.unanswered;

  // Yeni: son kullanılan locale'i takip et
  String? _lastLocale;

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
    // init score award animation
    _scoreAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _scoreOffset = Tween<Offset>(begin: const Offset(0, 0.6), end: const Offset(0, -0.6)).animate(CurvedAnimation(parent: _scoreAnimController, curve: Curves.easeOut));
    _scoreAnimController.addStatusListener((st) {
      if (st == AnimationStatus.completed) {
        // hide after animation completes
        Future.delayed(const Duration(milliseconds: 300), () { if (mounted) setState(() => _showAward = false); });
      }
    });
    _fetchQuizData(isInitialLoad: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final localeCode = Localizations.localeOf(context).languageCode;
    if (_lastLocale != localeCode) {
      _lastLocale = localeCode;
      // If there is an active quiz session, only replace texts for the same question IDs
      if (!_isLoading && _isQuizActive && _questions.isNotEmpty && !_localizeInProgress) {
        final ids = _questions.map((q) => q['id'] as int).toList();
        _localizeInProgress = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          try {
            final localized = await _apiService.getLocalizedQuizQuestions(widget.idToken, ids, lang: localeCode);
            if (!mounted) return;
            if (localized.isNotEmpty) {
              // map localized texts back into existing _questions preserving correct_index & ids
              setState(() {
                final Map<int, Map<String, dynamic>> byId = { for (var q in localized) q['id'] as int : q };
                _questions = _questions.map((q) {
                  final id = q['id'] as int;
                  final loc = byId[id];
                  if (loc != null) {
                    return {
                      'id': id,
                      'question_text': loc['question_text'],
                      'options': loc['options'],
                      'correct_answer_index': loc['correct_answer_index'],
                    };
                  }
                  return q;
                }).toList();
              });
            } else {
              // localized empty => backend returned 400 or empty; do nothing
              debugPrint("Localized quiz returned empty for ids=$ids (no change)");
            }
          } catch (e) {
            // fallback: do not replace questions; do not consume limits
            debugPrint("Failed to localize active quiz: $e");
          } finally {
            _localizeInProgress = false;
          }
        });
      } else {
        // when no active quiz, fetch as preview (no limit consumption)
        if (!_isLoading && !_isQuizActive) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _fetchQuizData(isInitialLoad: false, isPreview: true));
        }
        if (_limitError != null && !_isLoading) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _fetchQuizData(isInitialLoad: false, isPreview: true));
        }
      }
    }
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _scoreAnimController.dispose();
    super.dispose();
  }
  
  Future<void> _fetchQuizData({bool isInitialLoad = false, bool isPreview = false}) async {
    if (!mounted) return;
    setState(() { _isLoading = true; _limitError = null; });
    try {
      final lang = Localizations.localeOf(context).languageCode;
      final questions = await _apiService.getQuizQuestions(widget.idToken, limit: 3, lang: lang, preview: isPreview);
      // refresh profile to get latest daily counters before showing
      await Provider.of<UserProvider>(context, listen: false).loadProfile(widget.idToken);
      if (mounted && questions.isNotEmpty) {
        setState(() {
          _questions = questions;
          // keep current index synced with server profile if available
          final profile = Provider.of<UserProvider>(context, listen: false).profile;
          _currentIndex = 0;
          _sessionScore = profile?.dailyPoints ?? 0;
          _isQuizActive = true;
          _answered = false; _selectedAnswerIndex = null; _answerState = AnswerState.unanswered;
          _limitError = null;
        });
      } else if (mounted) {
        setState(() => _isQuizActive = false);
      }
    } on QuizLimitException catch (e) {
      if (mounted) {
        setState(() { _limitError = e.message; _isQuizActive = false; });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${AppLocalizations.of(context)!.quizCouldNotStart}: ${e.toString()}"), backgroundColor: Theme.of(context).colorScheme.error));
        setState(() => _isQuizActive = false);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startQuizSession() { _sessionScore = 0; _fetchQuizData(isInitialLoad: false, isPreview: false); }

  Future<void> _answerQuestion(int selectedIndex) async {
    if (_answered) return;

    setState(() { _selectedAnswerIndex = selectedIndex; _answered = true; _answerState = AnswerState.pending; });
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    try {
      final response = await _apiService.submitQuizAnswer(widget.idToken, _questions[_currentIndex]['id'] as int, selectedIndex);
      final newScore = response['new_score'] as int? ?? 0;
      final awarded = (response['score_awarded'] as int?) ?? 0;

      setState(() {
        _answerState = AnswerState.revealed;
        if (awarded > 0) {
          _sessionScore += awarded;
          _lastAwarded = awarded;
          _showAward = true;
          _scoreAnimController.forward(from: 0);
        }
      });
      // update global score and THEN refresh full profile to get today's counters/streak
      Provider.of<UserProvider>(context, listen: false).updateScore(newScore);
      await Provider.of<UserProvider>(context, listen: false).loadProfile(widget.idToken);

      await Future.delayed(const Duration(milliseconds: 1800));
      if (!mounted) return;

      if (_currentIndex >= _questions.length - 1) {
        _handleQuizCompletion();
      } else {
        _nextQuestion();
      }
    } catch (e) {
      if(mounted) _showErrorSnackBar("Bir hata oluştu: ${e.toString()}");
      setState(() { _answered = false; _answerState = AnswerState.unanswered; _selectedAnswerIndex = null; });
    }
  }

  void _nextQuestion() {
    if (!mounted) return;
    setState(() { _currentIndex++; _selectedAnswerIndex = null; _answered = false; _answerState = AnswerState.unanswered; });
  }

  Future<void> _handleQuizCompletion() async {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    setState(() { _isQuizActive = false; });
    await showDialog(
      context: context, barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text(localizations.quizFinished, style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
        content: Text("${localizations.yourScore}: $_sessionScore ${localizations.pointsEarned}", style: TextStyle(fontSize: 18.sp, color: Colors.white)),
        actions: [ TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(localizations.great, style: TextStyle(color: theme.colorScheme.tertiary, fontWeight: FontWeight.bold))) ],
      ),
    );

    if (mounted) {
      await _fetchQuizData(isInitialLoad: true);
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Theme.of(context).colorScheme.error,
      duration: const Duration(seconds: 3),
    ));
  }

  Color _getOptionColor(int index) {
    if (_questions.isEmpty || _currentIndex >= _questions.length) return Theme.of(context).colorScheme.surface.withOpacity(0.5);
    final correctIndex = _questions[_currentIndex]['correct_answer_index'];
    switch (_answerState) {
      case AnswerState.unanswered: return Theme.of(context).colorScheme.surface.withOpacity(0.5);
      case AnswerState.pending: return index == _selectedAnswerIndex ? Colors.yellow.shade700 : Theme.of(context).colorScheme.surface.withOpacity(0.5);
      case AnswerState.revealed:
        if (index == correctIndex) return Colors.green.shade600;
        else if (index == _selectedAnswerIndex) return Colors.red.shade600;
        else return Theme.of(context).colorScheme.surface.withOpacity(0.3);
    }
  }

  Border? _getOptionBorder(int index) {
    if (_questions.isEmpty || _currentIndex >= _questions.length) return Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.5));
    final correctIndex = _questions[_currentIndex]['correct_answer_index'];
    if (_answerState == AnswerState.revealed && index == correctIndex) return Border.all(color: Colors.green.shade300, width: 2.5);
    return Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.5));
  }
  
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final userProvider = Provider.of<UserProvider>(context);
    final currentStreak = userProvider.profile?.currentStreak ?? 0;
    return Scaffold( backgroundColor: Colors.black, body: Stack(children: [
          AnimatedBuilder( animation: _backgroundController, builder: (context, child) { return Stack( children: [ Positioned.fill(child: Align(alignment: _backgroundAnimation1.value, child: Container(width: 400.w, height: 400.h, decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.tertiary.withOpacity(0.15), boxShadow: [BoxShadow(color: theme.colorScheme.tertiary.withOpacity(0.1), blurRadius: 100.r, spreadRadius: 80.r)])))), Positioned.fill(child: Align(alignment: _backgroundAnimation2.value, child: Container(width: 300.w, height: 300.h, decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.primary.withOpacity(0.15), boxShadow: [BoxShadow(color: theme.colorScheme.primary.withOpacity(0.1), blurRadius: 100.r, spreadRadius: 60.r)])))),],);},),
          // award floating indicator
          if (_showAward)
            Positioned(
              top: 120.h,
              right: 40.w,
              child: SlideTransition(
                position: _scoreOffset,
                child: FadeTransition(
                  opacity: _scoreAnimController,
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 12.w),
                    decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.95), borderRadius: BorderRadius.circular(8.r), boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 6.r)]),
                    child: Row(children: [
                      Icon(Icons.add, color: Colors.white, size: 16.sp),
                      SizedBox(width: 6.w),
                      Text("+$_lastAwarded ${localizations.points}", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.sp)),
                    ]),
                  ),
                ),
              ),
            ),
           AnimatedSwitcher( duration: const Duration(milliseconds: 500), transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: ScaleTransition(scale: animation, child: child)),
             child: _isQuizActive && _questions.isNotEmpty ? _buildQuizView(context, localizations, theme, currentStreak) : _buildStartView(context, localizations, theme),
           ),
         ],
       ),
     );
   }
 
   Widget _buildStartView(BuildContext context, AppLocalizations localizations, ThemeData theme) {
     if (_limitError != null) { return _buildLimitExceededView(context, localizations, theme); }
     return Center( key: const ValueKey('startView'),
       child: _isLoading ? CircularProgressIndicator(color: theme.colorScheme.primary) : ElevatedButton.icon( icon: Icon(Icons.play_arrow_rounded, size: 28.sp), label: Text(localizations.startNewQuiz, style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 16.h)), onPressed: _startQuizSession,),
     );
   }
 
   Widget _buildLimitExceededView(BuildContext context, AppLocalizations localizations, ThemeData theme) {
     return Center( key: const ValueKey('limitExceededView'), child: Padding( padding: EdgeInsets.all(32.w), child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [
             Icon(Icons.lock_outline_rounded, size: 60.sp, color: theme.colorScheme.error), SizedBox(height: 20.h),
             Text(localizations.limitExceeded, style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.error)), SizedBox(height: 10.h),
             Text(_limitError ?? localizations.upgrade, textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 16.sp)), SizedBox(height: 30.h),
             ElevatedButton( onPressed: () { final mainScreenState = context.findAncestorStateOfType<MainScreenState>(); if (mainScreenState != null) { mainScreenState.onItemTapped(1); } }, child: Text(localizations.upgrade), style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.secondary),)
           ],),),
     );
   }
 
  Widget _buildQuizView(BuildContext context, AppLocalizations localizations, ThemeData theme, int currentStreak) {
     final userProvider = Provider.of<UserProvider>(context);
     final profile = userProvider.profile;
     final dailyPoints = profile?.dailyPoints ?? 0;

     // calculate display index and limit; avoid showing X/Y when it would exceed limit
     final int dailyUsed = profile?.dailyQuizUsed ?? 0;
     final int displayIndex = dailyUsed + 1;
     final int? dailyLimit = profile?.dailyQuizLimit;
     final bool overLimit = dailyLimit != null && displayIndex > dailyLimit;
     final double progressValue = (() {
       final denom = (dailyLimit != null && dailyLimit > 0) ? dailyLimit.toDouble() : 1.0;
       final v = (displayIndex.toDouble() / denom).clamp(0.0, 1.0);
       return v;
     })();
 
     return Padding( key: ValueKey<int>(_currentIndex), padding: EdgeInsets.all(16.w), child: Column( children: [
           SafeArea( child: Column( children: [ LinearProgressIndicator(value: progressValue, backgroundColor: theme.cardTheme.color, color: theme.colorScheme.tertiary, minHeight: 8.h, borderRadius: BorderRadius.circular(4.r)), SizedBox(height: 16.h),
                Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ 
                     // show Question X/Y based on computed displayIndex; hide if over limit
                     if (!overLimit)
                       Text("${localizations.question} $displayIndex/${dailyLimit ?? _questions.length}", style: TextStyle(color: theme.colorScheme.tertiary, fontSize: 18.sp, fontWeight: FontWeight.bold))
                     else
                       const SizedBox.shrink(),
                    Row(children: [
                      // today's points
                     Container(
                       padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                       decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.95), borderRadius: BorderRadius.circular(10.r)),
                       child: Row(children: [
                         Icon(Icons.star_rounded, color: Colors.yellow.shade700, size: 14.sp),
                         SizedBox(width: 6.w),
                         Text("$dailyPoints ${localizations.points}", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.sp)),
                       ]),
                     ),
                     SizedBox(width: 10.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(color: theme.colorScheme.secondary),
                        ),
                        child: Text("${localizations.streak}: ${profile?.currentStreak ?? 0}", style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold, fontSize: 14.sp)),
                      ),
                    ]),
                 ],),
              ],),),Expanded( child: _buildQuestionCard(key: ValueKey<int>(_currentIndex))),
        ],
      ),
    );
  }
   // Duplicate/malformed _buildQuestionCard removed; the real implementation appears further below.
 
   Widget _buildQuestionCard({required Key key}) {
     // Güvenlik kontrolü: Sorular henüz yüklenmediyse boş bir widget döndür
     if (_questions.isEmpty || _currentIndex >= _questions.length) {
       return const Center(child: CircularProgressIndicator());
     }
     final currentQuestion = _questions[_currentIndex];
     final options = currentQuestion['options'] as List<dynamic>; 
     return Column( key: key, mainAxisAlignment: MainAxisAlignment.center, children: [
         // grey box removed: plain padding around question text
         Container(
           padding: EdgeInsets.all(24.w),
           child: Text(
             currentQuestion['question_text'],
             textAlign: TextAlign.center,
             style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold, color: Colors.white),
           ),
         ),
         SizedBox(height: 30.h),
         ...List.generate(options.length, (index) {
           // --- BU DEĞİŞKENLER BURADA KULLANILIYOR ---
           final isCorrect = index == currentQuestion['correct_answer_index'];
           final isSelected = index == _selectedAnswerIndex;
           
           return Padding(
             padding: EdgeInsets.symmetric(vertical: 8.h),
             child: InkWell(
               onTap: _answered ? null : () => _answerQuestion(index),
               borderRadius: BorderRadius.circular(16.r),
               child: AnimatedContainer(
                 duration: const Duration(milliseconds: 400),
                 padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                 decoration: BoxDecoration( color: _getOptionColor(index), borderRadius: BorderRadius.circular(16.r), border: _getOptionBorder(index), ),
                 child: Row(
                   children: [
                     Expanded(child: Text(options[index], style: TextStyle(fontSize: 18.sp, color: Colors.white))),
                     
                     // --- KULLANIM YERİ BURASI ---
                     AnimatedOpacity(
                       // Sadece sonuçlar açıklandığında ikonları göster
                       opacity: _answerState == AnswerState.revealed ? 1.0 : 0.0,
                       duration: const Duration(milliseconds: 400),
                       // `isCorrect` doğru cevabın yanına ✅ koymak için,
                       // `isSelected` ise seçilen yanlış cevabın yanına ❌ koymak için kullanılır.
                       child: isCorrect
                           ? Icon(Icons.check_circle_outline_rounded, color: Colors.white)
                           : (isSelected ? Icon(Icons.highlight_off_rounded, color: Colors.white) : const SizedBox.shrink()),
                     )
                   ],
                 ),
               ),
             ),
           );
         }),
       ],
     );
   }
 }