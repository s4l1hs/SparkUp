// lib/models/user_models.dart

class UserProfile {
  final String firebaseUid;
  final String? email;
  final int score;
  final String rankName;
  final int currentStreak;
  final String subscriptionLevel;
  final String? subscriptionExpires;
  final List<String> topicPreferences;
  final String languageCode;
  final bool notificationsEnabled;

  UserProfile({
    required this.firebaseUid,
    this.email,
    required this.score,
    required this.rankName,
    required this.currentStreak,
    required this.subscriptionLevel,
    this.subscriptionExpires,
    required this.topicPreferences,
    required this.languageCode,
    required this.notificationsEnabled,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      firebaseUid: json['firebase_uid'] as String? ?? '',
      email: json['email'] as String?,
      score: json['score'] as int? ?? 0,
      rankName: json['rank_name'] as String? ?? 'Demir',
      currentStreak: json['current_streak'] as int? ?? 0,
      subscriptionLevel: json['subscription_level'] as String? ?? 'free',
      subscriptionExpires: json['subscription_expires'] as String?,
      topicPreferences: List<String>.from(json['topic_preferences'] as List? ?? []),
      languageCode: json['language_code'] as String? ?? 'en',
      notificationsEnabled: json['notifications_enabled'] as bool? ?? false,
    );
  }

  UserProfile copyWith({
    int? score, String? rankName, int? currentStreak,
    String? subscriptionLevel, String? subscriptionExpires,
  }) {
    return UserProfile(
      firebaseUid: this.firebaseUid, email: this.email,
      score: score ?? this.score, rankName: rankName ?? this.rankName,
      currentStreak: currentStreak ?? this.currentStreak,
      subscriptionLevel: subscriptionLevel ?? this.subscriptionLevel,
      subscriptionExpires: subscriptionExpires ?? this.subscriptionExpires,
      topicPreferences: this.topicPreferences, languageCode: this.languageCode,
      notificationsEnabled: this.notificationsEnabled,
    );
  }
}