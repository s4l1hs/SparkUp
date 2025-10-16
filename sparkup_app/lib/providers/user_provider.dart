// lib/providers/user_provider.dart

import 'package:flutter/material.dart';
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
    if (profile == null) {
      // create lightweight profile if needed
      profile = UserProfile(username: null, score: newScore, currentStreak: 0, subscriptionLevel: 'free');
      notifyListeners();
      return;
    }
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

class UserProfile {
  final String? username;
  final int score;
  final int currentStreak;
  final String subscriptionLevel; // added

  UserProfile({this.username, required this.score, required this.currentStreak, this.subscriptionLevel = 'free'});

  UserProfile copyWith({String? username, int? score, int? currentStreak, String? subscriptionLevel}) {
    return UserProfile(
      username: username ?? this.username,
      score: score ?? this.score,
      currentStreak: currentStreak ?? this.currentStreak,
      subscriptionLevel: subscriptionLevel ?? this.subscriptionLevel,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      username: json['username'] as String?,
      score: (json['score'] as num?)?.toInt() ?? 0,
      currentStreak: (json['current_streak'] as num?)?.toInt() ?? 0,
      subscriptionLevel: (json['subscription_level'] as String?) ?? (json['subscriptionLevel'] as String?) ?? 'free',
    );
  }
}