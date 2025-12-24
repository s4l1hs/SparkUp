import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AnalysisProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  bool isLoading = false;
  String? error;
  List<Map<String, dynamic>> items = [];

  Future<void> refresh(String idToken) async {
    if (idToken.isEmpty) return;
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final data = await _api.getUserAnalysis(idToken);
      final raw = (data['analysis'] as List<dynamic>?) ?? <dynamic>[];
      items = raw
          .map<Map<String, dynamic>>(
              (e) => Map<String, dynamic>.from(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
