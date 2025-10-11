import 'package:flutter/material.dart';
import '../models/user_models.dart';
import '../services/api_service.dart';

class UserProvider extends ChangeNotifier {
  UserProfile? _profile;
  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;

  // Profil verilerini yükler ve state'i günceller
  Future<void> loadProfile(String? idToken) async {
    if (idToken == null || idToken.isEmpty) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      final json = await _apiService.getUserProfile(idToken);
      _profile = UserProfile.fromJson(json);
    } catch (e) {
      debugPrint("Kullanıcı profili yüklenirken hata oluştu: $e");
      _profile = null; // Hata durumunda profili temizle
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Quiz/Streak/Puan güncellemelerinden sonra puanı elle günceller
  void updateScoreAndStreak(int newScore, int newStreak, String newRankName) {
    if (_profile != null) {
      _profile = UserProfile(
        firebaseUid: _profile!.firebaseUid,
        email: _profile!.email,
        score: newScore,
        rankName: newRankName,
        currentStreak: newStreak,
        subscriptionLevel: _profile!.subscriptionLevel,
        subscriptionExpires: _profile!.subscriptionExpires,
        topicPreferences: _profile!.topicPreferences,
        languageCode: _profile!.languageCode,
        notificationsEnabled: _profile!.notificationsEnabled,
      );
      notifyListeners();
    }
  }

  // Abonelik seviyesini sadece lokal olarak günceller
  void updateSubscriptionLevel(String level, String? expiresAt) {
    if (_profile != null) {
      _profile = UserProfile(
        firebaseUid: _profile!.firebaseUid,
        email: _profile!.email,
        score: _profile!.score,
        rankName: _profile!.rankName,
        currentStreak: _profile!.currentStreak,
        subscriptionLevel: level,
        subscriptionExpires: expiresAt,
        topicPreferences: _profile!.topicPreferences,
        languageCode: _profile!.languageCode,
        notificationsEnabled: _profile!.notificationsEnabled,
      );
      notifyListeners();
    }
  }
}