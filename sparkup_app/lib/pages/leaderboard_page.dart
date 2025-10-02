// pages/leaderboard_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../services/api_service.dart'; // ApiService'in bir klasör yukarıda olduğunu varsayıyoruz
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
      // ⚠️ idToken'ı getUserTopics'e iletiyoruz
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
    try {
      // ⚠️ idToken'ı setUserTopics'e iletiyoruz
      await _apiService.setUserTopics(widget.idToken, _selectedTopics.toList());
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.preferencesSaved), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${localizations.error}: ${localizations.preferencesCouldNotBeSaved}"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if(mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<void>(
        future: _loadingFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.amber));
          if (snapshot.hasError) return Center(child: Text("${localizations.error}: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
          
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
                    childAspectRatio: 2.5 / 1
                  ),
                  itemCount: _allTopics.length,
                  itemBuilder: (context, index) {
                    final apiKey = _allTopics.keys.elementAt(index);
                    final displayName = _allTopics.values.elementAt(index);
                    final isSelected = _selectedTopics.contains(apiKey);
                    
                    return InkWell(
                      onTap: () => setState(() => isSelected ? _selectedTopics.remove(apiKey) : _selectedTopics.add(apiKey)),
                      borderRadius: BorderRadius.circular(12.r),
                      child: Card(
                        color: isSelected ? Colors.amber.withOpacity(0.3) : Colors.grey.shade900,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r), 
                          side: BorderSide(color: isSelected ? Colors.amber : Colors.transparent, width: 2)
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
                                color: isSelected ? Colors.amber : Colors.white
                              )
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _saveTopics,
        backgroundColor: Colors.amber,
        icon: _isSaving ? SizedBox(width: 20.w, height: 20.h, child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Icon(Icons.save, color: Colors.black),
        label: Text(_isSaving ? localizations.saving : localizations.save, style: const TextStyle(color: Colors.black)),
      ),
    );
  }
}