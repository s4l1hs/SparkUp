// pages/info_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';

class InfoPage extends StatefulWidget {
  final String idToken;
  const InfoPage({super.key, required this.idToken});

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  final ApiService _apiService = ApiService();
  String? _dailyInfoText;
  String? _dailyInfoSource;
  bool _isLoadingInfo = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDailyInfo();
  }

  Future<void> _fetchDailyInfo() async {
    if (!mounted) return;
    setState(() { _isLoadingInfo = true; _error = null; });
    try {
      final infoData = await _apiService.getRandomInfo(widget.idToken);
      if (mounted) {
        setState(() {
          _dailyInfoText = infoData['info_text'];
          _dailyInfoSource = infoData['source'];
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = "Info could not load: $e");
    } finally {
      if (mounted) setState(() => _isLoadingInfo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context); // DEĞİŞİKLİK: Temayı alıyoruz

    return Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: _isLoadingInfo
              // DEĞİŞİKLİK: Yükleme göstergesi rengi temadan alınıyor
              ? CircularProgressIndicator(color: theme.colorScheme.primary)
              : _error != null
                  // DEĞİŞİKLİK: Hata rengi temadan alınıyor
                  ? Text("${localizations.error}: $_error", style: TextStyle(color: theme.colorScheme.error))
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          localizations.dailyFact, 
                          // DEĞİŞİKLİK: Metin rengi temanın ana rengi yapıldı
                          style: TextStyle(color: theme.colorScheme.primary, fontSize: 24.sp, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 24.h),
                        Container(
                          padding: EdgeInsets.all(20.w),
                          decoration: BoxDecoration(
                            // DEĞİŞİKLİK: Arka plan rengi temadan alınıyor
                            color: theme.cardTheme.color,
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          child: Text(
                            _dailyInfoText ?? localizations.infoNotFound,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 18.sp, height: 1.5),
                          ),
                        ),
                        SizedBox(height: 16.h),
                        if (_dailyInfoSource != null && _dailyInfoSource!.isNotEmpty)
                          Text(
                            "${localizations.source}: $_dailyInfoSource",
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12.sp, fontStyle: FontStyle.italic),
                            textAlign: TextAlign.center,
                          ),
                      ],
                    ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchDailyInfo,
        tooltip: localizations.refresh, 
        // DEĞİŞİKLİK: FAB rengi temadan alınıyor
        backgroundColor: theme.colorScheme.primary,
        child: Icon(Icons.refresh, color: theme.colorScheme.onPrimary), // DEĞİŞİKLİK: İkon rengi de temadan
      ),
    );
  }
}