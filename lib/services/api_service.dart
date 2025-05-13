// lib/services/api_service.dart
import 'dart:convert'; // JSON işlemleri için
import 'package:dio/dio.dart'; // HTTP istekleri için
import 'package:shared_preferences/shared_preferences.dart'; // user_id saklamak için
import 'package:logger/logger.dart'; // Loglama için
import 'dart:io'; // File sınıfı için
import 'package:intl/intl.dart'; // Tarih formatlama için

// API yanıtlarında veya ağ çağrılarında oluşabilecek hatalar için özel sınıf
class ApiException implements Exception {
  final String message;
  final int? statusCode; // HTTP durum kodu (varsa)
  final bool isNetworkError; // Ağ bağlantısı hatası mı?

  ApiException(this.message, this.statusCode, {this.isNetworkError = false});

  @override
  String toString() {
    String statusInfo = statusCode != null ? ' [Status: $statusCode]' : '';
    String typeInfo = isNetworkError ? ' (Network Error)' : '';
    return 'API Error$statusInfo$typeInfo: $message';
  }
}


class ApiService {
  // Backend sunucunuzun IP adresi ve portu.
  // Uygulamayı test ettiğiniz ağa göre burayı güncelleyin.
  // Örneğin, aynı ağdaysanız bilgisayarınızın yerel IP'si (192.168.x.x) veya 'localhost' (emulator/simulatör kullanıyorsanız)
  // veya Docker kullanıyorsanız servisin adı olabilir.
  // Docker içinde çalışıyorsa genellikle http://backend:5000 veya http://localhost:5000 (macOS/Windows) kullanılır.
  // Mobil cihazda test ediyorsanız, bilgisayarınızın aynı ağdaki IP adresini kullanın.
  // NOT: HTTPS kullanmıyorsanız, Android'de "cleartext traffic not permitted" hatası alabilirsiniz.
  // Bu durumda android/app/src/main/AndroidManifest.xml dosyasına network_security_config eklemeniz gerekebilir.
  static const String _baseUrl = 'http://10.0.2.2:5000/api';

  final Dio _dio = Dio();
  final Logger _logger = Logger(); // Logger örneği

