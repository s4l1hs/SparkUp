import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../providers/user_provider.dart';

// UserProfile ve SubscriptionUpdate için (importların artık mevcut olduğunu varsayıyoruz)
// import '../models/user_models.dart'; 

// NOT: Bu sayfada IAP servisi (örneğin in_app_purchase paketi) entegrasyonu
// yapılmamıştır. Satın alma butonları sadece simülasyon amaçlı bir API çağrısı yapar.

class SubscriptionPage extends StatefulWidget {
  final String idToken;
  const SubscriptionPage({super.key, required this.idToken});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  bool _isProcessing = false;

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
      if (mounted) setState(() => _isProcessing = false);
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
        'price': '\$4.99 / ${localizations.month}',
        'features': [
          {'icon': Icons.quiz_outlined, 'text': '5 ${localizations.questionsPerDay}', 'is_pro': true},
          {'icon': Icons.whatshot_outlined, 'text': '5 ${localizations.challengesPerDay}', 'is_pro': true},
          {'icon': Icons.notifications_active_outlined, 'text': '2 ${localizations.notificationsPerDay}', 'is_pro': true},
        ],
      },
      {
        'level': 'ultra',
        'title': localizations.planUltra,
        'color': theme.colorScheme.secondary,
        'price': '\$9.99 / ${localizations.month}',
        'features': [
          {'icon': Icons.quiz_outlined, 'text': localizations.unlimitedQuizzes, 'is_pro': true},
          {'icon': Icons.whatshot_outlined, 'text': localizations.unlimitedChallenges, 'is_pro': true},
          {'icon': Icons.notifications_active_outlined, 'text': '3 ${localizations.notificationsPerDay}', 'is_pro': true},
        ],
      },
    ];

    return Scaffold(
      appBar: AppBar(
        // remove visible title as requested
        title: const SizedBox.shrink(),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero header
            SizedBox(height: 8.h),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [theme.colorScheme.primary.withOpacity(0.18), theme.colorScheme.secondary.withOpacity(0.06)],
                      ),
                      borderRadius: BorderRadius.circular(16.r),
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10.r, offset: Offset(0,6.h))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(localizations.chooseYourPlan, style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800, color: Colors.white)),
                        SizedBox(height: 6.h),
                        Text(localizations.subscriptionNote, style: TextStyle(fontSize: 13.sp, color: Colors.white70)),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Container(
                  width: 64.w,
                  height: 64.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [theme.colorScheme.primary, theme.colorScheme.secondary]),
                    boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 12.r, offset: Offset(0,6.h))],
                  ),
                  child: Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 32.sp),
                )
              ],
            ),
            SizedBox(height: 20.h),

            // Horizontal plans
            SizedBox(
              height: 420.h,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: plans.length,
                physics: BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  final plan = plans[index];
                  return Padding(
                    padding: EdgeInsets.only(right: 16.w),
                    child: _buildSubscriptionCard(theme, localizations, plan, currentLevel),
                  );
                },
              ),
            ),
            SizedBox(height: 18.h),
            Center(
              child: Text(localizations.subscriptionNote, style: TextStyle(color: Colors.grey.shade400, fontSize: 12.sp), textAlign: TextAlign.center),
            ),
            SizedBox(height: 8.h),
            if (_isProcessing) Center(child: Padding(padding: EdgeInsets.only(top: 8.h), child: CircularProgressIndicator()))
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard(ThemeData theme, AppLocalizations localizations, Map<String, dynamic> plan, String currentLevel) {
    final bool isCurrent = plan['level'] == currentLevel;
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
        child: Container(
          width: 320.w,
          padding: EdgeInsets.all(18.w),
          decoration: BoxDecoration(
            gradient: isCurrent
                ? LinearGradient(colors: [cardColor.withOpacity(0.22), cardColor.withOpacity(0.06)])
                : LinearGradient(colors: [Colors.white10, Colors.white12]),
            borderRadius: BorderRadius.circular(20.r),
            border: isCurrent ? Border.all(color: cardColor.withOpacity(0.9), width: 2.w) : Border.all(color: Colors.white12),
            boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 18.r, offset: Offset(0,10.h))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ribbon + title
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(8.r)),
                          child: Text(plan['title'] as String, style: TextStyle(color: Colors.black87, fontSize: 18.sp, fontWeight: FontWeight.w900)),
                        ),
                        SizedBox(width: 8.w),
                        if (!isFree)
                          Text(plan['price'] as String, style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  if (isCurrent)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(localizations.current, style: TextStyle(color: cardColor, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              SizedBox(height: 12.h),

              // accent separator
              Container(height: 2.h, width: 60.w, decoration: BoxDecoration(gradient: LinearGradient(colors: [cardColor, cardColor.withOpacity(0.6)]), borderRadius: BorderRadius.circular(12.r))),
              SizedBox(height: 14.h),

              // features
              ...((plan['features'] as List<Map<String, dynamic>>).map((feature) {
                final bool featureActive = !(planLevel == 'free' && !(feature['is_pro'] as bool));
                final Color iconColor = featureActive ? (planLevel == 'ultra' ? theme.colorScheme.secondary : (planLevel == 'pro' ? theme.colorScheme.primary : Colors.grey)) : Colors.grey.shade600;
                final Color textColor = featureActive ? Colors.white : Colors.grey.shade500;
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  child: Row(
                    children: [
                      Container(
                        width: 36.w,
                        height: 36.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: featureActive ? iconColor.withOpacity(0.18) : Colors.white10,
                        ),
                        child: Icon(feature['icon'] as IconData, size: 18.sp, color: iconColor),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(child: Text(feature['text'] as String, style: TextStyle(color: textColor, fontSize: 15.sp))),
                      if (!featureActive) Padding(padding: EdgeInsets.only(left: 8.w), child: Text(localizations.limited, style: TextStyle(color: Colors.grey.shade500, fontSize: 12.sp))),
                    ],
                  ),
                );
              })).toList(),

              const Spacer(),

              // CTA
              SizedBox(
                width: double.infinity,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 320),
                        opacity: isCurrent ? 0.0 : 1.0,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [cardColor.withOpacity(0.95), cardColor.withOpacity(0.7)]),
                            borderRadius: BorderRadius.circular(12.r),
                            boxShadow: [BoxShadow(color: cardColor.withOpacity(0.24), blurRadius: 12.r, offset: Offset(0,6.h))],
                          ),
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: isCurrent || _isProcessing ? null : () => _simulatePurchase(planLevel),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isCurrent ? Colors.grey.shade800 : Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!isCurrent) Icon(Icons.workspace_premium_rounded, color: Colors.white),
                          SizedBox(width: 8.w),
                          Text(
                            isCurrent ? localizations.active : (isFree ? localizations.freeTrial : localizations.upgrade),
                            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}