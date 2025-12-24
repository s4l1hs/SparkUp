import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../providers/analysis_provider.dart';
import '../l10n/app_localizations.dart';

class AnalysisPage extends StatefulWidget {
  final String idToken;
  const AnalysisPage({super.key, required this.idToken});

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final prov = Provider.of<AnalysisProvider>(context, listen: false);
        prov.refresh(widget.idToken);
      } catch (_) {}
    });
  }

  // Başarı oranına göre renk döndüren yardımcı fonksiyon
  Color _getPerformanceColor(int percent, ColorScheme scheme) {
    if (percent >= 80) return Colors.greenAccent.shade700;
    if (percent >= 50) return Colors.orangeAccent.shade700;
    return scheme.error;
  }

  String _localizedCategory(String rawCategory, BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final key = rawCategory.toLowerCase();
    switch (key) {
      case 'history':
        return loc.category_history;
      case 'science':
        return loc.category_science;
      case 'art':
        return loc.category_art;
      case 'sports':
        return loc.category_sports;
      case 'technology':
        return loc.category_technology;
      case 'cinema_tv':
        return loc.category_cinema_tv;
      case 'music':
        return loc.category_music;
      case 'nature_animals':
        return loc.category_nature_animals;
      case 'geography_travel':
        return loc.category_geography_travel;
      case 'mythology':
        return loc.category_mythology;
      case 'philosophy':
        return loc.category_philosophy;
      case 'literature':
        return loc.category_literature;
      case 'space_astronomy':
        return loc.category_space_astronomy;
      case 'health_fitness':
        return loc.category_health_fitness;
      case 'economics_finance':
        return loc.category_economics_finance;
      case 'architecture':
        return loc.category_architecture;
      case 'video_games':
        return loc.category_video_games;
      case 'general_culture':
        return loc.category_general_culture;
      case 'fun_facts':
        return loc.category_fun_facts;
      default:
        final pretty = rawCategory.replaceAll('_', ' ');
        if (pretty.isEmpty) return rawCategory;
        return pretty[0].toUpperCase() + pretty.substring(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prov = Provider.of<AnalysisProvider>(context);
    final loc = AppLocalizations.of(context)!;

    final avgPercent = prov.items.isEmpty
        ? 0
        : (prov.items
                .map((e) => (e['percent'] ?? 0) as int)
                .reduce((a, b) => a + b) ~/
            prov.items.length);

    return Scaffold(
      backgroundColor:
          theme.colorScheme.surface, // Arka planı hafif gri/beyaz tutuyoruz
      body: Stack(
        children: [
          // Arka plana hafif dekoratif bir gradient veya desen atabiliriz (Opsiyonel)
          Positioned(
            top: -100.h,
            right: -100.w,
            child: Container(
              width: 300.w,
              height: 300.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withOpacity(0.05),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 10.h),
                  // Başlık
                  Text(
                    loc.performance_title,
                    style: TextStyle(
                      fontSize: 28.sp,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    loc.performance_subtitle,
                    style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                        fontSize: 14.sp),
                  ),

                  SizedBox(height: 24.h),

                  // --- HERO CARD (Genel Durum) ---
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.secondary
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24.r),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.4),
                          blurRadius: 20.r,
                          offset: Offset(0, 10.h),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              loc.overall_score,
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600),
                            ),
                            SizedBox(height: 8.h),
                            // Animasyonlu Sayı
                            TweenAnimationBuilder<int>(
                              tween: IntTween(begin: 0, end: avgPercent),
                              duration: const Duration(milliseconds: 1500),
                              curve: Curves.easeOutExpo,
                              builder: (context, value, child) {
                                return Text(
                                  '$value%',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 42.sp,
                                      fontWeight: FontWeight.bold),
                                );
                              },
                            ),
                            SizedBox(height: 4.h),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8.w, vertical: 4.h),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Text(
                                avgPercent > 70
                                    ? loc.excellent_job
                                    : loc.keep_pushing,
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w500),
                              ),
                            )
                          ],
                        ),
                        // Sağ tarafa dekoratif bir Progress Circle
                        SizedBox(
                          width: 80.w,
                          height: 80.w,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CircularProgressIndicator(
                                value: avgPercent / 100,
                                strokeWidth: 8.w,
                                backgroundColor: Colors.white.withOpacity(0.2),
                                valueColor:
                                    const AlwaysStoppedAnimation(Colors.white),
                                strokeCap: StrokeCap.round,
                              ),
                              Center(
                                child: Icon(Icons.insights,
                                    color: Colors.white, size: 32.sp),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24.h),

                  Text(
                    loc.category_breakdown,
                    style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface),
                  ),
                  SizedBox(height: 12.h),

                  // --- LİSTE VE DURUMLAR ---
                  if (prov.isLoading)
                    Expanded(
                        child: Center(
                            child: CircularProgressIndicator(
                                color: theme.colorScheme.primary))),

                  if (prov.error != null)
                    Expanded(
                        child: Center(
                            child: Text(prov.error!,
                                style: TextStyle(
                                    color: theme.colorScheme.error)))),

                  if (!prov.isLoading && prov.error == null)
                    Expanded(
                      child: prov.items.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.analytics_outlined,
                                      size: 64.sp,
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.2)),
                                  SizedBox(height: 16.h),
                                  Text(loc.no_data_available_yet,
                                      style: TextStyle(
                                          color: theme.colorScheme.onSurface
                                              .withOpacity(0.5))),
                                ],
                              ),
                            )
                          : ListView.separated(
                              physics: const BouncingScrollPhysics(),
                              itemCount: prov.items.length,
                              separatorBuilder: (c, i) =>
                                  SizedBox(height: 16.h),
                              itemBuilder: (c, i) {
                                final it = prov.items[i];
                                final rawCategory =
                                    (it['category'] ?? 'unknown') as String;
                                final category =
                                    _localizedCategory(rawCategory, context);
                                final percent = (it['percent'] ?? 0) as int;
                                final correct = it['correct'] ?? 0;
                                final total = it['total'] ?? 0;

                                // Her bir item için animasyon
                                return TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: 1),
                                  duration: Duration(
                                      milliseconds: 400 +
                                          (i *
                                              100)), // Kademeli giriş (Staggered animation)
                                  curve: Curves.easeOutQuad,
                                  builder: (context, value, child) {
                                    return Opacity(
                                      opacity: value,
                                      child: Transform.translate(
                                        offset: Offset(0, 20 * (1 - value)),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: EdgeInsets.all(16.w),
                                    decoration: BoxDecoration(
                                      color: theme.cardColor,
                                      borderRadius: BorderRadius.circular(20.r),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.04),
                                          blurRadius: 10.r,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                      border: Border.all(
                                          color: theme.colorScheme.outline
                                              .withOpacity(0.05)),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  category,
                                                  style: TextStyle(
                                                      fontSize: 16.sp,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: theme.colorScheme
                                                          .onSurface),
                                                ),
                                                SizedBox(height: 4.h),
                                                Text(
                                                  '$correct / $total ${loc.correct_label}',
                                                  style: TextStyle(
                                                      fontSize: 12.sp,
                                                      color: theme
                                                          .colorScheme.onSurface
                                                          .withOpacity(0.5),
                                                      fontWeight:
                                                          FontWeight.w500),
                                                ),
                                              ],
                                            ),
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: 10.w,
                                                  vertical: 6.h),
                                              decoration: BoxDecoration(
                                                color: _getPerformanceColor(
                                                        percent,
                                                        theme.colorScheme)
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(12.r),
                                              ),
                                              child: Text(
                                                '$percent%',
                                                style: TextStyle(
                                                  color: _getPerformanceColor(
                                                      percent,
                                                      theme.colorScheme),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14.sp,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 12.h),
                                        // Modern Progress Bar
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(10.r),
                                          child: LinearProgressIndicator(
                                            value: percent / 100.0,
                                            minHeight: 10.h,
                                            backgroundColor: theme.colorScheme
                                                .surfaceContainerHighest, // flutter 3.22+ ise, yoksa grey.shade200
                                            valueColor: AlwaysStoppedAnimation(
                                              _getPerformanceColor(
                                                  percent, theme.colorScheme),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  SizedBox(height: 10.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
