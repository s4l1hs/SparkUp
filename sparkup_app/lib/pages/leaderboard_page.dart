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

class _LeaderboardPageState extends State<LeaderboardPage> with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();

  // --- STATE'LER ---
  List<LeaderboardEntry> _leaderboardData = [];
  bool _isLoading = true;
  bool _isTopicPanelOpen = false;
  Map<String, String> _allTopics = {};
  Set<String> _selectedTopics = {};
  bool _isSaving = false;

  // --- ANİMASYON CONTROLLER'LARI ---
  late final AnimationController _listAnimationController;
  late final AnimationController _backgroundController;
  late final Animation<Alignment> _backgroundAnimation1;
  late final Animation<Alignment> _backgroundAnimation2;

  @override
  void initState() {
    super.initState();
    _listAnimationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _backgroundController = AnimationController(vsync: this, duration: const Duration(seconds: 30))..repeat(reverse: true);

    _backgroundAnimation1 = TweenSequence<Alignment>([
      TweenSequenceItem(tween: AlignmentTween(begin: Alignment.topLeft, end: Alignment.bottomRight), weight: 1),
      TweenSequenceItem(tween: AlignmentTween(begin: Alignment.bottomRight, end: Alignment.topLeft), weight: 1),
    ]).animate(_backgroundController);

    _backgroundAnimation2 = TweenSequence<Alignment>([
      TweenSequenceItem(tween: AlignmentTween(begin: Alignment.bottomLeft, end: Alignment.topRight), weight: 1),
      TweenSequenceItem(tween: AlignmentTween(begin: Alignment.topRight, end: Alignment.bottomLeft), weight: 1),
    ]).animate(_backgroundController);

    _loadPageData();
  }
  
  @override
  void dispose() {
    _listAnimationController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  // --- API FONKSİYONLARI ---
  Future<void> _loadPageData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    _listAnimationController.reset();
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
        _listAnimationController.forward();
      }
    } catch (e) {
      print("Sayfa verileri yüklenirken hata oluştu: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("AppLocalizations.of(context)!.errorCouldNotLoadData"), backgroundColor: Colors.red),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("localizations.errorCouldNotSaveChanges"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
  
  // --- YARDIMCI FONKSİYONLAR ---
  String _maskEmail(String? email) {
    if (email == null || !email.contains('@')) return 'Anonymous';
    final parts = email.split('@');
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) return '${name[0]}***@${domain.substring(0,1)}...';
    return '${name.substring(0, 2)}***@${domain.substring(0,1)}...';
  }

  // --- ANA BUILD METODU ---
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // CANLI ARKA PLAN
          AnimatedBuilder(
            animation: _backgroundController,
            builder: (context, child) {
              return Stack(
                children: [
                  Positioned.fill(child: Align(alignment: _backgroundAnimation1.value, child: Container(width: 400.w, height: 400.h, decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.primary.withOpacity(0.15), boxShadow: [BoxShadow(color: theme.colorScheme.primary.withOpacity(0.1), blurRadius: 100.r, spreadRadius: 80.r)])))),
                  Positioned.fill(child: Align(alignment: _backgroundAnimation2.value, child: Container(width: 300.w, height: 300.h, decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.tertiary.withOpacity(0.15), boxShadow: [BoxShadow(color: theme.colorScheme.tertiary.withOpacity(0.1), blurRadius: 100.r, spreadRadius: 60.r)])))),
                ],
              );
            },
          ),
          SafeArea(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
                : Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 16.w),
                        child: Text(localizations.navLeaderboard, style: theme.textTheme.titleLarge?.copyWith(fontSize: 24.sp)),
                      ),
                      if (_leaderboardData.length >= 3)
                        _AnimatedListItem(index: 0, controller: _listAnimationController, child: _buildPodium(context, _leaderboardData.sublist(0, 3))),
                      Expanded(
                        child: _leaderboardData.length < 4
                            ? (_leaderboardData.isEmpty ? Center(child: Text("localizations.noDataAvailable", style: TextStyle(color: Colors.grey.shade400))) : const SizedBox.shrink())
                            : ListView.builder(
                                padding: EdgeInsets.symmetric(horizontal: 16.w),
                                itemCount: _leaderboardData.length - 3,
                                itemBuilder: (context, index) {
                                  final entry = _leaderboardData[index + 3];
                                  return _AnimatedListItem(
                                    index: index + 1,
                                    controller: _listAnimationController,
                                    child: Card(
                                      color: theme.cardTheme.color,
                                      margin: EdgeInsets.only(bottom: 12.h),
                                      child: ListTile(
                                        leading: Text("#${entry.rank}", style: TextStyle(fontSize: 16.sp, color: Colors.grey.shade400, fontWeight: FontWeight.bold)),
                                        title: Text(_maskEmail(entry.email), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                        trailing: Row( mainAxisSize: MainAxisSize.min, children: [ Text(entry.score.toString(), style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)), SizedBox(width: 4.w), Icon(Icons.star_rounded, color: theme.colorScheme.secondary, size: 18.sp)])
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
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
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: RotationTransition(turns: animation, child: child)),
                  child: Icon(_isTopicPanelOpen ? Icons.close_rounded : Icons.category_rounded, key: ValueKey<bool>(_isTopicPanelOpen), color: theme.colorScheme.onTertiary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- YARDIMCI BUILD METOTLARI ---
  Widget _buildPodium(BuildContext context, List<LeaderboardEntry> topThree) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 24.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildPodiumPlace(context, topThree[1], theme, height: 120.h),
          _buildPodiumPlace(context, topThree[0], theme, height: 150.h, isFirst: true),
          _buildPodiumPlace(context, topThree[2], theme, height: 100.h),
        ],
      ),
    );
  }

  Widget _buildPodiumPlace(BuildContext context, LeaderboardEntry entry, ThemeData theme, {required double height, bool isFirst = false}) {
    return Expanded(
      child: Column(
        children: [
          if (isFirst) Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 32.sp),
          SizedBox(height: isFirst ? 8.h : 12.h),
          Text("#${entry.rank}", style: TextStyle(fontSize: 18.sp, color: isFirst ? Colors.amber : Colors.white, fontWeight: FontWeight.bold)),
          SizedBox(height: 4.h),
          Text(_maskEmail(entry.email), style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade300), overflow: TextOverflow.ellipsis),
          SizedBox(height: 8.h),
          Container(
            height: height,
            margin: EdgeInsets.symmetric(horizontal: 4.w),
            decoration: BoxDecoration(
              color: isFirst ? theme.colorScheme.primary.withOpacity(0.3) : theme.colorScheme.surface.withOpacity(0.5),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12.r)),
              border: Border.all(color: isFirst ? theme.colorScheme.primary : theme.colorScheme.tertiary.withOpacity(0.5)),
            ),
            child: Center(child: Text(entry.score.toString(), style: TextStyle(fontSize: 22.sp, color: Colors.white, fontWeight: FontWeight.bold))),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicSelectionPanel(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final panelHeight = MediaQuery.of(context).size.height * 0.75;
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
              color: Colors.black.withOpacity(0.85),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
              border: Border(top: BorderSide(color: theme.colorScheme.tertiary.withOpacity(0.5))),
            ),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 16.w, 16.w, 8.w),
                  child: Text(localizations.selectYourInterests, style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.tertiary)),
                ),
                Padding(
                  padding: EdgeInsets.only(bottom: 8.h),
                  child: Text('${_selectedTopics.length} ${"localizations.selected"}', style: TextStyle(color: Colors.grey.shade400, fontSize: 14.sp)),
                ),
                Expanded(
                  child: _allTopics.isEmpty
                      ? Center(child: Text("localizations.noDataAvailable", style: TextStyle(color: Colors.grey.shade400)))
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
                      onPressed: isSaveButtonEnabled ? _saveTopics : null,
                      icon: _isSaving
                          ? SizedBox(width: 20.w, height: 20.h, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onPrimary))
                          : Icon(Icons.save_rounded, color: theme.colorScheme.onPrimary),
                      label: Text(_isSaving ? localizations.saving : localizations.save),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
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

// Kademeli liste animasyonu için yardımcı widget
class _AnimatedListItem extends StatelessWidget {
  final int index;
  final AnimationController controller;
  final Widget child;

  const _AnimatedListItem({required this.index, required this.controller, required this.child});

  @override
  Widget build(BuildContext context) {
    final intervalStart = (index * 0.1).clamp(0.0, 1.0);
    final intervalEnd = (intervalStart + 0.5).clamp(0.0, 1.0);
    
    final animation = CurvedAnimation(parent: controller, curve: Interval(intervalStart, intervalEnd, curve: Curves.easeOut));
    
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(animation),
        child: child,
      ),
    );
  }
}