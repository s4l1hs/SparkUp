// lib/providers/user_provider.dart

import 'package:flutter/material.dart';
import '../models/user_models.dart';
import '../services/api_service.dart';

class UserProvider extends ChangeNotifier {
  UserProfile? profile;
  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  bool get isLoading => _isLoading;

  Future<void> loadProfile(String? idToken) async {
    if (idToken == null || idToken.isEmpty) return;
    _isLoading = true;
    notifyListeners();
    try {
      final json = await _apiService.getUserProfile(idToken);
      profile = UserProfile.fromJson(json);
    } catch (e) {
      debugPrint("Kullanıcı profili yüklenirken hata oluştu: $e");
      profile = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // ensure score updates notify listeners
  void updateScore(int newScore) {
    if (profile == null) return;
    if (profile!.score != newScore) {
      profile = profile!.copyWith(score: newScore);
      notifyListeners();
    }
  }

  // optionally helper to replace whole profile
  void setProfile(UserProfile p) {
    profile = p;
    notifyListeners();
  }

  void clearProfile() {
    profile = null;
    notifyListeners();
  }
}