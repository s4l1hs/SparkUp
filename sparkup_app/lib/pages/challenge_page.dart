import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
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
  int? _currentChallengeId;
  bool _isLoading = false;
  String? _limitError;
  String? _generalError;

  late final AnimationController _backgroundController;
  late final Animation<Alignment> _backgroundAnimation1;
  late final Animation<Alignment> _backgroundAnimation2;
  late final AnimationController _pulseController;
  bool _isPressed = false;

  // track last locale to refresh localized text without consuming limit
  String? _lastLocale;

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

    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final localeCode = Localizations.localeOf(context).languageCode;
    if (_lastLocale != localeCode) {
      _lastLocale = localeCode;
      if (!_isLoading && _challengeText != null && _currentChallengeId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          try {
            final localized = await _api_apiSafe(() => _apiService.getLocalizedChallenge(widget.idToken, _currentChallengeId!, lang: localeCode), const Duration(seconds: 8));
            if (!mounted) return;
            if (localized is Map && localized['challenge_text'] is String) {
              setState(() {
                _challengeText = localized['challenge_text'] as String?;
              });
            }
          } catch (e) {
            debugPrint("Failed to localize active challenge: $e");
          }
        });
      } else {
        // check limits on open but DO NOT consume (preview=false)
        if (!_isLoading) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _fetchChallenge(preview: false, consume: false));
        }
      }
    }
  }

  Future<void> _fetchChallenge({bool preview = false, bool consume = true}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _limitError = null;
      _generalError = null;
    });

    final localizations = AppLocalizations.of(context);
    final fallbackMsg = localizations?.challengeCouldNotBeLoaded ?? "Challenge could not be loaded";

    try {
      final lang = Localizations.localeOf(context).languageCode;
      final challengeData = await _api_apiSafe(() => _apiService.getRandomChallenge(widget.idToken, lang: lang, preview: preview), const Duration(seconds: 12));
      if (!mounted) return;

      if (challengeData is Map) {
        final text = challengeData['challenge_text'];
        final id = challengeData['id'];
        setState(() {
          _challengeText = (text is String) ? text : (_challengeText ?? '');
          _currentChallengeId = (id is int) ? id : _currentChallengeId;
          _limitError = null;
          _generalError = null;
        });
        _pulseController.forward(from: 0);
      } else {
        // unexpected response shape
        setState(() {
          _generalError = fallbackMsg;
        });
      }
    } catch (e) {
      if (!mounted) return;
      final errString = e.toString();

      try {
        final maybeMessage = (e as dynamic).message;
        if (maybeMessage is String && (errString.toLowerCase().contains('limit') || e.runtimeType.toString().toLowerCase().contains('limit'))) {
          setState(() => _limitError = maybeMessage);
          return;
        }
      } catch (_) {
        // ignore
      }

      if (errString.toLowerCase().contains('limit') || e.runtimeType.toString().toLowerCase().contains('limit')) {
        setState(() => _limitError = errString);
      } else {
        setState(() {
          _generalError = fallbackMsg;
        });
        debugPrint("Challenge yükleme hatası: $e");
      }
    } finally {
      if (mounted) setState(() {
        _isLoading = false;
      });
    }
  }

  Future<dynamic> _api_apiSafe(Future<dynamic> Function() fn, Duration timeout) {
    return fn().timeout(timeout, onTimeout: () => throw TimeoutException("API timeout"));
  }

  Future<void> _copyChallenge() async {
    if (_challengeText == null || _challengeText!.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _challengeText!));
    if (mounted) {
      final msg = AppLocalizations.of(context)?.copiedToClipboard ?? 'Copied';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    Widget currentContent;

    if (_isLoading) {
      currentContent = _buildLoadingView(theme, localizations);
    } else if (_limitError != null) {
      currentContent = _buildLimitExceededView(localizations, theme, _limitError!);
    } else if (_generalError != null) {
      currentContent = Padding(
        key: const ValueKey('error'),
        padding: EdgeInsets.all(16.w),
        child: Text("${localizations.error}: $_generalError", textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.error, fontSize: 18.sp)),
      );
    } else if (_challengeText != null && _challengeText!.isNotEmpty) {
      currentContent = _buildChallengeView(theme, localizations);
    } else {
      currentContent = _buildEmptyState(theme, localizations);
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
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
                        width: 420.w,
                        height: 420.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [theme.colorScheme.primary.withOpacity(0.16), Colors.transparent]),
                          boxShadow: [BoxShadow(color: theme.colorScheme.primary.withOpacity(0.08), blurRadius: 80.r, spreadRadius: 60.r)],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Align(
                      alignment: _backgroundAnimation2.value,
                      child: Container(
                        width: 320.w,
                        height: 320.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [theme.colorScheme.secondary.withOpacity(0.12), Colors.transparent]),
                          boxShadow: [BoxShadow(color: theme.colorScheme.secondary.withOpacity(0.06), blurRadius: 80.r, spreadRadius: 40.r)],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // main centered card
          SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 28.h),
                child: GestureDetector(
                  onTapDown: (_) => setState(() => _isPressed = true),
                  onTapUp: (_) => setState(() => _isPressed = false),
                  onTapCancel: () => setState(() => _isPressed = false),
                  onTap: (_isLoading || _limitError != null) ? null : () => _fetchChallenge(preview: false, consume: true),
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 150),
                    scale: _isPressed ? 0.98 : 1.0,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 720.w),
                      child: LayoutBuilder(builder: (context, constraints) {
                        final cardHeight = constraints.maxWidth * 0.95;
                        return SizedBox(
                          height: cardHeight,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(26.r),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                              child: Container(
                                padding: EdgeInsets.all(18.w),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [theme.colorScheme.surface.withOpacity(0.18), theme.colorScheme.surface.withOpacity(0.06)]),
                                  borderRadius: BorderRadius.circular(26.r),
                                  border: Border.all(color: Colors.white.withOpacity(0.04)),
                                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 24.r, offset: Offset(0, 12.h))],
                                ),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 420),
                                  transitionBuilder: (Widget child, Animation<double> animation) {
                                    final offsetAnimation = Tween<Offset>(begin: const Offset(0.0, 0.1), end: Offset.zero).animate(animation);
                                    return FadeTransition(opacity: animation, child: SlideTransition(position: offsetAnimation, child: child));
                                  },
                                  child: currentContent,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // top controls removed as requested
         ],
       ),
     );
   }

  Widget _buildLoadingView(ThemeData theme, AppLocalizations localizations) {
    return Center(
      key: const ValueKey('loading'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: Tween(begin: 0.96, end: 1.06).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)),
            child: Container(
              width: 110.w,
              height: 110.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [theme.colorScheme.primary, theme.colorScheme.secondary]),
                boxShadow: [BoxShadow(color: theme.colorScheme.primary.withOpacity(0.18), blurRadius: 18.r, offset: Offset(0,8.h))],
              ),
              child: Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
            ),
          ),
          SizedBox(height: 18.h),
          Text(localizations.loading, style: TextStyle(color: Colors.white70, fontSize: 16.sp)),
          SizedBox(height: 6.h),
          Text(localizations.pleaseWait, style: TextStyle(color: Colors.white30, fontSize: 12.sp)),
        ],
      ),
    );
  }

  Widget _buildChallengeView(ThemeData theme, AppLocalizations localizations) {
    return Padding(
      key: ValueKey<String>(_challengeText ?? 'challenge'),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // badge header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [theme.colorScheme.secondary.withOpacity(0.95), theme.colorScheme.primary.withOpacity(0.95)]),
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12.r, offset: Offset(0,6.h))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.whatshot_rounded, color: Colors.white, size: 18.sp),
                SizedBox(width: 8.w),
                Text(localizations.challenge, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.sp)),
              ],
            ),
          ),

          SizedBox(height: 18.h),

          // challenge text
          Expanded(
            child: SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              child: Column(
                children: [
                  Text(
                    _challengeText ?? '',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w800, color: Colors.white, height: 1.4),
                  ),
                  SizedBox(height: 22.h),
                  Text(localizations.hintTapToReload, textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 13.sp)),
                ],
              ),
            ),
          ),

          SizedBox(height: 12.h),

          // actions row
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading || _limitError != null ? null : () => _fetchChallenge(preview: false, consume: true),
                  icon: Icon(Icons.refresh_rounded, color: Colors.white),
                  label: Text(localizations.loadNewChallenge),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    backgroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                    elevation: 8,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              ElevatedButton(
                onPressed: _challengeText != null && _challengeText!.isNotEmpty ? _copyChallenge : null,
                child: Icon(Icons.bookmark_add_outlined, color: Colors.white),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 12.w),
                  backgroundColor: Colors.white10,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, AppLocalizations localizations) {
    return Center(
      key: const ValueKey('start'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.touch_app_outlined, size: 64.sp, color: theme.colorScheme.secondary),
          SizedBox(height: 20.h),
          Text(localizations.tapToLoadNewChallenge, textAlign: TextAlign.center, style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold, color: Colors.white)),
          SizedBox(height: 10.h),
          Text(localizations.challengeIntro, textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildLimitExceededView(AppLocalizations localizations, ThemeData theme, String message) {
    return Padding(
      key: const ValueKey('limitExceeded'),
      padding: EdgeInsets.all(18.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline_rounded, size: 64.sp, color: theme.colorScheme.error),
          SizedBox(height: 16.h),
          Text(localizations.limitExceeded, textAlign: TextAlign.center, style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.error, fontWeight: FontWeight.bold)),
          SizedBox(height: 10.h),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 16.sp)),
          SizedBox(height: 22.h),
          ElevatedButton(
            onPressed: () {
              final mainScreenState = context.findAncestorStateOfType<MainScreenState>();
              if (mainScreenState != null) {
                mainScreenState.onItemTapped(1);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.secondary,
              padding: EdgeInsets.symmetric(horizontal: 26.w, vertical: 14.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
            child: Text(localizations.upgrade),
          ),
        ],
      ),
    );
  }
}