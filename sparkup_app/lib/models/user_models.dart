class UserProfile {
  final String firebaseUid;
  final String? email;
  final int score;
  final String rankName; // Backend'den gelen rütbe adı (Demir, Altın vb.)
  final int currentStreak;
  final String subscriptionLevel; // free, pro, ultra
  final String? subscriptionExpires; // ISO 8601 string veya null
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

  // Backend JSON'dan UserProfile objesi oluşturur
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      firebaseUid: json['firebase_uid'] as String,
      email: json['email'] as String?,
      score: json['score'] as int,
      rankName: json['rank_name'] as String,
      currentStreak: json['current_streak'] as int,
      subscriptionLevel: json['subscription_level'] as String,
      subscriptionExpires: json['subscription_expires'] as String?,
      topicPreferences: List<String>.from(json['topic_preferences'] as List),
      languageCode: json['language_code'] as String,
      notificationsEnabled: json['notifications_enabled'] as bool,
    );
  }
}

// Backend'e abonelik bilgisini göndermek için kullanılan model
class SubscriptionUpdate {
  final String level;
  final int durationDays;

  SubscriptionUpdate({
    required this.level,
    required this.durationDays,
  });

  Map<String, dynamic> toJson() {
    return {
      'level': level,
      'duration_days': durationDays,
    };
  }
}