import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../services/api_service.dart'; 
import '../l10n/app_localizations.dart';
import '../main_screen.dart'; 

class ChallengePage extends StatefulWidget {
  final String idToken;
  const ChallengePage({super.key, required this.idToken});

  @override
  State<ChallengePage> createState() => _ChallengePageState();
}

class _ChallengePageState extends State<ChallengePage> with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  String? _challengeText;
  bool _isLoading = false;
  String? _limitError;
  String? _generalError;

  late final AnimationController _backgroundController;
  late final Animation<Alignment> _backgroundAnimation1;
  late final Animation<Alignment> _backgroundAnimation2;
  bool _isPressed = false; 

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

  Future<void> _fetchChallenge() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _limitError = null;
      _generalError = null;
    });

    try {
      final challengeData = await _apiService.getRandomChallenge(widget.idToken);
      if (mounted) {
        setState(() {
          _challengeText = challengeData['challenge_text'];
        });
      }
    } on ChallengeLimitException catch (e) {
      if (mounted) {
        setState(() {
          _limitError = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _generalError = AppLocalizations.of(context)?.challengeCouldNotBeLoaded ?? "Challenge could not be loaded";
          print("Challenge yükleme hatası: $e");
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context); 

    Widget currentContent;
    
    if (_isLoading) {
      currentContent = Center(key: const ValueKey('loading'), child: CircularProgressIndicator(color: theme.colorScheme.primary));
    } else if (_limitError != null) {
      currentContent = _buildLimitExceededView(localizations, theme, _limitError!);
    } else if (_generalError != null) {
      currentContent = Padding( key: const ValueKey('error'), padding: EdgeInsets.all(16.w), child: Text("${localizations.error}: $_generalError", textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.error, fontSize: 18.sp)),);
    } else if (_challengeText != null) {
      currentContent = Padding( key: ValueKey<String>(_challengeText!), padding: EdgeInsets.all(24.w), child: SingleChildScrollView( child: Column( mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [
              Icon(Icons.whatshot_rounded, size: 60.sp, color: theme.colorScheme.secondary),
              SizedBox(height: 24.h),
              Text(_challengeText!, textAlign: TextAlign.center, style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold, color: Colors.white, height: 1.4)),
              SizedBox(height: 24.h),
              Text(localizations.tapToLoadNewChallenge, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade400, fontSize: 14.sp)),
            ],),), 
      );
    } else {
      currentContent = Center( key: const ValueKey('start'), child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.touch_app_outlined, size: 60.sp, color: theme.colorScheme.secondary),
            SizedBox(height: 24.h),
            // DÜZELTME: Başlangıç metni daha doğru hale getirildi.
            Text(localizations.tapToLoadNewChallenge, style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold, color: Colors.white)),
          ],),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _backgroundController,
            builder: (context, child) {
              return Stack(
                children: [
                  Positioned.fill(child: Align(alignment: _backgroundAnimation1.value, child: Container(width: 400.w, height: 400.h, decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.secondary.withOpacity(0.15), boxShadow: [BoxShadow(color: theme.colorScheme.secondary.withOpacity(0.1), blurRadius: 100.r, spreadRadius: 80.r)])))),
                  Positioned.fill(child: Align(alignment: _backgroundAnimation2.value, child: Container(width: 300.w, height: 300.h, decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.primary.withOpacity(0.15), boxShadow: [BoxShadow(color: theme.colorScheme.primary.withOpacity(0.1), blurRadius: 100.r, spreadRadius: 60.r)])))),
                ],
              );
            },
          ),
          Center(
            child: Padding(
              padding: EdgeInsets.all(24.w),
              child: GestureDetector(
                onTapDown: (_) => setState(() => _isPressed = true),
                onTapUp: (_) => setState(() => _isPressed = false),
                onTapCancel: () => setState(() => _isPressed = false),
                // DÜZELTME: Ana kartın dokunma özelliği, yüklenirken VEYA limit hatası varken devre dışı bırakılır.
                onTap: (_isLoading || _limitError != null) ? null : _fetchChallenge, 
                child: AnimatedScale(
                  scale: _isPressed ? 0.97 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: ConstrainedBox( constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - (2 * 24.w)),
                    child: LayoutBuilder(builder: (context, constraints) {
                        final cardHeight = constraints.maxWidth * 1.50; 
                        return SizedBox( height: cardHeight, child: ClipRRect( borderRadius: BorderRadius.circular(24.r), child: BackdropFilter( filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container( decoration: BoxDecoration( color: theme.colorScheme.surface.withOpacity(0.2), borderRadius: BorderRadius.circular(24.r), border: Border.all(color: Colors.white.withOpacity(0.1))),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 500),
                                  transitionBuilder: (Widget child, Animation<double> animation) {
                                    final offsetAnimation = Tween<Offset>(begin: const Offset(0.0, 0.5), end: Offset.zero).animate(animation);
                                    return FadeTransition( opacity: animation, child: SlideTransition(position: offsetAnimation, child: child));
                                  },
                                  child: currentContent,
                                ),),),),);
                      }),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitExceededView(AppLocalizations localizations, ThemeData theme, String message) {
    return Padding(
      key: const ValueKey('limitExceeded'),
      padding: EdgeInsets.all(24.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline_rounded, size: 60.sp, color: theme.colorScheme.error),
          SizedBox(height: 20.h),
          Text(localizations.limitExceeded, style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.error)),
          SizedBox(height: 10.h),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 16.sp)),
          SizedBox(height: 30.h),
          ElevatedButton(
            onPressed: () {
              final mainScreenState = context.findAncestorStateOfType<MainScreenState>();
              if (mainScreenState != null) {
                mainScreenState.onItemTapped(1); 
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.secondary),
            child: Text(localizations.upgrade),
          )
        ],
      ),
    );
  }
}