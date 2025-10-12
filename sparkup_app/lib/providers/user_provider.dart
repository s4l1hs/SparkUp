// lib/providers/user_provider.dart

import 'package:flutter/material.dart';
import '../models/user_models.dart';
import '../services/api_service.dart';

class UserProvider extends ChangeNotifier {
  UserProfile? _profile;
  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;

  Future<void> loadProfile(String? idToken) async {
    if (idToken == null || idToken.isEmpty) return;
    _isLoading = true;
    notifyListeners();
    try {
      final json = await _apiService.getUserProfile(idToken);
      _profile = UserProfile.fromJson(json);
    } catch (e) {
      debugPrint("Kullanıcı profili yüklenirken hata oluştu: $e");
      _profile = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  void updateScore(int newScore) {
    if (_profile != null) {
      _profile = _profile!.copyWith(score: newScore);
      notifyListeners();
    }
  }

  void clearProfile() {
    _profile = null;
    notifyListeners();
  }
}