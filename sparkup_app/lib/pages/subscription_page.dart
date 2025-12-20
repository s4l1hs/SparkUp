import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../l10n/app_localizations.dart';
import '../widgets/animated_glass_card.dart';
import '../widgets/morphing_gradient_button.dart';
import '../widgets/app_background.dart';
import '../services/api_service.dart';
import '../providers/user_provider.dart';
import 'package:sparkup_app/utils/color_utils.dart';

// UserProfile ve SubscriptionUpdate için (importların artık mevcut olduğunu varsayıyoruz)
// import '../models/user_models.dart'; 

class SubscriptionPage extends StatefulWidget {
  final String idToken;
  const SubscriptionPage({super.key, required this.idToken});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> with SingleTickerProviderStateMixin {
  bool _isProcessing = false;
  final PageController _pageController = PageController(viewportFraction: 0.78, keepPage: true);
  late final AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  Future<void> _simulatePurchase(String level) async {
    final localizations = AppLocalizations.of(context)!;
    final apiService = ApiService();

    setState(() => _isProcessing = true);
    try {
      await apiService.updateSubscription(widget.idToken, level, 30);
      if (mounted) {
        Provider.of<UserProvider>(context, listen: false).loadProfile(widget.idToken);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.purchaseSuccess), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${localizations.purchaseError}: ${e.toString()}"), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) { setState(() => _isProcessing = false); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final userProvider = Provider.of<UserProvider>(context);
    final currentLevel = userProvider.profile?.subscriptionLevel ?? 'free';

    final List<Map<String, dynamic>> plans = [
      {
        'level': 'free',
        'title': localizations.planFree,
        'color': Colors.grey.shade700,
        'price': localizations.free,
        'multiplier': 1.0,
        'features': [
          {'icon': Icons.quiz_outlined, 'text': '3 ${localizations.questionsPerDay}', 'is_pro': false},
          {'icon': Icons.whatshot_outlined, 'text': '3 ${localizations.challengesPerDay}', 'is_pro': false},
          {'icon': Icons.notifications_active_outlined, 'text': '1 ${localizations.notificationPerDay}', 'is_pro': false},
        ],
      },
      {
        'level': 'pro',
        'title': localizations.planPro,
        'color': theme.colorScheme.primary,
        'price': '\$1.99 / ${localizations.month}',
        'multiplier': 1.5,
        'features': [
          {'icon': Icons.quiz_outlined, 'text': '5 ${localizations.questionsPerDay}', 'is_pro': true},
          {'icon': Icons.whatshot_outlined, 'text': '5 ${localizations.challengesPerDay}', 'is_pro': true},
          {'icon': Icons.notifications_active_outlined, 'text': '2 ${localizations.notificationsPerDay}', 'is_pro': true},
          {'icon': Icons.bolt_outlined, 'text': '1.5X ${localizations.pointsPerQuestion}', 'is_pro': true},
        ],
      },
      {
        'level': 'ultra',
        'title': localizations.planUltra,
        'color': theme.colorScheme.secondary,
        'price': '\$3.99 / ${localizations.month}',
        'multiplier': 2.0,
        'features': [
          {'icon': Icons.quiz_outlined, 'text': localizations.unlimitedQuizzes, 'is_pro': true},
          {'icon': Icons.whatshot_outlined, 'text': localizations.unlimitedChallenges, 'is_pro': true},
          {'icon': Icons.notifications_active_outlined, 'text': '3 ${localizations.notificationsPerDay}', 'is_pro': true},
          {'icon': Icons.bolt_outlined, 'text': '2X ${localizations.pointsPerQuestion}', 'is_pro': true},
        ],
      },
    ];

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: true,
        centerTitle: true,
      ),
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 12.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero card with subtle glass + CTA shortcut
                AnimatedGlassCard(
                  borderRadius: BorderRadius.circular(18.r),
                  padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 14.h),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          localizations.chooseYourPlan,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, fontSize: 18.sp, color: Colors.white),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Container(
                        width: 52.w,
                        height: 52.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.secondary]),
                          boxShadow: [BoxShadow(color: colorWithOpacity(Colors.black, 0.32), blurRadius: 10.r, offset: Offset(0, 6.h))],
                        ),
                        child: Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 26.sp),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 18.h),

                // Make the pageview flexible so it doesn't overflow
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: plans.length,
                    padEnds: true,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      final plan = plans[index];
                      final bool isCurrent = plan['level'] == currentLevel;
                      return Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
                        child: _buildSubscriptionCard(theme, localizations, plan, currentLevel, isCurrent),
                      );
                    },
                  ),
                ),

                SizedBox(height: 12.h),
                if (_isProcessing) Center(child: Padding(padding: EdgeInsets.only(top: 8.h), child: const CircularProgressIndicator())),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard(ThemeData theme, AppLocalizations localizations, Map<String, dynamic> plan, String currentLevel, bool isCurrent) {
    final Color cardColor = plan['color'] as Color;
    final String planLevel = plan['level'] as String;
    final bool isFree = planLevel == 'free';

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 420),
      tween: Tween(begin: 0.98, end: isCurrent ? 1.03 : 1.0),
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: GestureDetector(
        onTap: () {
          if (!isCurrent) _simulatePurchase(planLevel);
        },
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(18.w),
            decoration: BoxDecoration(
              gradient: isCurrent
                  ? LinearGradient(colors: [colorWithOpacity(cardColor, 0.22), colorWithOpacity(cardColor, 0.06)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                  : LinearGradient(colors: [colorWithOpacity(Colors.white, 0.02), colorWithOpacity(Colors.white, 0.01)]),
              borderRadius: BorderRadius.circular(20.r),
              border: isCurrent ? Border.all(color: colorWithOpacity(cardColor, 0.9), width: 1.5.w) : Border.all(color: colorWithOpacity(Colors.white, 0.04)),
              boxShadow: [
                BoxShadow(color: colorWithOpacity(Colors.black, 0.45), blurRadius: 22.r, offset: Offset(0, 12.h)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: title + price badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(10.r)),
                              child: Text(
                                plan['title'] as String,
                                style: TextStyle(color: Colors.black87, fontSize: 12.sp, fontWeight: FontWeight.w900),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                              ),
                            ),
                          ),
                          SizedBox(width: 10.w),
                        ],
                      ),
                    ),
                    SizedBox(width: 8.w),
                    // Price: use FittedBox so long translations don't overflow
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: 120.w),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(plan['price'] as String, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.sp)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                SizedBox(height: 14.h),

                // accent separator
                Container(height: 2.h, width: 80.w, decoration: BoxDecoration(gradient: LinearGradient(colors: [cardColor, colorWithOpacity(cardColor, 0.6)]), borderRadius: BorderRadius.circular(12.r))),
                SizedBox(height: 14.h),

                // features - compact, readable rows
                    Column(
                  children: (plan['features'] as List<Map<String, dynamic>>).map((feature) {
                    final bool featureActive = !(planLevel == 'free' && !(feature['is_pro'] as bool));
                    final Color iconColor = featureActive ? (planLevel == 'ultra' ? theme.colorScheme.secondary : (planLevel == 'pro' ? theme.colorScheme.primary : Colors.grey)) : Colors.grey;
                    final Color textColor = featureActive ? Colors.white : Colors.grey.shade500;
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      child: Row(
                        children: [
                          Container(
                            width: 42.w,
                            height: 42.w,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: featureActive ? colorWithOpacity(iconColor, 0.18) : Colors.white10,
                            ),
                            child: Icon(feature['icon'] as IconData, size: 18.sp, color: iconColor),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(child: Text(feature['text'] as String, style: TextStyle(color: textColor, fontSize: 15.sp), softWrap: true, maxLines: 3, overflow: TextOverflow.ellipsis)),
                          if (!featureActive) Padding(padding: EdgeInsets.only(left: 8.w), child: Text(localizations.limited, style: TextStyle(color: Colors.grey.shade500, fontSize: 12.sp))),
                        ],
                      ),
                    );
                  }).toList(),
                ),

                const Spacer(),

                // CTA area: glass + morphing gradient button with elevation
                SizedBox(
                  width: double.infinity,
                  child: isCurrent
                      ? MorphingGradientButton(
                          onPressed: null,
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          borderRadius: BorderRadius.circular(12.r),
                          colors: [Colors.grey.shade800, Colors.grey.shade700],
                          child: FittedBox(fit: BoxFit.scaleDown, child: Text(localizations.active, style: TextStyle(fontSize: 16.sp))),
                        )
                      : MorphingGradientButton.icon(
                          icon: Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 16.sp),
                          label: FittedBox(fit: BoxFit.scaleDown, child: Text(isFree ? localizations.freeTrial : localizations.upgrade, style: TextStyle(fontSize: 16.sp))),
                          onPressed: _isProcessing ? null : () => _simulatePurchase(planLevel),
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          borderRadius: BorderRadius.circular(12.r),
                          colors: [colorWithOpacity(cardColor, 0.95), colorWithOpacity(cardColor, 0.7)],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}