import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import '../models/leaderboard_entry.dart';
import '../main.dart';

// --- YENİ HATA SINIFLARI ---
class QuizLimitException implements Exception {
  final String message;
  QuizLimitException(this.message);
  @override
  String toString() => 'QuizLimitException: $message';
}

class ChallengeLimitException implements Exception {
  final String message;
  ChallengeLimitException(this.message);
  @override
  String toString() => 'ChallengeLimitException: $message';
}


class ApiService {

  // --- Helper Fonksiyonu: Yetkilendirilmiş Başlık (Headers) Oluşturma ---
  Map<String, String> _getAuthHeaders(String idToken) {
    return {
      'Content-Type': 'application/json',
      // Backend'in beklediği format: HTTP Bearer şeması
      'Authorization': 'Bearer $idToken', 
    };
  }
  
  // JSON decoding sırasında UTF8 hatalarını gidermek için kullanılan bir yardımcı fonksiyon
  dynamic _decodeResponseBody(Uint8List bodyBytes) {
      return jsonDecode(utf8.decode(bodyBytes));
  }


  Future<Map<String, dynamic>> getUserProfile(String idToken) async {
    final uri = Uri.parse("$backendBaseUrl/user/profile/");
    final response = await http.get(uri, headers: _getAuthHeaders(idToken));

    if (response.statusCode == 200) {
      return _decodeResponseBody(response.bodyBytes);
    } else {
      throw Exception('Failed to load user profile: ${response.statusCode}');
    }
  }

