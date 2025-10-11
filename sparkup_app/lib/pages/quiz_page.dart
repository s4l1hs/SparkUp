import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../services/api_service.dart';
import '../l10n/app_localizations.dart';

class QuizPage extends StatefulWidget {
  final String idToken;
  const QuizPage({super.key, required this.idToken});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();

  bool _isQuizActive = false;
  bool _isLoading = false;

  List<Map<String, dynamic>> _questions = [];
  int _currentIndex = 0;
  int _score = 0;
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
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    super.dispose();
  }

  // --- API ve QUIZ MANTIĞI ---
  Future<void> _startNewQuiz() async {
    setState(() => _isLoading = true);
    final localizations = AppLocalizations.of(context)!;
    try {
      // Backend'den 10 soru çekiyoruz
      final questions = await _apiService.getQuizQuestions(widget.idToken, limit: 10);
      if (mounted) {
        setState(() {
          _questions = questions;
          _currentIndex = 0;
          _score = 0;
          _selectedAnswerIndex = null;
          _answered = false;
          _isQuizActive = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${localizations.quizCouldNotStart}: $e"), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    }
  }

  void _answerQuestion(int selectedIndex) {
    if (_answered) return;

    final isCorrect = selectedIndex == _questions[_currentIndex]['correct_answer_index'];
    setState(() {
      _selectedAnswerIndex = selectedIndex;
      _answered = true;
      if (isCorrect) {
        _score++;
        // TODO: _apiService.submitAnswer(questionId, isCorrect) gibi bir çağrı ile backend'e puanı kaydet
      }
    });

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) _nextQuestion();
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
        content: Text("${localizations.yourScore}: $_score / ${_questions.length}", style: TextStyle(fontSize: 18.sp, color: Colors.white)),
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

  Color _getOptionColor(int index) {
    if (!_answered) return Theme.of(context).colorScheme.surface.withOpacity(0.5);
    int correctIndex = _questions[_currentIndex]['correct_answer_index'];
    if (index == correctIndex) return Colors.green.withOpacity(0.7);
    if (index == _selectedAnswerIndex) return Theme.of(context).colorScheme.error.withOpacity(0.7);
    return Theme.of(context).colorScheme.surface.withOpacity(0.3);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // YENİ: Canlı Arka Plan Eklendi
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
            child: !_isQuizActive
              ? _buildStartView(context, localizations, theme)
              : _buildQuizView(context, localizations, theme),
          ),
        ],
      ),
    );
  }

  // --- YARDIMCI BUILD METOTLARI ---
  Widget _buildStartView(BuildContext context, AppLocalizations localizations, ThemeData theme) {
    return Center(
      key: const ValueKey('startView'),
      child: _isLoading
          ? CircularProgressIndicator(color: theme.colorScheme.primary)
          : ElevatedButton.icon(
              icon: Icon(Icons.play_arrow_rounded, size: 28.sp),
              label: Text(localizations.startNewQuiz, style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 16.h)),
              onPressed: _startNewQuiz,
            ),
    );
  }

  Widget _buildQuizView(BuildContext context, AppLocalizations localizations, ThemeData theme) {
    if (_questions.isEmpty) {
      return Center(key: const ValueKey('emptyView'), child: Text(localizations.questionDataIsEmpty, style: TextStyle(color: Colors.grey.shade400)));
    }
    
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
                Text("${localizations.question} ${_currentIndex + 1}/${_questions.length}", style: TextStyle(color: theme.colorScheme.tertiary, fontSize: 18.sp, fontWeight: FontWeight.bold)),
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
              onTap: () => _answerQuestion(index),
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