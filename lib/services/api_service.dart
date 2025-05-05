// lib/services/api_service.dart
import 'dart:convert'; // JSON işlemleri için
import 'package:http/http.dart' as http; // HTTP istekleri için
import 'package:flutter/foundation.dart'; // kDebugMode ve debugPrint için

// ÖNEMLİ: Burayı backend sunucunuzun adresine göre AYARLAYIN.
// Android Emülatör için: http://10.0.2.2:5000/api
// iOS Simülatör için: http://localhost:5000/api veya http://127.0.0.1:5000/api
// Fiziksel Cihaz için: http://[BilgisayarınızınYerelIPAdresi]:5000/api
const String baseUrl = 'http://10.0.2.2:5000/api'; // Varsayılan olarak Android Emülatör için

class ApiService {
  // HTTP istekleri için bir client oluşturuyoruz. Bağlantıları daha verimli yönetir.
  final client = http.Client();

  // Genel POST isteği fonksiyonu
  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> data) async {
    final url = Uri.parse('$baseUrl/$endpoint');
    debugPrint('API POST isteği: $url'); // Debug çıktısı

    try {
      final response = await client.post(
        url,
        headers: {'Content-Type': 'application/json'}, // JSON gönderdiğimizi belirtiyoruz
        body: jsonEncode(data), // Dart Map'ini JSON string'e çeviriyoruz
      );

      debugPrint('API POST yanıtı Durum: ${response.statusCode}');
      if (kDebugMode) { // Sadece debug modunda ham yanıtı logla
        // Yanıt gövdesini decode edip logluyoruz (UTF-8 hatası olmaması için)
        debugPrint('Ham Yanıt: ${utf8.decode(response.bodyBytes)}');
      }

      // Yanıtı işleme (2xx başarılı durumlar)
      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
             // Yanıt gövdesini JSON olarak çözme
             final dynamic responseBody = jsonDecode(utf8.decode(response.bodyBytes));
             // Başarılı yanıtların genellikle Map olduğunu varsayıyoruz
             if (responseBody is Map<String, dynamic>) {
                  return {'statusCode': response.statusCode, 'body': responseBody};
             } else {
                 // Başarılı ama JSON Map'i olmayan yanıtlar için (örn: 204 No Content)
                 debugPrint('API Service POST Hata: Beklenmeyen JSON formatı yanıtı $url');
                 return {'statusCode': response.statusCode, 'body': {'message': 'İşlem başarılı ancak sunucudan beklenmedik yanıt formatı geldi.'}};
             }
        } catch (e) {
            // JSON parse etme hatası
            debugPrint('API Service POST Hata: JSON çözme hatası $url - $e');
            return {'statusCode': 500, 'body': {'message': 'Sunucudan gelen yanıt işlenemedi.'}};
        }

      } else {
        // Hata durumları (4xx, 5xx)
        String errorMessage = 'Bir hata oluştu (${response.statusCode}).';
        try {
             // Hata yanıtı da JSON içerebilir
             final dynamic errorBody = jsonDecode(utf8.decode(response.bodyBytes));
             if (errorBody is Map<String, dynamic> && errorBody.containsKey('message')) {
                 errorMessage = errorBody['message'];
             } else {
                 // Standart olmayan hata yanıtı
                 debugPrint('API Service POST Hata: Standart olmayan hata yanıtı $url - Durum: ${response.statusCode}');
             }
        } catch (e) {
             // Hata yanıtı JSON değilse
             debugPrint('API Service POST Hata: Hata yanıtı JSON çözme hatası $url - $e');
        }
        return {'statusCode': response.statusCode, 'body': {'message': errorMessage}};
      }
    } on http.ClientException catch (e) {
       // Ağ bağlantısı hataları (örn: sunucu kapalı, adres yanlış)
       debugPrint('API Service POST Ağ Hatası $url: $e'); // Debug çıktısı
       return {'statusCode': 503, 'body': {'message': 'Sunucuya bağlanılamadı. Lütfen internet bağlantınızı veya sunucu durumunu kontrol edin.'}};
    } catch (e) {
      // Beklenmedik diğer hatalar
      debugPrint('API Service POST Beklenmedik Hata $url: $e'); // Debug çıktısı
      return {'statusCode': 500, 'body': {'message': 'Beklenmedik bir hata oluştu.'}};
    }
  }

   // Kimlik doğrulama gerektiren GET isteği (X-User-ID header ekler)
   Future<Map<String, dynamic>> get(String endpoint, {required int userId}) async {
        final url = Uri.parse('$baseUrl/$endpoint');
        debugPrint('API GET isteği: $url (User ID: $userId)');
        try {
            // X-User-ID header'ını ekliyoruz
            final headers = {'Content-Type': 'application/json', 'X-User-ID': userId.toString()};

            final response = await client.get(url, headers: headers);

             debugPrint('API GET yanıtı Durum: ${response.statusCode}');
             if (kDebugMode) {
                debugPrint('Ham Yanıt: ${utf8.decode(response.bodyBytes)}');
             }


            if (response.statusCode >= 200 && response.statusCode < 300) {
                 try {
                     final dynamic responseBody = jsonDecode(utf8.decode(response.bodyBytes));
                     return {'statusCode': response.statusCode, 'body': responseBody};
                 } catch (e) {
                     debugPrint('API Service GET Hata: JSON çözme hatası $url - $e');
                     return {'statusCode': 500, 'body': {'message': 'Sunucudan gelen yanıt işlenemedi.'}};
                 }
            } else {
                 String errorMessage = 'Bir hata oluştu (${response.statusCode}).';
                 try {
                    final dynamic errorBody = jsonDecode(utf8.decode(response.bodyBytes));
                     if (errorBody is Map<String, dynamic> && errorBody.containsKey('message')) {
                         errorMessage = errorBody['message'];
                     } else {
                         debugPrint('API Service GET Hata: Standart olmayan hata yanıtı veya JSON çözme hatası $url - Durum: ${response.statusCode}');
                     }
                 } catch (e) {
                     debugPrint('API Service GET Hata: Hata yanıtı JSON çözme hatası $url - $e');
                 }
                 return {'statusCode': response.statusCode, 'body': {'message': errorMessage}};
            }
        } on http.ClientException catch (e) {
            debugPrint('API Service GET Ağ Hatası $url: $e');
            return {'statusCode': 503, 'body': {'message': 'Sunucuya bağlanılamadı. Lütfen internet bağlantınızı veya sunucu durumunu kontrol edin.'}};
        } catch (e) {
            debugPrint('API Service GET Beklenmedik Hata $url: $e');
            return {'statusCode': 500, 'body': {'message': 'Beklenmedik bir hata oluştu.'}};
        }
   }

    // PUT (Kimlik doğrulama gerektirir)
   Future<Map<String, dynamic>> put(String endpoint, Map<String, dynamic> data, {required int userId}) async {
        final url = Uri.parse('$baseUrl/$endpoint');
        debugPrint('API PUT isteği: $url (User ID: $userId)');
        try {
            final headers = {'Content-Type': 'application/json', 'X-User-ID': userId.toString()};

            final response = await client.put(
                url,
                headers: headers,
                body: jsonEncode(data),
            );

            debugPrint('API PUT yanıtı Durum: ${response.statusCode}');
             if (kDebugMode) {
                debugPrint('Ham Yanıt: ${utf8.decode(response.bodyBytes)}');
            }

             if (response.statusCode >= 200 && response.statusCode < 300) {
                 try {
                     final dynamic responseBody = jsonDecode(utf8.decode(response.bodyBytes));
                     if (responseBody is Map<String, dynamic>) {
                         return {'statusCode': response.statusCode, 'body': responseBody};
                     } else {
                          debugPrint('API Service PUT Hata: Beklenmeyen JSON formatı yanıtı $url');
                          return {'statusCode': response.statusCode, 'body': {'message': 'Güncelleme başarılı ancak sunucudan beklenmedik yanıt formatı geldi.'}};
                     }
                 } catch (e) {
                     debugPrint('API Service PUT Hata: JSON çözme hatası $url - $e');
                     return {'statusCode': 500, 'body': {'message': 'Sunucudan gelen yanıt işlenemedi.'}};
                 }
            } else {
                 String errorMessage = 'Bir hata oluştu (${response.statusCode}).';
                 try {
                    final dynamic errorBody = jsonDecode(utf8.decode(response.bodyBytes));
                     if (errorBody is Map<String, dynamic> && errorBody.containsKey('message')) {
                         errorMessage = errorBody['message'];
                     } else {
                         debugPrint('API Service PUT Hata: Standart olmayan hata yanıtı veya JSON çözme hatası $url - Durum: ${response.statusCode}');
                     }
                 } catch (e) {
                     debugPrint('API Service PUT Hata: Hata yanıtı JSON çözme hatası $url - $e');
                 }
                 return {'statusCode': response.statusCode, 'body': {'message': errorMessage}};
            }
        } on http.ClientException catch (e) {
            debugPrint('API Service PUT Ağ Hatası $url: $e');
            return {'statusCode': 503, 'body': {'message': 'Sunucuya bağlanılamadı. Lütfen internet bağlantınızı veya sunucu durumunu kontrol edin.'}};
        } catch (e) {
            debugPrint('API Service PUT Beklenmedik Hata $url: $e');
            return {'statusCode': 500, 'body': {'message': 'Beklenmedik bir hata oluştu.'}};
        }
   }

    // DELETE (Kimlik doğrulama gerektirir)
   Future<Map<String, dynamic>> delete(String endpoint, {required int userId}) async {
        final url = Uri.parse('$baseUrl/$endpoint');
        debugPrint('API DELETE isteği: $url (User ID: $userId)');
        try {
            final headers = {'Content-Type': 'application/json', 'X-User-ID': userId.toString()};

            final response = await client.delete(
                url,
                headers: headers,
            );

            debugPrint('API DELETE yanıtı Durum: ${response.statusCode}');
            if (kDebugMode) {
                // DELETE 204 No Content döndürebilir, body boş olabilir
                debugPrint('Ham Yanıt: ${utf8.decode(response.bodyBytes)}');
            }


             if (response.statusCode >= 200 && response.statusCode < 300) {
                 // Başarılı silme genellikle 200 OK (body ile) veya 204 No Content (boş body)
                 String successMessage = 'Silme işlemi başarılı.';
                 dynamic responseBody;
                 try {
                     // 204'te body olmayabilir, bu durumda parse hatası olur
                     responseBody = jsonDecode(utf8.decode(response.bodyBytes));
                     if (responseBody is Map<String, dynamic> && responseBody.containsKey('message')) {
                         successMessage = responseBody['message'];
                     }
                 } catch (e) {
                     // Body yoksa veya JSON değilse normal kabul et (özellikle 204 için)
                     debugPrint('API Service DELETE Uyarı: Başarılı yanıtta body yok veya JSON değil (muhtemelen 204).');
                 }

                 return {'statusCode': response.statusCode, 'body': {'message': successMessage}};

            } else {
                 String errorMessage = 'Bir hata oluştu (${response.statusCode}).';
                 try {
                    final dynamic errorBody = jsonDecode(utf8.decode(response.bodyBytes));
                     if (errorBody is Map<String, dynamic> && errorBody.containsKey('message')) {
                         errorMessage = errorBody['message'];
                     } else {
                         debugPrint('API Service DELETE Hata: Standart olmayan hata yanıtı veya JSON çözme hatası $url - Durum: ${response.statusCode}');
                     }
                 } catch (e) {
                     debugPrint('API Service DELETE Hata: Hata yanıtı JSON çözme hatası $url - $e');
                 }
                 return {'statusCode': response.statusCode, 'body': {'message': errorMessage}};
            }
        } on http.ClientException catch (e) {
            debugPrint('API Service DELETE Ağ Hatası $url: $e');
            return {'statusCode': 503, 'body': {'message': 'Sunucuya bağlanılamadı. Lütfen internet bağlantınızı veya sunucu durumunu kontrol edin.'}};
        } catch (e) {
            debugPrint('API Service DELETE Beklenmedik Hata $url: $e');
            return {'statusCode': 500, 'body': {'message': 'Beklenmedik bir hata oluştu.'}};
        }
   }


  void dispose() {
    client.close();
  }
}