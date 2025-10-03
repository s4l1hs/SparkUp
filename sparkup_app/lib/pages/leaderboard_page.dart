// lib/pages/leaderboard_page.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../services/api_service.dart';
import '../l10n/app_localizations.dart';
import '../models/leaderboard_entry.dart';

class LeaderboardPage extends StatefulWidget {
  final String idToken;
  const LeaderboardPage({super.key, required this.idToken});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  final ApiService _apiService = ApiService();

  List<LeaderboardEntry> _leaderboardData = [];
  bool _isLoading = true;
  bool _isTopicPanelOpen = false;
  Map<String, String> _allTopics = {};
  Set<String> _selectedTopics = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPageData();
  }

  Future<void> _loadPageData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _apiService.getLeaderboard(widget.idToken),
        _apiService.getTopics(),
        _apiService.getUserTopics(widget.idToken),
      ]);
      if (mounted) {
        setState(() {
          _leaderboardData = results[0] as List<LeaderboardEntry>;
          _allTopics = results[1] as Map<String, String>;
          _selectedTopics = (results[2] as List<String>).toSet();
        });
      }
    } catch (e) {
      print("Sayfa verileri yüklenirken hata oluştu: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error Could Not Load Data"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveTopics() async {
    setState(() => _isSaving = true);
    final localizations = AppLocalizations.of(context)!;
    try {
      await _apiService.setUserTopics(widget.idToken, _selectedTopics.toList());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.preferencesSaved), backgroundColor: Colors.green),
        );
        setState(() => _isTopicPanelOpen = false);
        await _loadPageData();
      }
    } catch (e) {
      print("Konular kaydedilirken hata oluştu: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
  
  String _maskEmail(String? email) {
    if (email == null || !email.contains('@')) return 'Anonymous';
    final parts = email.split('@');
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) return '${name[0]}***@${domain.substring(0,1)}...';
    return '${name.substring(0, 2)}***@${domain.substring(0,1)}...';
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
                : Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 16.w),
                        child: Text(localizations.navLeaderboard, style: theme.textTheme.titleLarge?.copyWith(fontSize: 24.sp)),
                      ),
                      Expanded(
                        child: _leaderboardData.isEmpty
                            ? Center(child: Text("No Data Available", style: TextStyle(color: Colors.grey.shade400)))
                            : ListView.builder(
                                padding: EdgeInsets.symmetric(horizontal: 16.w),
                                itemCount: _leaderboardData.length,
                                itemBuilder: (context, index) {
                                  final entry = _leaderboardData[index];
                                  final isTopThree = entry.rank <= 3;
                                  return Card(
                                    color: isTopThree ? theme.colorScheme.primary.withOpacity(0.1) : theme.cardTheme.color,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r), side: BorderSide(color: isTopThree ? theme.colorScheme.primary : Colors.transparent, width: 1.5)),
                                    margin: EdgeInsets.only(bottom: 12.h),
                                    child: ListTile(
                                      leading: CircleAvatar(backgroundColor: theme.colorScheme.surface, child: Text(entry.rank.toString(), style: TextStyle(fontWeight: FontWeight.bold, color: isTopThree ? theme.colorScheme.primary : Colors.white))),
                                      title: Text(_maskEmail(entry.email), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(entry.score.toString(), style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                                          SizedBox(width: 4.w),
                                          Icon(Icons.star_rounded, color: theme.colorScheme.secondary, size: 20.sp),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      SizedBox(height: 80.h),
                    ],
                  ),
          ),
          _buildTopicSelectionPanel(context),
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: FloatingActionButton(
                onPressed: () => setState(() => _isTopicPanelOpen = !_isTopicPanelOpen),
                backgroundColor: theme.colorScheme.tertiary,
                child: Icon(_isTopicPanelOpen ? Icons.close_rounded : Icons.category_rounded, color: theme.colorScheme.onTertiary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicSelectionPanel(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final panelHeight = MediaQuery.of(context).size.height * 0.75;
    
    // DEĞİŞİKLİK: Butonun aktif olup olmayacağını belirleyen değişken
    final bool isSaveButtonEnabled = !_isSaving && _selectedTopics.isNotEmpty;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      bottom: _isTopicPanelOpen ? 0 : -panelHeight,
      left: 0,
      right: 0,
      height: panelHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
              border: Border(top: BorderSide(color: theme.colorScheme.tertiary.withOpacity(0.5))),
            ),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 16.w, left: 16.w, right: 16.w),
                  child: Text(
                    localizations.selectYourInterests,
                    style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.tertiary),
                  ),
                ),
                // DEĞİŞİKLİK: Seçim sayacı eklendi
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  child: Text(
                    '${_selectedTopics.length} ${"Selected"}', // Lokalizasyona ekleyin: "selected": "Seçili"
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 14.sp),
                  ),
                ),
                Expanded(
                  child: _allTopics.isEmpty
                      ? Center(child: Text("No Data Available", style: TextStyle(color: Colors.grey.shade400)))
                      : GridView.builder(
                          padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 20.h),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 2.5 / 1),
                          itemCount: _allTopics.length,
                          itemBuilder: (context, index) {
                            final apiKey = _allTopics.keys.elementAt(index);
                            final displayName = _allTopics.values.elementAt(index);
                            final isSelected = _selectedTopics.contains(apiKey);
                            return InkWell(
                              onTap: () => setState(() => isSelected ? _selectedTopics.remove(apiKey) : _selectedTopics.add(apiKey)),
                              borderRadius: BorderRadius.circular(12.r),
                              child: Card(
                                color: isSelected ? theme.colorScheme.primary.withOpacity(0.3) : theme.cardTheme.color,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r), side: BorderSide(color: isSelected ? theme.colorScheme.primary : Colors.transparent, width: 2)),
                                child: Center(child: Text(displayName, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp, color: isSelected ? theme.colorScheme.primary : Colors.white))),
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 24.h),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      // DEĞİŞİKLİK: Butonun aktif olma koşulu güncellendi
                      onPressed: isSaveButtonEnabled ? _saveTopics : null,
                      icon: _isSaving
                          ? SizedBox(width: 20.w, height: 20.h, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onPrimary))
                          : Icon(Icons.save_rounded, color: theme.colorScheme.onPrimary),
                      label: Text(_isSaving ? localizations.saving : localizations.save),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        // DEĞİŞİKLİK: Buton pasifken daha soluk görünmesini sağlar
                        disabledBackgroundColor: theme.colorScheme.primary.withOpacity(0.4),
                        padding: EdgeInsets.symmetric(vertical: 16.h)
                      ),
                    ),
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