import 'dart:ui';
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
  
  Future<void> _simulatePurchase(String level) async {
    final localizations = AppLocalizations.of(context)!;
    final apiService = ApiService();

    try {
      // Örnek: 30 günlük abonelik süresi
      await apiService.updateSubscription(widget.idToken, level, 30);
      
      // Kullanıcı verilerini güncelle
      if (mounted) {
        // UserProvider'ı güncelleyerek anında UI güncellemesi tetiklenir
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    
    // UserProvider'dan abonelik seviyesini dinle
    final userProvider = Provider.of<UserProvider>(context);
    final currentLevel = ((userProvider.profile as dynamic)?.subscriptionLevel) ?? 'free';

    // Plan verileri (backend limitleri ile senkronize olmalı)
    final List<Map<String, dynamic>> plans = [
      {
        'level': 'free',
        'title': localizations.planFree,
        'color': Colors.grey.shade600,
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
        'color': theme.colorScheme.primary, // Cyan (Mavi/Yeşilimsi)
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
        // DEĞİŞİKLİK BURADA: Tertiary yerine secondary kullanıldı
        'color': theme.colorScheme.secondary, // Secondary (Turuncu/Kırmızı)
        'price': '\$9.99 / ${localizations.month}',
        'features': [
          {'icon': Icons.quiz_outlined, 'text': localizations.unlimitedQuizzes, 'is_pro': true},
          {'icon': Icons.whatshot_outlined, 'text': localizations.unlimitedChallenges, 'is_pro': true},
          {'icon': Icons.notifications_active_outlined, 'text': '3 ${localizations.notificationsPerDay}', 'is_pro': true},
        ],
      },
    ];

    return Scaffold(
      appBar: AppBar(title: Text(localizations.subscriptions)),
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: ListView(
          children: [
            SizedBox(height: 10.h),
            // 'Choose Your Plan' header removed as requested
            SizedBox(height: 20.h),
            
            // Planları Yatay Kaydırılabilir Liste Olarak Gösterme
            SizedBox(
              height: 550.h,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: plans.length,
                itemBuilder: (context, index) {
                  final plan = plans[index];
                  return Padding(
                    padding: EdgeInsets.only(right: 16.w),
                    child: _buildSubscriptionCard(theme, localizations, plan, currentLevel),
                  );
                },
              ),
            ),
            SizedBox(height: 20.h),
            Center(
              child: Text(localizations.subscriptionNote, style: TextStyle(color: Colors.grey.shade600, fontSize: 12.sp), textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }

  // Abonelik Kartı Widget'ı
  Widget _buildSubscriptionCard(ThemeData theme, AppLocalizations localizations, Map<String, dynamic> plan, String currentLevel) {
    final bool isCurrent = plan['level'] == currentLevel;
    final Color cardColor = plan['color'] as Color;
    final String planLevel = plan['level'] as String;
    final bool isFree = planLevel == 'free';

    return SizedBox(
      width: 300.w,
      child: Card(
        color: theme.colorScheme.surface.withOpacity(0.9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.r),
          side: isCurrent ? BorderSide(color: cardColor, width: 3.w) : BorderSide.none,
        ),
        elevation: 8,
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık ve Rozet
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(plan['title'] as String, style: theme.textTheme.titleLarge?.copyWith(color: cardColor, fontSize: 26.sp, fontWeight: FontWeight.w900)),
                  if (isCurrent)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(color: cardColor.withOpacity(0.2), borderRadius: BorderRadius.circular(10.r)),
                      child: Text(localizations.current, style: TextStyle(color: cardColor, fontWeight: FontWeight.bold, fontSize: 12.sp)),
                    ),
                ],
              ),
              SizedBox(height: 10.h),

              Text(isFree ? '' : plan['price'] as String, style: TextStyle(color: Colors.white, fontSize: 22.sp, fontWeight: FontWeight.bold)),
              SizedBox(height: 20.h),

              ...((plan['features'] as List<Map<String, dynamic>>).map((feature) => _buildFeatureRow(theme, feature, planLevel))).toList(),
              
              const Spacer(),

              // Satın Alma Butonu
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isCurrent || isFree ? null : () => _simulatePurchase(planLevel),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCurrent || isFree ? Colors.grey.shade800 : cardColor,
                    disabledBackgroundColor: Colors.grey.shade800,
                  ),
                  child: Text(isCurrent ? localizations.active : isFree ? localizations.freeTrial : localizations.upgrade, style: TextStyle(fontSize: 18.sp)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Özellik Satırı Widget'ı
  Widget _buildFeatureRow(ThemeData theme, Map<String, dynamic> feature, String planLevel) {
    
    final bool isFree = planLevel == 'free';
    
    // Simge Rengi: Ultra ise secondary, Pro ise primary, Free ise pasif gri
    Color iconColor;
    if (planLevel == 'ultra') {
      iconColor = theme.colorScheme.secondary; // Ultra: Secondary (Turuncu/Kırmızı)
    } else if (planLevel == 'pro') {
      iconColor = theme.colorScheme.primary;  // Pro: Primary (Cyan)
    } else {
      iconColor = Colors.grey.shade700;       // Free: Kısıtlı gri
    }

    // Metin Rengi: Free plandaki kısıtlı özellikler (is_pro: false olanlar) gri olur.
    final Color textColor = isFree && !(feature['is_pro'] as bool) 
        ? Colors.grey.shade500 
        : Colors.white;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        children: [
          Icon(feature['icon'] as IconData, color: iconColor, size: 20.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              feature['text'] as String,
              style: TextStyle(
                color: textColor,
                fontSize: 16.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }
}