  // Singleton deseni
  static final ApiService _instance = ApiService._internal();
  factory ApiService() {
    return _instance;
  }
  ApiService._internal() {
    // Dio instance'ına base URL ekle
    _dio.options.baseUrl = _baseUrl;
     _dio.options.connectTimeout = const Duration(seconds: 10); // Bağlantı zaman aşımı
     _dio.options.receiveTimeout = const Duration(seconds: 10); // Veri alma zaman aşımı

    // Interceptor ekleyerek her isteğe X-User-ID header'ını otomatik ekle
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final userId = await getUserId();
        if (userId != null) {
          options.headers['X-User-ID'] = userId.toString();
           _logger.d("Adding X-User-ID header: $userId to ${options.method} ${options.path}");
        } else {
           _logger.w("X-User-ID not found for ${options.method} ${options.path}. This request might require authentication.");
        }
        // Eğer body bir Map ise ve loglanabilir büyüklükteyse logla
        if (options.data != null) {
           try {
             // Dio isteğin türüne göre FormData veya JSON kullanır.
             // FormData ise content-type otomatik multipart/form-data olur.
             // Diğer durumlarda default application/json veya ayarlanmış olan kullanılır.
             // Sadece JSON gibi görünen metinleri loglayalım.
             if (options.headers['Content-Type'] == 'application/json' && options.data is Map) {
                final bodySnippet = jsonEncode(options.data);
                 // Düzeltilmiş satır: İç içe interpolation kullanıldı
                _logger.d("Request Body Snippet: ${bodySnippet.length > 500 ? '${bodySnippet.substring(0, 500)}...' : bodySnippet}");
             } else if (options.data is String && options.data.length < 500) {
                // Küçük string body'leri logla
                 _logger.d("Request Body Snippet (String): ${options.data}");
             } else if (options.data is FormData) {
                _logger.d("Request Body is FormData (not logged fully)");
             }
           } catch (e) {
              _logger.e("Failed to log request body: $e");
           }
        }
        return handler.next(options); // İsteğe devam et
      },
      onResponse: (response, handler) {
         _logger.d("API Response received: ${response.requestOptions.method} ${response.requestOptions.path} - Status: ${response.statusCode}");
         // Sadece başarılı durum kodları (2xx) için yanıtın bir kısmını logla
         if (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300) {
            try {
              // Yanıt veri tipi dynamic, Map veya List olabilir. JSON encode etmeye çalışalım.
               final responseBodySnippet = jsonEncode(response.data);
                // Düzeltilmiş satır: İç içe interpolation kullanıldı
               _logger.d("Response Body Snippet: ${responseBodySnippet.length > 500 ? '${responseBodySnippet.substring(0, 500)}...' : responseBodySnippet}");
            } catch (e) {
               _logger.e("Failed to log successful response body: ${e.toString()} (Data type: ${response.data.runtimeType})");
            }
         }
        return handler.next(response); // Yanıtı devam ettir
      },
      onError: (DioException e, handler) {
        _logger.e("API Error caught by Interceptor: ${e.requestOptions.method} ${e.requestOptions.path} - Status: ${e.response?.statusCode}");
        _logger.e("Error Message: ${e.message}");
         if (e.response?.data != null) {
             _logger.e("Error Response Data: ${e.response?.data}");
         }
        // Interceptor hatayı yakaladıktan sonra handler.next(e) çağrılmazsa hata yutulur.
        // Hatanın _handleRequest metoduna iletilmesi için throw e'yi çağıracağız.
        return handler.next(e); // Hatayı daha sonraki error handler'lara veya _handleRequest'in catch bloğuna ilet
      },
    ));
    _logger.i("ApiService initialized with base URL: $_baseUrl");
  }

  // --- SharedPreferences ile user_id Yönetimi ---
  Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_id');
  }

  Future<void> setUserId(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_id', userId);
     _logger.i("User ID saved locally: $userId");
  }

  Future<void> clearUserId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
     _logger.i("User ID cleared locally.");
  }

  // --- API Çağrıları İçin Genel Yardımcı Metot ---
  // Bu metot artık başarılı yanıtın içeriğini (Map veya List) doğrudan dönecek.
  // Hata durumlarında özel ApiException fırlatacak.
  Future<dynamic> _handleRequest(Future<Response> requestFuture) async {
    try {
      final response = await requestFuture; // Future bekleniyor

      // Başarılı yanıt durum kodları (2xx)
      if (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300) {
        // Backend'in JSON döndürdüğü varsayılıyor, Dio bunu otomatik parse eder
        // response.data dynamic tipindedir, çağıran metod doğru tipe cast etmeli.
        return response.data;
      } else {
         // Backend 2xx dışında bir durum kodu döndürdü ama hata fırlatmadı (örn: 401, 404, 409)
         String message = 'Sunucudan beklenmedik durum kodu: ${response.statusCode}';
         if (response.data is Map && response.data.containsKey('message')) {
            message = response.data['message'];
         } else if (response.data != null) {
             message = response.data.toString(); // Eğer Map değilse string olarak al
         }
         _logger.e("Non-2xx status code received: ${response.statusCode} - Message: $message");
         throw ApiException(message, response.statusCode); // Özel hata sınıfını fırlat
      }
    } on DioException catch (e) {
       // Dio tarafından yakalanan ağ hataları, timeout, 5xx server hataları vb.
       String message = 'Bir ağ hatası oluştu.'; // Genel hata mesajı
       bool isNetwork = false;
       int? statusCode = e.response?.statusCode; // Durum kodunu burada yakala

       if (e.response != null) {
          // Backend'den gelen spesifik hata mesajı varsa onu kullan
          if (e.response!.data is Map && e.response!.data.containsKey('message')) {
             message = e.response!.data['message'];
          } else if (e.response!.data != null) {
              message = e.response!.data.toString();
          } else {
             message = 'Sunucu hatası: ${e.response!.statusCode}';
          }
       } else {
          // Yanıt yoksa (ağ hatası, timeout vb.)
          switch (e.type) {
            case DioExceptionType.connectionTimeout:
            case DioExceptionType.receiveTimeout:
            case DioExceptionType.sendTimeout:
              message = 'İstek zaman aşımına uğradı.';
              isNetwork = true;
              break;
            case DioExceptionType.badResponse: // 4xx veya 5xx durum kodları yanıtı geldiğinde
              message = 'Sunucudan geçersiz yanıt: ${e.response?.statusCode}';
               if (e.response?.data != null) {
                  message += ' - Detay: ${e.response?.data}'; // Hata yanıtının içeriğini ekle
               }
              break;
            case DioExceptionType.cancel:
              message = 'İstek iptal edildi.';
              break;
            case DioExceptionType.connectionError: // Bağlantı kurulamadı
               message = 'Sunucuya bağlanılamadı. Adresi ve internet bağlantınızı kontrol edin.';
               isNetwork = true;
               break;
            case DioExceptionType.badCertificate: // SSL hatası
               message = 'SSL sertifika hatası.';
               isNetwork = true;
               break;
            case DioExceptionType.unknown: // Diğer bilinmeyen hatalar (Dart 3.0+ ile bu çok nadir olmalı)
               message = 'Beklenmedik ağ hatası: ${e.message}';
               isNetwork = true;
               break;
          }
       }

       _logger.e("Dio Error details: Type=${e.type}, Message=${e.message}, Response=${e.response?.data}, Stack=${e.stackTrace}");
       // ApiException nesnesine durumu kodu da gönder
       throw ApiException(message, statusCode, isNetworkError: isNetwork); // Özel hata sınıfını fırlat

    } catch (e, stackTrace) {
       // Dio dışındaki diğer beklenmedik hatalar
      _logger.e("Unexpected Error in _handleRequest: $e", error: e, stackTrace: stackTrace);
      throw ApiException('Genel bir hata oluştu: ${e.toString()}', null); // Özel hata sınıfını fırlat
    }
  }


  // --- Kullanıcı Kayıt (POST /api/register) ---
  Future<Map<String, dynamic>> register({
    required String ad,
    required String soyad,
    required String kullaniciAdi,
    required String sifre,
    required String eposta,
    String? dogumTarihi, // YYYY-MM-DD formatında string veya null
  }) async {
    _logger.i("Attempting to register user: $kullaniciAdi");
    final data = {
      'ad': ad,
      'soyad': soyad,
      'kullanici_adi': kullaniciAdi,
      'sifre': sifre,
      'eposta': eposta,
      'dogum_tarihi': dogumTarihi,
    };
    final responseData = await _handleRequest(_dio.post('/register', data: data));
    // _handleRequest hata fırlatmazsa responseData başarılı yanıtın içeriğidir.
    // Bu endpoint'in Map döndürdüğü varsayılıyor.
    return responseData as Map<String, dynamic>;
  }

  // --- Kullanıcı Giriş (POST /api/login) ---
  Future<Map<String, dynamic>> login({
    required String kullaniciAdi,
    required String sifre,
  }) async {
    _logger.i("Attempting to login user: $kullaniciAdi");
    final data = {
      'kullanici_adi': kullaniciAdi,
      'sifre': sifre,
    };
    final responseData = await _handleRequest(_dio.post('/login', data: data));

    // _handleRequest hata fırlatmazsa responseData başarılı yanıtın içeriğidir.
    // Bu endpoint'in Map döndürdüğü varsayılıyor.
    if (responseData is Map && responseData.containsKey('user_id') && responseData['user_id'] != null) {
       await setUserId(responseData['user_id']); // Başarılı girişte user_id'yi kaydet
       return responseData as Map<String, dynamic>;
    } else {
       // Başarılı 200 yanıtı geldi ama beklenen user_id Map içinde yok.
       _logger.e("Login successful, but user_id not found in response data.");
       throw ApiException('Giriş başarılı ancak kullanıcı kimliği alınamadı.', 200);
    }
  }

  // --- Profil Bilgilerini Getir (GET /api/profile) ---
  Future<Map<String, dynamic>> getProfile() async {
     _logger.i("Attempting to get profile.");
     final responseData = await _handleRequest(_dio.get('/profile'));
      // _handleRequest hata fırlatmazsa responseData başarılı yanıtın içeriğidir.
     // Bu endpoint'in Map döndürdüğü varsayılıyor.
     return responseData as Map<String, dynamic>;
  }

  // --- Profil Bilgilerini Güncelle (PUT /api/profile) ---
  // profileData Map'i sadece güncellenmek istenen alanları içermeli
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> profileData) async {
     _logger.i("Attempting to update profile.");
     // Frontend'in dogum_tarihi'ni YYYY-MM-DD formatında string veya null olarak gönderdiği varsayılıyor.
     final responseData = await _handleRequest(_dio.put('/profile', data: profileData));
     // _handleRequest hata fırlatmazsa responseData başarılı yanıtın içeriğidir.
     // Bu endpoint'in Map döndürdüğü varsayılıyor (mesaj içerir).
     return responseData as Map<String, dynamic>;
  }

  // --- Günlükleri Getir (GET /api/diary) ---
  Future<List<Map<String, dynamic>>> getDiaryEntries() async {
     _logger.i("Attempting to get diary entries.");
     final responseData = await _handleRequest(_dio.get('/diary'));
     // _handleRequest hata fırlatmazsa responseData başarılı yanıtın içeriğidir.
     // Bu endpoint'in bir Liste döndürdüğü varsayılıyor.
     if (responseData is List) {
        // List<dynamic> olarak gelen yanıtı List<Map<String, dynamic>>'e dönüştür
        return List<Map<String, dynamic>>.from(responseData.map((item) => item as Map<String, dynamic>));
     } else {
        // Beklenen liste gelmedi, backend yapısı değişmiş olabilir veya hata.
        _logger.e("Expected List from /diary but received: ${responseData.runtimeType}");
        throw ApiException('Günlükler alınırken beklenmeyen yanıt formatı.', null);
     }
  }

  // --- Günlük Ekle (POST /api/diary) ---
  Future<Map<String, dynamic>> addDiaryEntry({
    required String baslik,
    required String dusunce,
    // Backend şu anda stil veya ses yolu beklemiyor bu endpointte, sadece metin ve duygu
    // String? audioPath, // Backend'e ses dosyasını göndermek isterseniz buraya eklenmeli
    // Map<String, dynamic>? style, // Backend'e stili kaydetmek isterseniz buraya eklenmeli
  }) async {
    _logger.i("Attempting to add diary entry: '$baslik'");
    final data = {
      'baslik': baslik,
      'dusunce': dusunce,
      // 'audioPath': audioPath, // Backend'e ses dosyasını göndermek isterseniz
      // 'style': style, // Backend'e stili kaydetmek isterseniz
    };
    final responseData = await _handleRequest(_dio.post('/diary', data: data));
     // _handleRequest hata fırlatmazsa responseData başarılı yanıtın içeriğidir.
    // Bu endpoint'in Map döndürdüğü varsayılıyor (yeni eklenen entry detayları).
    return responseData as Map<String, dynamic>;
  }

  // --- Günlük Güncelle (PUT /api/diary/<id>) ---
  Future<Map<String, dynamic>> updateDiaryEntry({
    required int entryId,
    required String baslik,
    required String dusunce,
     // Backend şu anda stil veya ses yolu güncellemesi beklemiyor bu endpointte
    // String? audioPath, // Backend'e ses dosyasını göndermek isterseniz
    // Map<String, dynamic>? style, // Backend'e stili kaydetmek isterseniz
  }) async {
    _logger.i("Attempting to update diary entry: $entryId");
    final data = {
      'baslik': baslik,
      'dusunce': dusunce,
      // 'audioPath': audioPath, // Backend'e ses dosyasını göndermek isterseniz
      // 'style': style, // Backend'e stili kaydetmek isterseniz
    };
    final responseData = await _handleRequest(_dio.put('/diary/$entryId', data: data));
     // _handleRequest hata fırlatmazsa responseData başarılı yanıtın içeriğidir.
    // Bu endpoint'in Map döndürdüğü varsayılıyor (güncellenen entry detayları veya mesaj).
    return responseData as Map<String, dynamic>;
  }

  // --- Günlük Sil (DELETE /api/diary/<id>) ---
  Future<void> deleteDiaryEntry(int entryId) async {
     _logger.i("Attempting to delete diary entry: $entryId");
     // DELETE genellikle 204 No Content veya bir mesaj içeren 200 döndürür.
     // _handleRequest 2xx durum kodunda veriyi döndürür.
     await _handleRequest(_dio.delete('/diary/$entryId'));
     // Eğer 204 dönerse response.data null olabilir.
     // Eğer 200 + body dönerse response.data o body olur.
     // Fonksiyon başarılıysa hata fırlatmayacak.
  }

  // --- Duygu Analizi ve Plan Al (POST /api/diary/analyze-and-plan) ---
  Future<Map<String, dynamic>> analyzeAndPlan(String text) async {
     _logger.i("Attempting to analyze text and get plan.");
     final data = {'text': text};
     final responseData = await _handleRequest(_dio.post('/diary/analyze-and-plan', data: data));
     // _handleRequest hata fırlatmazsa responseData başarılı yanıtın içeriğidir.
     // Bu endpoint'in Map döndürdüğü varsayılıyor.
     return responseData as Map<String, dynamic>;
  }

  // --- Hatırlatıcıları Getir (GET /api/reminders) ---
  Future<List<Map<String, dynamic>>> getReminders() async {
     _logger.i("Attempting to get reminders.");
     final responseData = await _handleRequest(_dio.get('/reminders'));
     // _handleRequest hata fırlatmazsa responseData başarılı yanıtın içeriğidir.
     // Bu endpoint'in bir Liste döndürdüğü varsayılıyor.
     if (responseData is List) {
        return List<Map<String, dynamic>>.from(responseData.map((item) => item as Map<String, dynamic>));
     } else {
        _logger.e("Expected List from /reminders but received: ${responseData.runtimeType}");
        throw ApiException('Hatırlatıcılar alınırken beklenmeyen yanıt formatı.', null);
     }
  }

  // --- Hatırlatıcı Ekle (POST /api/reminders) ---
  Future<Map<String, dynamic>> addReminder({
    required DateTime dateTime, // Mobil DateTime objesi al
    required String description,
  }) async {
     _logger.i("Attempting to add reminder: '$description'");
     // Backend date (YYYY-MM-DD string) ve time (HH:MM:SS string) bekliyor
     final data = {
       'date': DateFormat('yyyy-MM-dd').format(dateTime),
       'time': DateFormat('HH:mm:ss').format(dateTime),
       'description': description,
     };
     final responseData = await _handleRequest(_dio.post('/reminders', data: data));
      // _handleRequest hata fırlatmazsa responseData başarılı yanıtın içeriğidir.
     // Bu endpoint'in Map döndürdüğü varsayılıyor (yeni eklenen reminder detayları).
     return responseData as Map<String, dynamic>;
  }

  // --- Hatırlatıcı Güncelle (PUT /api/reminders/<id>) ---
   Future<Map<String, dynamic>> updateReminder({
    required int reminderId,
    DateTime? dateTime, // Güncellenecekse DateTime veya null
    String? description, // Güncellenecekse String veya null
    bool? notified, // Güncellenecekse bool veya null
  }) async {
     _logger.i("Attempting to update reminder: $reminderId");
     final data = <String, dynamic>{};

     if (dateTime != null) {
       data['date'] = DateFormat('yyyy-MM-dd').format(dateTime);
       data['time'] = DateFormat('HH:mm:ss').format(dateTime);
     }
     if (description != null) {
       data['description'] = description;
     }
     if (notified != null) {
       // Backend'in 0/1 beklediğini varsayarak gönderelim
       data['notified'] = notified ? 1 : 0;
     }

     if (data.isEmpty) {
         _logger.w("Update Reminder called with no data for ID: $reminderId");
          throw ApiException('Güncellenecek geçerli bir bilgi sağlanmadı.', 400);
       }

     final responseData = await _handleRequest(_dio.put('/reminders/$reminderId', data: data));
     // _handleRequest hata fırlatmazsa responseData başarılı yanıtın içeriğidir.
     // Bu endpoint'in Map döndürdüğü varsayılıyor (mesaj içerir).
     return responseData as Map<String, dynamic>;
  }

  // --- Hatırlatıcı Sil (DELETE /api/reminders/<id>) ---
  Future<void> deleteReminder(int reminderId) async {
     _logger.i("Attempting to delete reminder: $reminderId");
     // Başarılıysa hata fırlatmayacak
     await _handleRequest(_dio.delete('/reminders/$reminderId'));
  }


  // --- Haftalık Görevleri Getir (GET /api/weekly-planner) ---
   Future<Map<String, List<Map<String, dynamic>>>> getWeeklyTasks() async {
     _logger.i("Attempting to get weekly tasks.");
     final responseData = await _handleRequest(_dio.get('/weekly-planner'));
      // _handleRequest hata fırlatmazsa responseData başarılı yanıtın içeriğidir.
     // Bu endpoint'in Map<String, List> döndürdüğü varsayılıyor.
     if (responseData is Map) {
        return Map<String, List<Map<String, dynamic>>>.from(responseData.map((key, value) {
           if (value is List) {
             // Map'in içindeki liste öğelerini Map'e dönüştür
             return MapEntry(key.toString(), List<Map<String, dynamic>>.from(value.map((item) => item as Map<String, dynamic>)));
           } else {
              _logger.w("Expected List for key '$key' in weekly tasks but received: ${value.runtimeType}");
              return MapEntry(key.toString(), <Map<String, dynamic>>[]); // Liste gelmezse boş liste koy
           }
        }));
     } else {
        _logger.e("Expected Map from /weekly-planner but received: ${responseData.runtimeType}");
        throw ApiException('Haftalık görevler alınırken beklenmeyen yanıt formatı.', null);
     }
   }

  // --- Haftalık Görev Ekle (POST /api/weekly-planner) ---
   Future<Map<String, dynamic>> addTask({
     required String day, // 'monday', 'tuesday' vb. formatında (backend'e uygun)
     required String taskText,
   }) async {
      _logger.i("Attempting to add task for $day: '$taskText'");
      final data = {
        'gun': day,
        'gorev_metni': taskText,
      };
      final responseData = await _handleRequest(_dio.post('/weekly-planner', data: data));
       // _handleRequest hata fırlatmazsa responseData başarılı yanıtın içeriğidir.
      // Bu endpoint'in Map döndürdüğü varsayılıyor (yeni eklenen task detayları).
      return responseData as Map<String, dynamic>;
   }

  // --- Haftalık Görev Güncelle (PUT /api/weekly-planner/<id>) ---
   Future<Map<String, dynamic>> updateTask({
     required int taskId,
     String? taskText, // Güncellenecekse
     bool? completed, // Güncellenecekse (true/false)
   }) async {
      _logger.i("Attempting to update task: $taskId");
      final data = <String, dynamic>{};
      if (taskText != null) {
         data['gorev_metni'] = taskText;
      }
      if (completed != null) {
         data['tamamlandi'] = completed; // Backend bool bekliyor, doğrudan bool gönderelim.
      }

       if (data.isEmpty) {
         _logger.w("Update Task called with no data for ID: $taskId");
          throw ApiException('Güncellenecek geçerli bir bilgi sağlanmadı.', 400);
       }

      final responseData = await _handleRequest(_dio.put('/weekly-planner/$taskId', data: data));
       // _handleRequest hata fırlatmazsa responseData başarılı yanıtın içeriğidir.
      // Bu endpoint'in Map döndürdüğü varsayılıyor (mesaj içerir).
      return responseData as Map<String, dynamic>;
   }

  // --- Haftalık Görev Sil (DELETE /api/weekly-planner/<id>) ---
   Future<void> deleteTask(int taskId) async {
      _logger.i("Attempting to delete task: $taskId");
       // Başarılıysa hata fırlatmayacak
      await _handleRequest(_dio.delete('/weekly-planner/$taskId'));
   }

   // --- Duygu İstatistiklerini Getir (GET /api/diary/sentiment-stats) ---
    Future<Map<String, int>> getSentimentStats(String period) async {
      _logger.i("Attempting to get sentiment stats for period: $period");
       // period parametresi 'weekly' veya 'monthly' olmalı. Backend bunu doğruluyor.
      final responseData = await _handleRequest(_dio.get('/diary/sentiment-stats', queryParameters: {'period': period}));

       // _handleRequest hata fırlatmazsa responseData başarılı yanıtın içeriğidir.
      // Bu endpoint'in Map<String, int> döndürdüğü varsayılıyor.
      if (responseData is Map) {
         // Map'in değerlerinin int olduğundan emin olalım
         return Map<String, int>.from(responseData.map((key, value) => MapEntry(key.toString(), value as int)));
      } else {
         _logger.e("Expected Map from /diary/sentiment-stats but received: ${responseData.runtimeType}");
         throw ApiException('Duygu istatistikleri alınırken beklenmeyen yanıt formatı.', null);
      }
    }

   // --- Ses Dosyası Yükle ve Çevir (POST /api/transcribe) ---
   // NOT: journal_page.dart şu anda ses kaydını locale kaydediyor ve local oynatıyor.
   // Bu metot, eğer ses kaydını backend'e gönderip backend'in çeviri yapmasını isterseniz kullanılır.
   // journal_page.dart'ın bu metodu kullanacak şekilde güncellenmesi gerekir.
   Future<Map<String, dynamic>> uploadAudioForTranscription(File audioFile) async {
      _logger.i("Attempting to upload audio file for transcription: ${audioFile.path}");
      // Dosyanın varlığını kontrol et
      if (!await audioFile.exists()) {
         _logger.e("Audio file not found at path: ${audioFile.path}");
         throw ApiException('Ses dosyası bulunamadı.', 400); // 400 Bad Request gibi düşünebiliriz
      }

      // FormData oluştur (multipart/form-data için)
      // Dosya adını otomatik alır veya belirtebilirsiniz
      FormData formData = FormData.fromMap({
         "audio": await MultipartFile.fromFile(audioFile.path, filename: audioFile.path.split('/').last),
      });

      // POST isteği yap
      final responseData = await _handleRequest(_dio.post('/transcribe', data: formData));
       // _handleRequest hata fırlatmazsa responseData başarılı yanıtın içeriğidir.
      // Bu endpoint'in Map döndürdüğü varsayılıyor.
      return responseData as Map<String, dynamic>;
   }

}