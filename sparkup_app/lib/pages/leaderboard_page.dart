import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../services/api_service.dart'; 
import '../l10n/app_localizations.dart';

class LeaderboardPage extends StatefulWidget {
  final String idToken;
  const LeaderboardPage({super.key, required this.idToken});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  final ApiService _apiService = ApiService();
  
  Map<String, String> _allTopics = {};
  Set<String> _selectedTopics = {};
  Future<void>? _loadingFuture;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadingFuture = _loadTopics();
  }

  Future<void> _loadTopics() async {
    try {
      final results = await Future.wait([_apiService.getTopics(), _apiService.getUserTopics(widget.idToken)]);
      if (mounted) {
        setState(() {
          _allTopics = results[0] as Map<String, String>;
          _selectedTopics = (results[1] as List<String>).toSet();
        });
      }
    } catch(e) {
      print("Error loading topics: $e");
    }
  }

  Future<void> _saveTopics() async {
    setState(() => _isSaving = true);
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    try {
      await _apiService.setUserTopics(widget.idToken, _selectedTopics.toList());
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.preferencesSaved), backgroundColor: theme.colorScheme.secondary),
        );
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${localizations.error}: ${localizations.preferencesCouldNotBeSaved}"), backgroundColor: theme.colorScheme.error),
        );
      }
    } finally {
      if(mounted) setState(() => _isSaving = false);
    }
  }

  // Örnek olarak, öne çıkarmak istediğimiz konuların bir listesini state'e ekleyelim.
  // Bu veri normalde API'den veya başka bir kaynaktan gelir.
  final Set<String> _highlightedTopics = {'science', 'technology'};


  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      body: FutureBuilder<void>(
        future: _loadingFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: theme.colorScheme.primary));
          if (snapshot.hasError) return Center(child: Text("${localizations.error}: ${snapshot.error}", style: TextStyle(color: theme.colorScheme.error)));

          return Column(
            children: [
              Padding(
                padding: EdgeInsets.all(16.w),
                child: Text(
                  localizations.selectYourInterests,
                  style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.bold)
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 80.h),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16.w,
                    mainAxisSpacing: 16.h,
                    childAspectRatio: 2.5 / 1,
                  ),
                  itemCount: _allTopics.length,
                  itemBuilder: (context, index) {
                    final apiKey = _allTopics.keys.elementAt(index);
                    final displayName = _allTopics.values.elementAt(index);
                    
                    // DEĞİŞİKLİK: 3 farklı durumu kontrol ediyoruz
                    final isSelected = _selectedTopics.contains(apiKey);
                    final isHighlighted = _highlightedTopics.contains(apiKey);

                    Color cardColor;
                    Color borderColor;
                    Color textColor;

                    if (isSelected) {
                      cardColor = theme.colorScheme.primary.withOpacity(0.3);
                      borderColor = theme.colorScheme.primary;
                      textColor = theme.colorScheme.primary;
                    } else if (isHighlighted) {
                      // Öne çıkarılan ama seçilmemiş konular için TERTİARY rengini kullan
                      cardColor = theme.colorScheme.tertiary.withOpacity(0.3);
                      borderColor = theme.colorScheme.tertiary;
                      textColor = theme.colorScheme.tertiary;
                    } else {
                      cardColor = theme.cardTheme.color!;
                      borderColor = Colors.transparent;
                      textColor = Colors.white;
                    }

                    return InkWell(
                      onTap: () => setState(() => isSelected ? _selectedTopics.remove(apiKey) : _selectedTopics.add(apiKey)),
                      borderRadius: BorderRadius.circular(12.r),
                      child: Card(
                        color: cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          side: BorderSide(color: borderColor, width: 2),
                        ),
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.w),
                            child: Text(
                              displayName,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16.sp,
                                color: textColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      // Bu senaryoda Kaydet butonunu primary'de bırakmak daha iyi olabilir.
      // Veya 1. önerideki gibi tertiary'e de çekebilirsiniz.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _saveTopics,
        backgroundColor: theme.colorScheme.primary, // veya tertiary
        icon: _isSaving
            ? SizedBox(width: 20.w, height: 20.h, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onPrimary))
            : Icon(Icons.save, color: theme.colorScheme.onPrimary),
        label: Text(_isSaving ? localizations.saving : localizations.save, style: TextStyle(color: theme.colorScheme.onPrimary)),
      ),
    );
  }
}