  // Konu başlıklarını getirir (auth gerektirmez)
  Future<Map<String, String>> getTopics() async {
    final uri = Uri.parse("$backendBaseUrl/topics/");
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = Map<String, dynamic>.from(_decodeResponseBody(response.bodyBytes));
      return data.map((key, value) => MapEntry(key, value.toString()));
    } else {
      throw Exception("Failed to load topics. Status: ${response.statusCode}");
    }
  }


  // Kullanıcının kayıtlı konularını getirir
  Future<List<String>> getUserTopics(String idToken) async {
     final uri = Uri.parse("$backendBaseUrl/user/topics/");
     final response = await http.get(
       uri, 
       headers: _getAuthHeaders(idToken)
     );
     if (response.statusCode == 200) {
       return List<String>.from(_decodeResponseBody(response.bodyBytes));
     } else {
       throw Exception("Failed to load user topics. Status: ${response.statusCode}, Body: ${response.body}");
     }
  }

  // Kullanıcının konu tercihlerini kaydeder
  Future<void> setUserTopics(String idToken, List<String> topics) async {
     final uri = Uri.parse("$backendBaseUrl/user/topics/");
     final response = await http.put(
       uri, 
       headers: _getAuthHeaders(idToken),
       body: jsonEncode(topics),
     );
     if (response.statusCode != 200) {
       throw Exception("Failed to set user topics. Status: ${response.statusCode}, Body: ${response.body}");
     }
  }


  // Rastgele bilgi kartı getirir
  Future<Map<String, dynamic>> getRandomInfo(String idToken, {String? category}) async {
    final uri = Uri.parse("$backendBaseUrl/info/random/${category != null ? '?category=$category' : ''}");
    final response = await http.get(
      uri, 
      headers: _getAuthHeaders(idToken)
    ); 
    if (response.statusCode == 200) {
      return _decodeResponseBody(response.bodyBytes);
    } else {
      throw Exception("Failed to load info. Status: ${response.statusCode}, Body: ${response.body}");
    }
  }

  // Quiz soruları getirir (429 Hata Kontrolü Eklendi)
  Future<List<Map<String, dynamic>>> getQuizQuestions(String idToken, {int limit = 3, String? category}) async {
    final uri = Uri.parse("$backendBaseUrl/quiz/?limit=$limit${category != null ? '&category=$category' : ''}");
    final response = await http.get(
      uri, 
      headers: _getAuthHeaders(idToken)
    ); 
    
    if (response.statusCode == 429) {
      final data = jsonDecode(response.body);
      throw QuizLimitException(data['detail'] ?? "Daily quiz limit reached.");
    }
    
    if (response.statusCode == 200) {
      final List<dynamic> data = _decodeResponseBody(response.bodyBytes);
      return List<Map<String, dynamic>>.from(data);
    } else {
      throw Exception("Failed to load quiz questions. Status: ${response.statusCode}, Body: ${response.body}");
    }
  }

  // Rastgele meydan okuma (challenge) getirir (429 Hata Kontrolü Eklendi)
  Future<Map<String, dynamic>> getRandomChallenge(String idToken) async {
    final uri = Uri.parse("$backendBaseUrl/challenges/random/");
    final response = await http.get(
      uri, 
      headers: _getAuthHeaders(idToken)
    );
    
    if (response.statusCode == 429) {
      final data = jsonDecode(response.body);
      throw ChallengeLimitException(data['detail'] ?? "Daily challenge limit reached.");
    }

    if (response.statusCode == 200) {
      return _decodeResponseBody(response.bodyBytes);
    } else {
      throw Exception("Failed to load challenge. Status: ${response.statusCode}, Body: ${response.body}");
    }
  }
  
  // Quiz Cevabı Gönderme (submitQuizAnswer)
  Future<Map<String, dynamic>> submitQuizAnswer(String idToken, int questionId, int answerIndex) async {
    final uri = Uri.parse("$backendBaseUrl/quiz/answer/");
    final response = await http.post(
      uri, 
      headers: _getAuthHeaders(idToken),
      body: jsonEncode({
        'question_id': questionId,
        'answer_index': answerIndex,
      }),
    );
    
    // 429 HATA KONTROLÜ (Limit tam cevap gönderilirken dolmuşsa)
    if (response.statusCode == 429) {
      final data = jsonDecode(response.body);
      throw QuizLimitException(data['detail'] ?? "Daily quiz question limit reached.");
    }

    if (response.statusCode == 200) {
      return _decodeResponseBody(response.bodyBytes);
    } else {
      throw Exception("Failed to submit answer. Status: ${response.statusCode}, Body: ${response.body}");
    }
  }


  // Tüm lider tablosu verilerini getirir
  Future<List<LeaderboardEntry>> getLeaderboard(String idToken) async {
    final uri = Uri.parse('$backendBaseUrl/leaderboard/');
    final response = await http.get(uri, headers: _getAuthHeaders(idToken));

    if (response.statusCode == 200) {
      final List<dynamic> data = _decodeResponseBody(response.bodyBytes);
      return data.map((json) => LeaderboardEntry.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load leaderboard. Status: ${response.statusCode}, Body: ${response.body}');
    }
  }
  
  // Kullanıcının kendi sıralama ve puan bilgisini getirir
  Future<LeaderboardEntry?> getUserRank(String idToken) async {
    final uri = Uri.parse('$backendBaseUrl/leaderboard/me/');
    final response = await http.get(uri, headers: _getAuthHeaders(idToken));

    if (response.statusCode == 200) {
      final data = _decodeResponseBody(response.bodyBytes);
      return LeaderboardEntry.fromJson(data);
    } 
    else if (response.statusCode == 404) {
      return null;
    }
    else {
      throw Exception('Failed to load user rank. Status: ${response.statusCode}, Body: ${response.body}');
    }
  }
  
  // YENİ EKLENEN FONKSİYON: Abonelik Güncelleme
  Future<void> updateSubscription(String idToken, String level, int durationDays) async {
    final uri = Uri.parse("$backendBaseUrl/subscription/update/");
    final response = await http.post(
      uri,
      headers: _getAuthHeaders(idToken),
      body: jsonEncode({
        'level': level,
        'duration_days': durationDays,
      }),
    );
    
    if (response.statusCode != 200) {
      throw Exception("Failed to update subscription. Status: ${response.statusCode}, Body: ${response.body}");
    }
  }
}