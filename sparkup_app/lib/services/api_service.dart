import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import '../models/leaderboard_entry.dart';

// main.dart dosyasında tanımlanan global backendBaseUrl'ı kullanacağız.
// NOT: Bu dosyada kullanabilmek için, ya main.dart dosyasındaki
//      backendBaseUrl değişkenini buraya kopyalamalıyız (http://127.0.0.1:8000)
//      ya da main.dart'tan export etmeliyiz.
// Şimdilik buraya sabit değerini kopyalıyorum:
const String backendBaseUrl = "http://127.0.0.1:8000";


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


  // --- Genel Endpoitler (AUTH GEREKMEZ) ---
  
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


  // --- Kullanıcı Tercih Endpoitleri (AUTH GEREKİR) ---

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


  // --- İçerik Endpoitleri (AUTH GEREKİR) ---
  
  // Rastgele bilgi kartı getirir
  Future<Map<String, dynamic>> getRandomInfo(String idToken, {String? category}) async {
    final uri = Uri.parse("$backendBaseUrl/info/random/${category != null ? '?category=$category' : ''}");
    final response = await http.get(
      uri, 
      headers: _getAuthHeaders(idToken) // Token'lı istek
    ); 
    if (response.statusCode == 200) {
      return _decodeResponseBody(response.bodyBytes);
    } else {
      throw Exception("Failed to load info. Status: ${response.statusCode}, Body: ${response.body}");
    }
  }

  // Quiz soruları getirir
  Future<List<Map<String, dynamic>>> getQuizQuestions(String idToken, {int limit = 3, String? category}) async {
    final uri = Uri.parse("$backendBaseUrl/quiz/?limit=$limit${category != null ? '&category=$category' : ''}");
    final response = await http.get(
      uri, 
      headers: _getAuthHeaders(idToken) // Token'lı istek
    ); 
    if (response.statusCode == 200) {
      final List<dynamic> data = _decodeResponseBody(response.bodyBytes);
      return List<Map<String, dynamic>>.from(data);
    } else {
      throw Exception("Failed to load quiz questions. Status: ${response.statusCode}, Body: ${response.body}");
    }
  }

  // Rastgele meydan okuma (challenge) getirir
  Future<Map<String, dynamic>> getRandomChallenge(String idToken) async {
    final uri = Uri.parse("$backendBaseUrl/challenges/random/");
    final response = await http.get(
      uri, 
      headers: _getAuthHeaders(idToken) // Token'lı istek
    );
    if (response.statusCode == 200) {
      return _decodeResponseBody(response.bodyBytes);
    } else {
      throw Exception("Failed to load challenge. Status: ${response.statusCode}, Body: ${response.body}");
    }
  }

  // --- Lider Tablosu Endpoitleri (AUTH GEREKİR) ---

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
  
  // YENİ ENDPOINT: Kullanıcının kendi sıralama ve puan bilgisini getirir
  Future<LeaderboardEntry?> getUserRank(String idToken) async {
    // Backend'de "/leaderboard/me/" gibi bir endpoint olduğunu varsayıyoruz
    final uri = Uri.parse('$backendBaseUrl/leaderboard/me/');
    final response = await http.get(uri, headers: _getAuthHeaders(idToken));

    if (response.statusCode == 200) {
      final data = _decodeResponseBody(response.bodyBytes);
      // Gelen veriye göre rütbe adını ekliyoruz
      data['rank_name'] = _getRankName(data['score'] ?? 0);
      return LeaderboardEntry.fromJson(data);
    } 
    // Kullanıcı listede yoksa veya 404 dönerse null döndürülebilir
    else if (response.statusCode == 404) {
      return null;
    }
    else {
      throw Exception('Failed to load user rank. Status: ${response.statusCode}, Body: ${response.body}');
    }
  }
}

// --- RÜTBE HESAPLAMA YARDIMCI METODU ---

String _getRankName(int score) {
    if (score >= 10000) {
        return 'Üstad';
    } else if (score >= 5000) {
        return 'Elmas';
    } else if (score >= 2000) {
        return 'Altın';
    } else if (score >= 1000) {
        return 'Gümüş';
    } else if (score >= 500) {
        return 'Bronz';
    } else {
        return 'Demir';
    }
}