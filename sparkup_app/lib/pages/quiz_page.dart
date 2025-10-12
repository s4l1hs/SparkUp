import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../l10n/app_localizations.dart';
import '../providers/user_provider.dart';
import '../main_screen.dart'; 

class QuizPage extends StatefulWidget {
  final String idToken;
  const QuizPage({super.key, required this.idToken});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();

  bool _isQuizActive = false;
  bool _isLoading = true; 
  String? _limitError; 
  
  List<Map<String, dynamic>> _questions = [];
  int _currentIndex = 0;
  int _sessionScore = 0; 
  int? _selectedAnswerIndex;
  bool _answered = false;
  
  // --- ANİMASYON CONTROLLER'LARI ---
  late final AnimationController _backgroundController;
  late final Animation<Alignment> _backgroundAnimation1;
  late final Animation<Alignment> _backgroundAnimation2;

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
    
    _fetchQuizData(isInitialLoad: true); 
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    super.dispose();
  }
  
  // --- YARDIMCI METOTLAR ---
  
  Future<void> _fetchQuizData({bool isInitialLoad = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _limitError = null;
    });
    
    try {
      final questions = await _apiService.getQuizQuestions(widget.idToken); 
      
      if (mounted) {
        if (questions.isNotEmpty) {
          setState(() {
            _questions = questions;
            _currentIndex = 0; 
            _isQuizActive = true;
          });
        } else {
          if (isInitialLoad) {
             setState(() => _isQuizActive = false);
          } else {
             _showResultDialog();
          }
        }
      }
    } on QuizLimitException catch (e) {
      if (mounted) {
        setState(() {
          _limitError = e.message;
          _isQuizActive = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${AppLocalizations.of(context)!.quizCouldNotStart}: ${e.toString()}"), backgroundColor: Theme.of(context).colorScheme.error),
        );
        setState(() => _isQuizActive = false);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startQuizSession() {
     _sessionScore = 0;
     _fetchQuizData();
  }

  // Cevaplama ve Streak/Puan Gönderme
  Future<void> _answerQuestion(int selectedIndex) async {
    if (_answered) return;

    setState(() {
      _selectedAnswerIndex = selectedIndex;
      _answered = true;
      _isLoading = true;
    });

    final localizations = AppLocalizations.of(context)!;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    int currentStreakBeforeAnswer = userProvider.profile?.currentStreak ?? 0;
    
    try {
      final response = await _apiService.submitQuizAnswer(
        widget.idToken, 
        _questions[_currentIndex]['id'] as int, 
        selectedIndex
      );
      
      final isCorrect = response['correct'] as bool;
      final scoreAwarded = response['score_awarded'] as int;
      
      if (mounted) {
        if (isCorrect && scoreAwarded > 0) {
           _sessionScore += scoreAwarded; 
           
           // Global skoru provider üzerinden güncelle ve yeni streak'i al
           await userProvider.loadProfile(widget.idToken); 
           int newStreak = userProvider.profile?.currentStreak ?? 0;
           
           // ETKİLEYİCİ POP-UP GÖSTERİMİ
           _showScoreAndStreakPopup(context, localizations, scoreAwarded, currentStreakBeforeAnswer, newStreak, true);
           
        } else if (!isCorrect) {
           // Streak sıfırlandı, UI'da yeni streak'i (0) görmek için profil güncellemesi
           await userProvider.loadProfile(widget.idToken);
           _showScoreAndStreakPopup(context, localizations, 0, currentStreakBeforeAnswer, 0, false);
           _showErrorSnackBar(localizations.wrongAnswerResetStreak); 
        } 
      }
    } on QuizLimitException catch (e) {
       if(mounted) _showErrorSnackBar(e.message);
    } catch (e) {
       if(mounted) _showErrorSnackBar(localizations.errorSubmittingAnswer);
    } finally {
       if (mounted) setState(() => _isLoading = false);
    }

    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
         if (_currentIndex < _questions.length - 1) {
             _nextQuestion();
         } else {
             _fetchQuizData(isInitialLoad: false); 
         }
      }
    });
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedAnswerIndex = null;
        _answered = false;
      });
    } else {
      _showResultDialog(); 
    }
  }
  
  void _showResultDialog() {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text(localizations.quizFinished, style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
        content: Text("${localizations.yourScore}: $_sessionScore ${localizations.pointsEarned}", style: TextStyle(fontSize: 18.sp, color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() => _isQuizActive = false); 
            },
            child: Text(localizations.great, style: TextStyle(color: theme.colorScheme.tertiary, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
  
  // --- SNACKBAR METOTLARI (HATA İÇİN KORUNDU) ---
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Theme.of(context).colorScheme.error,
      duration: const Duration(seconds: 3),
    ));
  }
  
  // YENİ VE DÜZELTİLMİŞ: Etkileyici Pop-up Gösterim Metodu
  void _showScoreAndStreakPopup(BuildContext context, AppLocalizations localizations, int score, int oldStreak, int newStreak, bool isCorrect) {
    if (!mounted) return;
    
    final theme = Theme.of(context);
    
    // Streak Mantığı İçin Yeni Değişkenler
    final bool isStreakBroken = isCorrect == false; // Yanlışsa bozulmuştur
    final bool isMaxStreak = newStreak >= 5 && isCorrect; // Maksimum bonus streak'i 5'tir
    
    // Renk ve Mesajı Ayarlama
    final Color color = isCorrect ? Colors.green.shade600 : theme.colorScheme.error;
    final String mainMessage;

    if (isStreakBroken) {
        mainMessage = localizations.streakBroken;
    } else if (score > 0) {
        // Doğru ve puan kazanıldı
        mainMessage = isMaxStreak 
            ? localizations.maxStreak 
            : "${newStreak}x ${localizations.streakBonus}";
    } else {
        // Doğru bilindi ancak puan 0 (zaten cevaplanmıştı)
        mainMessage = localizations.correct;
    }

    final OverlayEntry overlayEntry = OverlayEntry(
      builder: (context) {
        return Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: scale,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 30.w, vertical: 20.h),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20.r),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10)]
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Puan Kazanımı (Yanlışsa gösterme)
                        if (score > 0)
                          Text(
                            '+$score ${localizations.points}',
                            style: TextStyle(
                              fontSize: 32.sp,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        if (score > 0) SizedBox(height: 10.h),
                        
                        // Streak Mesajı
                        Text(mainMessage, style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );

    Overlay.of(context).insert(overlayEntry);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) overlayEntry.remove();
    });
  }


  Color _getOptionColor(int index) {
    if (!_answered) return Theme.of(context).colorScheme.surface.withOpacity(0.5);
    if (_questions.isEmpty) return Theme.of(context).colorScheme.surface.withOpacity(0.5);
    
    int correctIndex = _questions[_currentIndex]['correct_answer_index'];
    if (index == correctIndex) return Colors.green.withOpacity(0.7);
    if (index == _selectedAnswerIndex) return Theme.of(context).colorScheme.error.withOpacity(0.7);
    return Theme.of(context).colorScheme.surface.withOpacity(0.3);
  }

  // --- BUILD METOTLARI ---

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final userProvider = Provider.of<UserProvider>(context);
    final currentStreak = userProvider.profile?.currentStreak ?? 0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Arka Plan
          AnimatedBuilder(
            animation: _backgroundController,
            builder: (context, child) {
              return Stack(
                children: [
                  Positioned.fill(child: Align(alignment: _backgroundAnimation1.value, child: Container(width: 400.w, height: 400.h, decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.tertiary.withOpacity(0.15), boxShadow: [BoxShadow(color: theme.colorScheme.tertiary.withOpacity(0.1), blurRadius: 100.r, spreadRadius: 80.r)])))),
                  Positioned.fill(child: Align(alignment: _backgroundAnimation2.value, child: Container(width: 300.w, height: 300.h, decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.primary.withOpacity(0.15), boxShadow: [BoxShadow(color: theme.colorScheme.primary.withOpacity(0.1), blurRadius: 100.r, spreadRadius: 60.r)])))),
                ],
              );
            },
          ),
          
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: ScaleTransition(scale: animation, child: child)),
            // Quiz aktifse ve sorular varsa, quiz ekranını göster.
            child: _isQuizActive && _questions.isNotEmpty
              ? _buildQuizView(context, localizations, theme, currentStreak)
              : _buildStartView(context, localizations, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildStartView(BuildContext context, AppLocalizations localizations, ThemeData theme) {
    // Limit aşıldıysa özel view göster
    if (_limitError != null) {
      return _buildLimitExceededView(context, localizations, theme);
    }
    
    // Yükleniyor veya Quiz bitmiş durumda başlangıç tuşunu göster
    return Center(
      key: const ValueKey('startView'),
      child: _isLoading
          ? CircularProgressIndicator(color: theme.colorScheme.primary)
          : ElevatedButton.icon(
              icon: Icon(Icons.play_arrow_rounded, size: 28.sp),
              label: Text(localizations.startNewQuiz, style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 16.h)),
              onPressed: _startQuizSession,
            ),
    );
  }
  
  Widget _buildLimitExceededView(BuildContext context, AppLocalizations localizations, ThemeData theme) {
    return Center(
      key: const ValueKey('limitExceededView'),
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, size: 60.sp, color: theme.colorScheme.error),
            SizedBox(height: 20.h),
            Text(localizations.limitExceeded, style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.error)),
            SizedBox(height: 10.h),
            Text(_limitError ?? localizations.upgrade, textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 16.sp)),
            SizedBox(height: 30.h),
            ElevatedButton(
              onPressed: () {
                final mainScreenState = context.findAncestorStateOfType<MainScreenState>();
                if (mainScreenState != null) {
                    mainScreenState.onItemTapped(1); 
                }
              },
              child: Text(localizations.upgrade),
              style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.secondary),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildQuizView(BuildContext context, AppLocalizations localizations, ThemeData theme, int currentStreak) {
    
    return Padding(
      key: const ValueKey('quizView'),
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          SafeArea(
            child: Column(
              children: [
                LinearProgressIndicator(value: (_currentIndex + 1) / _questions.length, backgroundColor: theme.cardTheme.color, color: theme.colorScheme.tertiary, minHeight: 8.h, borderRadius: BorderRadius.circular(4.r)),
                SizedBox(height: 16.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("${localizations.question} ${_currentIndex + 1}/${_questions.length}", style: TextStyle(color: theme.colorScheme.tertiary, fontSize: 18.sp, fontWeight: FontWeight.bold)),
                    // YENİ: Streak Gösterimi
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(color: theme.colorScheme.secondary)
                      ),
                      child: Text("${localizations.streak}: $currentStreak", style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold, fontSize: 14.sp)),
                    )
                  ],
                ),
              ],
            ),
          ),
          
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (Widget child, Animation<double> animation) {
                final inAnimation = Tween<Offset>(begin: const Offset(0.0, 1.0), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
                final outAnimation = Tween<Offset>(begin: const Offset(0.0, -1.0), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
                
                if (child.key == ValueKey<int>(_currentIndex)) {
                   return ClipRect(child: SlideTransition(position: inAnimation, child: FadeTransition(opacity: animation, child: child)));
                } else {
                   return ClipRect(child: SlideTransition(position: outAnimation, child: FadeTransition(opacity: ReverseAnimation(animation), child: child)));
                }
              },
              child: _buildQuestionCard(key: ValueKey<int>(_currentIndex)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard({required Key key}) {
    final theme = Theme.of(context);
    final currentQuestion = _questions[_currentIndex];
    final options = currentQuestion['options'] as List<dynamic>; 

    return Column(
      key: key,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.all(24.w),
          decoration: BoxDecoration(color: theme.colorScheme.surface.withOpacity(0.5), borderRadius: BorderRadius.circular(20.r)),
          child: Text(currentQuestion['question_text'], textAlign: TextAlign.center, style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        SizedBox(height: 30.h),
        ...List.generate(options.length, (index) {
          final isCorrect = index == currentQuestion['correct_answer_index'];
          final isSelected = index == _selectedAnswerIndex;
          
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            child: InkWell(
              onTap: _answered ? null : () => _answerQuestion(index),
              borderRadius: BorderRadius.circular(16.r),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                decoration: BoxDecoration(
                  color: _getOptionColor(index),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: theme.colorScheme.primary.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(options[index], style: TextStyle(fontSize: 18.sp, color: Colors.white))),
                    AnimatedOpacity(
                      opacity: _answered && (isSelected || isCorrect) ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 400),
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