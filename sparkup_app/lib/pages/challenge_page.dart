import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../services/api_service.dart'; 
import '../l10n/app_localizations.dart';

class ChallengePage extends StatefulWidget {
  final String idToken;
  const ChallengePage({super.key, required this.idToken});

  @override
  State<ChallengePage> createState() => _ChallengePageState();
}

class _ChallengePageState extends State<ChallengePage> {
  final ApiService _apiService = ApiService();
  String? _challengeText;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchChallenge();
  }

  Future<void> _fetchChallenge() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final challengeData = await _apiService.getRandomChallenge(widget.idToken);
      if (mounted) {
        setState(() {
          _challengeText = challengeData['challenge_text'];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = AppLocalizations.of(context)?.challengeCouldNotBeLoaded ?? "Challenge could not be loaded";
          print("Challenge error: $e");
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

    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: InkWell(
          onTap: _isLoading ? null : _fetchChallenge,
          borderRadius: BorderRadius.circular(20.r),
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [theme.cardTheme.color!, Colors.black87],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.5),
                  width: 2,
                ),
              ),
              child: Center(
                child: _isLoading
                    ? CircularProgressIndicator(color: theme.colorScheme.primary)
                    : _error != null
                        ? Padding(
                            padding: EdgeInsets.all(16.w),
                            child: Text(
                              "${localizations.error}: $_error",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          )
                        : Padding(
                            padding: EdgeInsets.all(24.w),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.fitness_center_rounded, size: 60.sp, color: theme.colorScheme.primary),
                                SizedBox(height: 24.h),
                                Text(
                                  _challengeText ?? localizations.noChallengeAvailable,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 22.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    height: 1.4,
                                  ),
                                ),
                                SizedBox(height: 24.h),
                                Text(
                                  localizations.tapToLoadNewChallenge,
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 14.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}