// pages/info_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart'; // ApiService'in bir klasör yukarıda olduğunu varsayıyoruz

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
      // ⚠️ idToken'ı API servisine iletiyoruz
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

    return Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: _isLoadingInfo
              ? const CircularProgressIndicator(color: Colors.amber)
              : _error != null
                  ? Text("${localizations.error}: $_error", style: const TextStyle(color: Colors.red))
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          localizations.dailyFact, 
                          style: TextStyle(color: Colors.amber, fontSize: 24.sp, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 24.h),
                        Container(
                          padding: EdgeInsets.all(20.w),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade900.withOpacity(0.5),
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
        backgroundColor: Colors.amber,
        child: const Icon(Icons.refresh, color: Colors.black),
      ),
    );
  }
}