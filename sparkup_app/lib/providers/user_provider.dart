// lib/providers/user_provider.dart

import 'package:flutter/material.dart';
import '../services/api_service.dart';

class UserProvider extends ChangeNotifier {
  UserProfile? profile;
  bool _isLoading = false;
  final ApiService _api_service = ApiService();

  bool get isLoading => _isLoading;

  Future<void> loadProfile(String? idToken) async {
    if (idToken == null || idToken.isEmpty) return;
    _isLoading = true;
    notifyListeners();
    try {
      final json = await _api_service.getUserProfile(idToken);
      profile = UserProfile.fromJson(json);
    } catch (e) {
      debugPrint("Kullanıcı profili yüklenirken hata oluştu: $e");
      // keep previous profile if available
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateScore(int newScore) {
    if (profile == null) {
      profile = UserProfile(username: null, score: newScore, currentStreak: 0, subscriptionLevel: 'free', dailyQuizLimit: null, dailyQuizUsed: 0, remainingQuizzes: null, dailyPoints: 0);
      notifyListeners();
      return;
    }
    if (profile!.score != newScore) {
      profile = profile!.copyWith(score: newScore);
      notifyListeners();
    }
  }

  void setProfile(UserProfile p) { profile = p; notifyListeners(); }
  void clearProfile() { profile = null; notifyListeners(); }
}

class UserProfile {
  final String? username;
  final int score;
  final int currentStreak;
  final String subscriptionLevel;
  final int? dailyQuizLimit;
  final int? dailyQuizUsed;
  final int? remainingQuizzes;
  final int dailyPoints;

  UserProfile({
    this.username,
    required this.score,
    required this.currentStreak,
    this.subscriptionLevel = 'free',
    this.dailyQuizLimit,
    this.dailyQuizUsed,
    this.remainingQuizzes,
    this.dailyPoints = 0,
  });

  UserProfile copyWith({String? username, int? score, int? currentStreak, String? subscriptionLevel, int? dailyQuizLimit, int? dailyQuizUsed, int? remainingQuizzes, int? dailyPoints}) {
    return UserProfile(
      username: username ?? this.username,
      score: score ?? this.score,
      currentStreak: currentStreak ?? this.currentStreak,
      subscriptionLevel: subscriptionLevel ?? this.subscriptionLevel,
      dailyQuizLimit: dailyQuizLimit ?? this.dailyQuizLimit,
      dailyQuizUsed: dailyQuizUsed ?? this.dailyQuizUsed,
      remainingQuizzes: remainingQuizzes ?? this.remainingQuizzes,
      dailyPoints: dailyPoints ?? this.dailyPoints,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      // do not fall back to email — keep username null if backend didn't provide it
      username: json['username'] as String?,
      score: (json['score'] as num?)?.toInt() ?? 0,
      currentStreak: (json['current_streak'] as num?)?.toInt() ?? 0,
      subscriptionLevel: (json['subscription_level'] as String?) ?? 'free',
      dailyQuizLimit: json['daily_quiz_limit'] != null ? (json['daily_quiz_limit'] as num).toInt() : null,
      dailyQuizUsed: json['daily_quiz_used'] != null ? (json['daily_quiz_used'] as num).toInt() : 0,
      remainingQuizzes: json['remaining_quizzes'] != null ? (json['remaining_quizzes'] as num).toInt() : null,
      dailyPoints: (json['daily_points'] as num?)?.toInt() ?? 0,
    );
  }
}