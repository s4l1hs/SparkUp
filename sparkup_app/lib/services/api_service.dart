import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
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
  Future<List<Map<String, dynamic>>> getQuizQuestions(String idToken, {int limit = 3, String? lang, bool preview = false}) async {
    final uri = Uri.parse("$backendBaseUrl/quiz/?limit=$limit${lang != null ? '&lang=$lang' : ''}${preview ? '&preview=true' : ''}");
    final resp = await http.get(uri, headers: {'Authorization': 'Bearer $idToken'});
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as List<dynamic>;
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } else if (resp.statusCode == 429) {
      final detail = resp.body;
      throw QuizLimitException(detail);
    } else {
      throw Exception('Failed to load quiz questions (${resp.statusCode})');
    }
  }

  // Rastgele meydan okuma (challenge) getirir (429 Hata Kontrolü Eklendi)
  Future<Map<String, dynamic>> getRandomChallenge(String idToken, {String? lang, bool preview = false}) async {
    final uri = Uri.parse("$backendBaseUrl/challenges/random/${lang != null ? '?lang=$lang' : ''}${preview ? (lang != null ? '&preview=true' : '?preview=true') : ''}");
    final resp = await http.get(uri, headers: {'Authorization': 'Bearer $idToken'});
    if (resp.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(resp.body) as Map);
    } else if (resp.statusCode == 429) {
      final detail = resp.body;
      throw ChallengeLimitException(detail);
    } else {
      throw Exception('Failed to load challenge (${resp.statusCode})');
    }
  }
  
  // Quiz Cevabı Gönderme (submitQuizAnswer)
  Future<Map<String, dynamic>> submitQuizAnswer(String idToken, int questionId, int answerIndex) async {
    final uri = Uri.parse("$backendBaseUrl/quiz/answer/");
    final resp = await http.post(uri,
      headers: {'Authorization': 'Bearer $idToken', 'Content-Type': 'application/json'},
      body: jsonEncode({'question_id': questionId, 'answer_index': answerIndex}),
    );
    if (resp.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(resp.body) as Map);
    } else {
      throw Exception('Failed to submit answer (${resp.statusCode})');
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

  // Kullanıcı analiz verilerini getirir (category correctness)
  Future<Map<String, dynamic>> getUserAnalysis(String idToken) async {
    final uri = Uri.parse('$backendBaseUrl/user/analysis/');
    final resp = await http.get(uri, headers: _getAuthHeaders(idToken));
    if (resp.statusCode == 200) {
      return _decodeResponseBody(resp.bodyBytes) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to load analysis (${resp.statusCode})');
    }
  }
  
  // Manual True/False questions loaded from repo-root data/manual_truefalse.json
  Future<List<Map<String, dynamic>>> getManualTrueFalse({String? idToken}) async {
    final uri = Uri.parse('$backendBaseUrl/manual/truefalse/');
    final headers = idToken != null ? _getAuthHeaders(idToken) : <String, String>{};
    // no debug prints here to keep console clean
    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as List<dynamic>;
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } else if (resp.statusCode == 404) {
      // upstream: no manual TF available
      return <Map<String, dynamic>>[];
    } else {
      throw Exception('Failed to load manual true/false (${resp.statusCode})');
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

  // new: get localized texts for specific quiz question ids (no limits consumed)
  Future<List<Map<String, dynamic>>> getLocalizedQuizQuestions(String idToken, List<int> ids, {String? lang}) async {
    final idsParam = ids.join(",");
    final baseUri = Uri.parse("$backendBaseUrl/quiz/localize/");
    final uri = baseUri.replace(queryParameters: {
      'ids': idsParam,
      if (lang != null) 'lang': lang,
    });

    final resp = await http.get(uri, headers: _getAuthHeaders(idToken));
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as List<dynamic>;
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } else if (resp.statusCode == 400) {
      // Backend considered the request invalid — don't spam logs, return empty to keep UI stable.
      if (kDebugMode) {
        print("getLocalizedQuizQuestions: bad request (400) for ids=$idsParam lang=$lang");
      }
      return <Map<String, dynamic>>[];
    } else {
      throw Exception('Failed to load localized quiz questions (${resp.statusCode})');
    }
  }

  // new: get localized text for a specific challenge id (no limits consumed)
  Future<Map<String, dynamic>> getLocalizedChallenge(String idToken, int challengeId, {String? lang}) async {
    final baseUri = Uri.parse("$backendBaseUrl/challenges/$challengeId/localize/");
    final uri = baseUri.replace(queryParameters: {
      if (lang != null) 'lang': lang,
    });
    final resp = await http.get(uri, headers: _getAuthHeaders(idToken));
    if (resp.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(resp.body) as Map);
    } else {
      throw Exception('Failed to load localized challenge (${resp.statusCode})');
    }
  }
}