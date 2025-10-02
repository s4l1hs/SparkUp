import 'dart:convert';
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

class _QuizPageState extends State<QuizPage> {
  final ApiService _apiService = ApiService();

  bool _isQuizActive = false;
  bool _isLoading = false;

  List<Map<String, dynamic>> _questions = [];
  int _currentIndex = 0;
  int _score = 0;
  int? _selectedAnswerIndex;
  bool _answered = false;

  Future<void> _startNewQuiz() async {
    setState(() => _isLoading = true);
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context); // DEĞİŞİKLİK: Temayı alıyoruz
    try {
      final questions = await _apiService.getQuizQuestions(widget.idToken);
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
          // DEĞİŞİKLİK: Hata rengi temadan alınıyor
          SnackBar(content: Text("${localizations.quizCouldNotStart}: $e"), backgroundColor: theme.colorScheme.error),
        );
      }
    }
  }

  void _answerQuestion(int selectedIndex) {
    if (_answered) return;
    setState(() {
      _selectedAnswerIndex = selectedIndex;
      _answered = true;
      if (selectedIndex == _questions[_currentIndex]['correct_answer_index']) {
        _score++;
      }
    });
    Future.delayed(const Duration(milliseconds: 1500), () {
      if(mounted) _nextQuestion();
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
        title: Text(localizations.quizFinished, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20.sp)),
        content: Text("${localizations.yourScore}: $_score / ${_questions.length}", style: TextStyle(fontSize: 16.sp)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() => _isQuizActive = false);
            },
            child: Text(localizations.great, style: TextStyle(color: theme.colorScheme.tertiary)),
          )
        ],
      ),
    );
  }

  Color _getOptionColor(int index) {
    final theme = Theme.of(context); // DEĞİŞİKLİK: Temayı alıyoruz
    if (!_answered) return theme.cardTheme.color!; // DEĞİŞİKLİK: Temanın kart rengi
    int correctIndex = _questions[_currentIndex]['correct_answer_index'];
    if (index == correctIndex) return Colors.green.shade700; // Yeşil belirginlik için kalabilir. Alternatif: theme.colorScheme.secondary
    if (index == _selectedAnswerIndex) return theme.colorScheme.error; // DEĞİŞİKLİK: Temanın hata rengi
    return theme.cardTheme.color!; // DEĞİŞİKLİK: Temanın kart rengi
  }

  @override
Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (!_isQuizActive) {
      return Center(
        child: _isLoading
            ? CircularProgressIndicator(color: theme.colorScheme.primary) 
            : ElevatedButton.icon(
                icon: Icon(Icons.play_arrow_rounded, size: 28.sp),
                label: Text(localizations.startNewQuiz, style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 16.h),
                ),
                onPressed: _startNewQuiz,
              ),
      );
    }

    if (_questions.isEmpty) {
      return Center(child: Text(localizations.questionDataIsEmpty, style: TextStyle(color: Colors.grey.shade400)));
    }
    final options = jsonDecode(_questions[_currentIndex]['options']) as List<dynamic>;

    return Scaffold(
      body: _questions.isEmpty
          ? Center(child: Text(localizations.questionDataIsEmpty, style: TextStyle(color: Colors.grey.shade400)))
          : Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // YENİ EKLENDİ: Soru ilerleme çubuğu
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    child: LinearProgressIndicator(
                      value: (_currentIndex + 1) / _questions.length,
                      backgroundColor: theme.cardTheme.color,
                      color: theme.colorScheme.tertiary, // <<< TERTİARY RENK KULLANIMI
                      minHeight: 6.h,
                      borderRadius: BorderRadius.circular(3.r),
                    ),
                  ),
                  
                  // DEĞİŞİKLİK: Soru sayısını üçüncül renk ile vurguluyoruz
                  Text(
                    "${localizations.question} ${_currentIndex + 1}/${_questions.length}", 
                    textAlign: TextAlign.center, 
                    style: TextStyle(
                      color: theme.colorScheme.tertiary, // <<< TERTİARY RENK KULLANIMI
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold
                    )
                  ),
                  SizedBox(height: 16.h),
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(color: theme.cardTheme.color, borderRadius: BorderRadius.circular(12.r)),
                    child: Text(_questions[_currentIndex]['question_text'], textAlign: TextAlign.center, style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                  const Spacer(),
                  ...List.generate(options.length, (index) {
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      child: InkWell(
                        onTap: () => _answerQuestion(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: _getOptionColor(index), 
                            borderRadius: BorderRadius.circular(12.r), 
                            border: Border.all(color: theme.colorScheme.primary.withOpacity(0.5))
                          ),
                          child: Text(options[index], style: TextStyle(fontSize: 18.sp, color: Colors.white)),
                        ),
                      ),
                    );
                  }),
                  const Spacer(),
                ],
              ),
            ),
    );
  }
}