import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../services/api_service.dart';
import 'package:sparkup_app/utils/color_utils.dart';

class AnalysisPage extends StatefulWidget {
  final String idToken;
  const AnalysisPage({super.key, required this.idToken});

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _api.getUserAnalysis(widget.idToken);
      final rawList = (data['analysis'] as List<dynamic>?) ?? <dynamic>[];
      setState(() {
        _items = rawList.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map<String, dynamic>)).toList();
      });
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Performance Analysis', style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
            SizedBox(height: 12.h),
            if (_isLoading) Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
            if (_error != null) Center(child: Text(_error!)),
            if (!_isLoading && _error == null)
              Expanded(
                child: _items.isEmpty
                    ? Center(child: Text('No analysis data yet'))
                    : ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (c, i) => SizedBox(height: 12.h),
                        itemBuilder: (c, i) {
                          final it = _items[i];
                          final category = it['category'] ?? 'unknown';
                          final percent = (it['percent'] ?? 0) as int;
                          final correct = it['correct'] ?? 0;
                          final total = it['total'] ?? 0;

                          return Container(
                            padding: EdgeInsets.all(12.w),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(12.r),
                              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8.r, offset: Offset(0,2))],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 84.w,
                                  height: 84.w,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.secondary]),
                                  ),
                                  child: Center(
                                    child: Text('$percent%', style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(category, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600)),
                                      SizedBox(height: 6.h),
                                      Text('Correctness: $correct/$total', style: TextStyle(color: colorWithOpacity(theme.colorScheme.onSurface, 0.7))),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right, color: colorWithOpacity(theme.colorScheme.onSurface, 0.4)),
                              ],
                            ),
                          );
                        },
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
