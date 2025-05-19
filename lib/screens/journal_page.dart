// journal_page.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart'; // ImagePicker eklendi
import 'package:flutter_html/flutter_html.dart'; // flutter_html paketini import et

// import '../database/database_helper.dart'; // Lokal veritabanı kaldırılacak
import '../services/api_service.dart'; // ApiService import edildi
// import 'package:intl/intl.dart'; // Eğer burada tarih formatlama yapılıyorsa import edilebilir, şu an JournalEntry modelinde kullanılıyor.
// c:\src\digital_gunluk3\lib\models\journal_entry.dart

class JournalStyle {
  final Color backgroundColor;
  final double fontSize;
  final String fontFamily; // DİKKAT: Bu alan 'String' ise ve null olamazsa
  final Color textColor;
  final bool isBold;
  final bool isItalic;
  final bool isUnderlined;

  JournalStyle({
    required this.backgroundColor,
    required this.fontSize,
    required this.fontFamily,
    required this.textColor,
    required this.isBold,
    required this.isItalic,
    required this.isUnderlined,
  });

  factory JournalStyle.fromMap(Map<String, dynamic> map) {
    return JournalStyle(
      // ignore: deprecated_member_use
      backgroundColor: Color(map['backgroundColor'] as int? ?? Colors.white.value),
      fontSize: (map['fontSize'] as num? ?? 18.0).toDouble(),
      // Eğer map['fontFamily'] null ise ve fontFamily alanı null olamazsa (String ise) HATA VERİR.
      // DOĞRU YAKLAŞIM:
      fontFamily: map['fontFamily'] as String? ?? 'Roboto', // Null ise 'Roboto' kullan
      // ignore: deprecated_member_use
      textColor: Color(map['textColor'] as int? ?? Colors.black87.value),
      isBold: map['isBold'] as bool? ?? false,
      isItalic: map['isItalic'] as bool? ?? false,
      isUnderlined: map['isUnderlined'] as bool? ?? false,
    );
  }

  Future<Map<String, dynamic>> toMap() async {
    return {
      // ignore: deprecated_member_use
      'backgroundColor': backgroundColor.value,
      'fontSize': fontSize,
      'fontFamily': fontFamily,
      // ignore: deprecated_member_use
      'textColor': textColor.value,
      'isBold': isBold,
      'isItalic': isItalic,
      'isUnderlined': isUnderlined,
    };
  }
}

class JournalEntry {
  final int? id;
  final String title;
  final String content;
  final String? audioUrl; // Eskiden audioPath idi, şimdi URL veya backend yolu
  final String? imageUrl; // Yeni: Resim URL'si veya backend yolu
  final DateTime createdAt;
  final JournalStyle style;
  // Belki başka String alanlarınız da vardır, onları da kontrol edin!
  // final String mood; // Örnek

  JournalEntry({
    this.id,
    required this.title,
    required this.content,
    this.audioUrl,
    this.imageUrl,
    required this.createdAt,
    required this.style,
    
    // required this.mood, // Örnek
  });
  
  String? get fullImageUrl {
    if (imageUrl == null || imageUrl!.isEmpty) return null;
    // Eğer imageUrl zaten tam bir URL ise (http:// veya https:// ile başlıyorsa) doğrudan döndür
    if (imageUrl!.startsWith('http://') || imageUrl!.startsWith('https://')) {
      return imageUrl;
    }
    return '${ApiService.baseUrl.replaceAll("/api", "")}$imageUrl'; // ApiService.baseUrl kullanarak eriş
  }

  factory JournalEntry.fromMap(Map<String, dynamic> map) {
    final styleMap = map['style'] as Map<String, dynamic>? ?? {};
    return JournalEntry(
      id: map['id'] as int?,
      title: map['baslik'] as String? ?? '',
      content: map['dusunce'] as String? ?? '',
      audioUrl: map['audio_url'] as String?, // Backend'den 'audio_url' bekleniyor
      imageUrl: map['image_url'] as String?, // Backend'den 'image_url' bekleniyor
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
      style: JournalStyle.fromMap(styleMap),
      // mood: map['mood'] as String? ?? 'Bilinmiyor', // Örnek null kontrolü
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'baslik': title,
      'dusunce': content,
      'audio_url': audioUrl,
      'image_url': imageUrl,
      'created_at': createdAt.toIso8601String(),
      'style': style.toMap(),
      // 'mood': mood, // Örnek
    };
  }
}

class JournalPage extends StatefulWidget {
  const JournalPage({super.key});

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  // --- State Değişkenleri ---
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<RecordState>? _recordSub;
  RecordState _recordState = RecordState.stop;
  StreamSubscription<Amplitude>? _amplitudeSub;
  Amplitude? _amplitude;

  String? _audioFilePath; // Yeni kaydedilen ses dosyasının lokal yolu
  File? _selectedImageFile; // Yeni seçilen resim dosyasının lokal yolu

  String? _editingAudioUrl; // Düzenlenen girdinin mevcut ses URL'si
  String? _editingImageUrl; // Düzenlenen girdinin mevcut resim URL'si

  // Stil state'leri (varsayılanlar biraz daha belirgin olabilir)
  // Arka plan rengi state'i zaten mevcuttu
  Color _backgroundColor = Colors.white;
  double _fontSize = 18.0; // Varsayılan font boyutu biraz arttırıldı
  String _selectedFont = 'Roboto';
  Color _textColor = Colors.black87; // Varsayılan yazı rengi biraz daha koyu yapıldı
  bool _isBold = false;
  bool _isItalic = false;
  bool _isUnderlined = false;

  // Veritabanı ve liste state'leri
  // final DatabaseHelper _dbHelper = DatabaseHelper(); // Lokal veritabanı kaldırıldı
  final ApiService _apiService = ApiService(); // ApiService örneği
  List<Map<String, dynamic>> _journalEntries = []; // Artık Map listesi tutacağız
  JournalEntry? _editingEntry; // Düzenlenmekte olan günlük girdisi

  // Düzenleme veya Yeni Giriş modunu kontrol etmek için
  bool get _isEditing => _editingEntry != null;

   // ScrollController ekleyerek üst kısma kaydırma
  final ScrollController _scrollController = ScrollController();

  // --- Init and Dispose ---
  @override
  void initState() {
    super.initState();
    _initRecorder();
    _checkPermissions();
    _loadJournalEntries(); // Kaydedilmiş girdileri yükle
  }

  @override
  void dispose() {
    _recordSub?.cancel();
    _amplitudeSub?.cancel();
    _recorder.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _scrollController.dispose();
    // ApiService'i dispose etmeye gerek yok, singleton yönetiyor
    super.dispose();
  }

  // --- Recorder Metotları ---
  void _initRecorder() {
     _recordSub = _recorder.onStateChanged().listen((recordState) {
      if (mounted) { // mounted kontrolü StatefulWidget'in hayat döngüsü için önemlidir
        setState(() => _recordState = recordState);
      }
      debugPrint("Record state changed: $recordState");
    });

    _amplitudeSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 300))
        .listen((amp) {
           if (mounted) { // mounted kontrolü
              setState(() => _amplitude = amp);
           }
        });
  }

  Future<bool> _checkPermissions() async {
    debugPrint("Checking microphone permission...");
    var status = await Permission.microphone.status;
    debugPrint("Initial microphone permission status: $status");
    if (!status.isGranted) {
      debugPrint("Requesting microphone permission...");
      status = await Permission.microphone.request();
      debugPrint("Permission status after request: $status");
    }
    if (!status.isGranted) {
       debugPrint("Microphone permission denied.");
       if (!mounted) return false; // mounted kontrolü
       ScaffoldMessenger.of(context).showSnackBar( // context kullanımı
        const SnackBar(content: Text('Mikrofon izni reddedildi! Kayıt yapılamaz.')),
      );
    } else {
       debugPrint("Microphone permission granted.");
    }
    return status.isGranted;
  }

  Future<bool> _checkCameraPermission() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
    }
    if (!status.isGranted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kamera izni reddedildi!')),
      );
    }
    return status.isGranted;
  }

   Future<void> _startRecording() async {
    if (_isEditing) {
       if (!mounted) return; // mounted kontrolü
       ScaffoldMessenger.of(context).showSnackBar( // context kullanımı
        const SnackBar(content: Text('Lütfen kayda başlamadan önce düzenlemeyi tamamlayın veya yeni bir giriş başlatın.')),
      );
      return;
    }

    debugPrint("Attempting to start recording...");
    if (!await _checkPermissions()) {
       debugPrint("Permission check failed before starting.");
       return;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      if (_audioFilePath != null) {
         final oldFile = File(_audioFilePath!);
         if (await oldFile.exists()) {
            await oldFile.delete();
            debugPrint("Deleted old audio file: $_audioFilePath");
         }
      }

      final filePath =
          '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      debugPrint("Generated file path: $filePath");

      final recordingDir = File(filePath).parent;
      if (!await recordingDir.exists()) {
        await recordingDir.create(recursive: true);
        debugPrint("Created directory: ${recordingDir.path}");
      }

      await _recorder.start(const RecordConfig(), path: filePath);
      debugPrint("Recorder start command issued.");

      if (!mounted) return; // mounted kontrolü
      ScaffoldMessenger.of(context).showSnackBar( // context kullanımı
        const SnackBar(content: Text('Kayıt başladı!')),
      );
    } catch (e, stackTrace) {
      debugPrint('Error starting recording: $e');
      debugPrint('Stack trace: $stackTrace');
      if (!mounted) return; // mounted kontrolü
      ScaffoldMessenger.of(context).showSnackBar( // context kullanımı
        SnackBar(content: Text('Kayıt başlatılamadı: ${e.toString()}')),
      );
      if (mounted) { // mounted kontrolü
        setState(() { // setState kullanımı
           _recordState = RecordState.stop; // state değişkeni
           _audioFilePath = null; // state değişkeni
        });
      }
    }
  }

  Future<void> _stopRecording() async {
    debugPrint("Attempting to stop recording...");
    if (_recordState == RecordState.record || _recordState == RecordState.pause) { // state değişkeni
       try {
        final path = await _recorder.stop();
        debugPrint("Recorder stopped. Returned path: $path");

        if (!mounted) return; // mounted kontrolü

        setState(() { // setState kullanımı
          _audioFilePath = path; // state değişkeni
        });

        if (path != null) {
          if (mounted) { // mounted kontrolü
            ScaffoldMessenger.of(context).showSnackBar( // context kullanımı
              SnackBar(content: Text('Ses kaydı tamamlandı! Kaydedildi: $path')),
            );
          }
        } else {
          if (mounted) { // mounted kontrolü
            ScaffoldMessenger.of(context).showSnackBar( // context kullanımı
              const SnackBar(content: Text('Kayıt durduruldu ancak dosya yolu alınamadı.')),
            );
          }
           if (mounted) { // mounted kontrolü
              setState(() => _audioFilePath = null); // setState kullanımı, state değişkeni
           }
        }
      } catch (e, stackTrace) {
        debugPrint('Error stopping recording: $e');
        debugPrint('Stack trace: $stackTrace');
        if (!mounted) return; // mounted kontrolü
        ScaffoldMessenger.of(context).showSnackBar( // context kullanımı
          SnackBar(content: Text('Kayıt durdurulamadı: ${e.toString()}')),
        );
         if (mounted) { // mounted kontrolü
           setState(() { // setState kullanımı
             _recordState = RecordState.stop; // state değişkeni
             _audioFilePath = null; // state değişkeni
           });
         }
      }
    } else {
       debugPrint("Stop recording called but recorder state is already: $_recordState"); // state değişkeni
    }
  }

  Future<void> _pauseRecording() async {
    if (_recordState == RecordState.record) { // state değişkeni
      try {
        debugPrint("Attempting to pause recording...");
        await _recorder.pause();
        debugPrint("Recording paused state triggered via API.");
        // State listener updates _recordState
      } catch (e) {
         debugPrint("Error pausing recording: $e");
          if (mounted) { // mounted kontrolü
            ScaffoldMessenger.of(context).showSnackBar( // context kullanımı
              SnackBar(content: Text('Kayıt duraklatılamadı: ${e.toString()}')),
            );
          }
      }
    } else {
       debugPrint("Pause recording called but recorder state is: $_recordState"); // state değişkeni
    }
  }

  Future<void> _resumeRecording() async {
     if (_recordState == RecordState.pause) { // state değişkeni
      try {
        debugPrint("Attempting to resume recording...");
        await _recorder.resume();
        debugPrint("Recording resumed state triggered via API.");
         // State listener updates _recordState
      } catch (e) {
         debugPrint("Error resuming recording: $e");
          if (mounted) { // mounted kontrolü
            ScaffoldMessenger.of(context).showSnackBar( // context kullanımı
              SnackBar(content: Text('Kayda devam edilemedi: ${e.toString()}')),
            );
          }
      }
    } else {
       debugPrint("Resume recording called but recorder state is: $_recordState"); // state değişkeni
    }
  }

  Future<void> _openRecordedFile() async {
    if (_audioFilePath != null) { // state değişkeni
       final file = File(_audioFilePath!); // state değişkeni
       if (await file.exists()) {
         try {
          // Add mounted check before using context after await
          if (!mounted) {
             debugPrint("Widget not mounted before OpenFile.open call.");
             return;
          }
          final result = await OpenFile.open(_audioFilePath!); // state değişkeni
          debugPrint('OpenFile result: ${result.type} ${result.message}');
          if (!mounted) return; // mounted kontrolü

          if (result.type != ResultType.done) {
            ScaffoldMessenger.of(context).showSnackBar( // context kullanımı
              SnackBar(content: Text('Dosya açılamadı: ${result.message}')),
            );
          }
        } catch (e) {
          debugPrint('Error opening file: $e');
          if (!mounted) return; // mounted kontrolü
           ScaffoldMessenger.of(context).showSnackBar( // context kullanımı
              SnackBar(content: Text('Dosya açılırken hata oluştu: ${e.toString()}')),
            );
        }
       } else {
          debugPrint("Attempted to open file, but file doesn't exist at path: $_audioFilePath"); // state değişkeni
          if (!mounted) return; // mounted kontrolü
          ScaffoldMessenger.of(context).showSnackBar( // context kullanımı
            const SnackBar(content: Text('Ses dosyası bulunamadı (silinmiş olabilir)!')),
          );
       }
    } else {
      debugPrint("Attempted to open file, but _audioFilePath is null."); // state değişkeni
      if (!mounted) return; // mounted kontrolü
      ScaffoldMessenger.of(context).showSnackBar( // context kullanımı
        const SnackBar(content: Text('Önce bir ses kaydı yapın veya kayıt yolu bulunamadı.')),
      );
    }
  }

  // --- Stil Değiştirme Fonksiyonları ---
  void _changeBackgroundColor(Color color) {
    setState(() { // setState kullanımı
      _backgroundColor = color; // state değişkeni
    });
  }

  void _changeFontSize(double size) {
    setState(() { // setState kullanımı
      _fontSize = size; // state değişkeni
    });
  }

  void _changeFont(String font) {
    setState(() { // setState kullanımı
      _selectedFont = font; // state değişkeni
    });
  }

  void _changeTextColor(Color color) {
    setState(() { // setState kullanımı
      _textColor = color; // state değişkeni
    });
  }

  void _toggleBold() {
    setState(() { // setState kullanımı
      _isBold = !_isBold; // state değişkeni
    });
  }

  void _toggleItalic() {
    setState(() { // setState kullanımı
      _isItalic = !_isItalic; // state değişkeni
    });
  }

  void _toggleUnderline() {
    setState(() { // setState kullanımı
      _isUnderlined = !_isUnderlined; // state değişkeni
    });
  }

  // --- Resim Seçme Fonksiyonu ---
  Future<void> _pickImage(ImageSource source) async {
    if (_recordState != RecordState.stop) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen önce ses kaydını durdurun.')),
      );
      return;
    }
    // Kamera için izin kontrolü (isteğe bağlı, image_picker kendi de isteyebilir)
    if (source == ImageSource.camera && !await _checkCameraPermission()) {
      return;
    }

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source, imageQuality: 80, maxWidth: 1024);

      if (pickedFile != null) {
        setState(() {
          _selectedImageFile = File(pickedFile.path);
          _editingImageUrl = null; // Yeni resim seçildiğinde, düzenleme URL'sini temizle
        });
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Resim seçildi.')),
          );
        }
      } else {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Resim seçilmedi.')),
          );
        }
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Resim seçerken hata: ${e.toString()}')));
    }
  }
  // --- Duygu Analizi (Simülasyon) ---
  void _analyzeSentiment() {
      String title = _titleController.text; // controller kullanımı
      String content = _contentController.text; // controller kullanımı

      if (title.isEmpty && content.isEmpty && _audioFilePath == null) { // state değişkeni
         if (!mounted) return; // mounted kontrolü
         ScaffoldMessenger.of(context).showSnackBar( // context kullanımı
            const SnackBar(content: Text('Analiz edilecek bir günlük girişi yok.')),
         );
         return;
      }

      String sentiment = "Nötr"; // Varsayılan duygu durumu
      String analysisText = "";
      String suggestionsText = "";

      // Metin analizi
      if (title.isNotEmpty || content.isNotEmpty) {
          final fullText = "${title.toLowerCase()} ${content.toLowerCase()}";

          if (fullText.contains('mutlu') || fullText.contains('sevindim') ||
              fullText.contains('harika') || fullText.contains('güzel') ||
              fullText.contains('iyi hissediyorum') || fullText.contains('keyifli')) {
             sentiment = "Pozitif";
             analysisText = "Yazılı içerik: Pozitif görünüyor 🎉😊";
             suggestionsText = """Harika bir gün geçirmişsin! Bu olumlu enerjiyi sürdürmek için:
- Bugün seni mutlu eden 3 şeyi daha düşün.
- Sevdiğin bir aktiviteyi yap.
- Bu anı yakalamak için fotoğraf çek.
- Bir arkadaşınla hislerini paylaş.""";
          } else if (fullText.contains('üzgün') || fullText.contains('kötü') ||
                     fullText.contains('canım sıkkın') || fullText.contains('sinirli') ||
                     fullText.contains('yalnız hissediyorum') || fullText.contains('moralim bozuk')) {
             sentiment = "Negatif";
             analysisText = "Yazılı içerik: Negatif görünüyor 😞😠";
             suggestionsText = """Zor bir gün olmuş gibi görünüyor. Kendine iyi bakmak için:
- Derin nefes egzersizleri yap.
- Sevdiğin rahatlatıcı bir müziği dinle.
- Güvendiğin biriyle konuşmayı düşün.
- Kısa bir yürüyüşe çık.
- Yarın için küçük bir hedef belirle.""";
          } else {
             sentiment = "Nötr";
             analysisText = "Yazılı içerik: Nötr veya belirsiz görünüyor 🤔";
             suggestionsText = """Gün içinde sakin bir denge bulmuşsun gibi. Bu durumu değerlendirmek için:
- Gününün nasıl geçtiğini daha detaylı düşün. Seni şaşırtan bir şey oldu mu?
- Yeni bir şeyler öğrenmeyi dene (podcast dinle, kısa bir makale oku).
- Gelecek planların üzerine biraz kafa yor.
- Yaratıcı bir şeyler yap (çizim, yazı vb.).""";
          }
      } else {
           // Sadece ses kaydı varsa ve metin yoksa
           analysisText = "Yazılı içerik yok. Ses kaydı analizi için ses işleme gerekir. 🎙️";
            sentiment = "Nötr"; // Ses analizini simüle edemediğimiz için varsayılan nötr
             suggestionsText = """Ses kaydını dinleyerek o anki duygu durumunu anlamaya çalışabilirsin.
- Kaydı dinlerken hangi duyguları hissettiğini not al.
- Kendine karşı nazik ol."""; // Ses kaydı için basit bir öneri
      }


      // Ses kaydı analizi simülasyonu (Ek metin ekler)
      if (_audioFilePath != null && (title.isNotEmpty || content.isNotEmpty)) { // state değişkeni
           analysisText += "\nSes kaydı: Analiz için ses işleme gerekir. 🎙️";
      }
       if (title.isEmpty && content.isEmpty && _audioFilePath != null) { // state değişkeni
           analysisText = "Ses kaydı analizi için ses işleme gerekir. 🎙️";
       }

       // Add mounted check before showing dialog
       if (!mounted) return; // mounted kontrolü

      showDialog( // context kullanımı
          context: context,
          builder: (context) => AlertDialog(
              title: Text('$sentiment Duygu Analizi Sonucu'),
              content: SingleChildScrollView(
                 child: ListBody(
                   children: <Widget>[
                     Text(analysisText),
                     const SizedBox(height: 16),
                     const Text('Öneriler:', style: TextStyle(fontWeight: FontWeight.bold)),
                     const SizedBox(height: 8),
                     Text(suggestionsText),
                     if (_audioFilePath != null && !(title.isNotEmpty || content.isNotEmpty)) ...[ // state değişkeni
                         const SizedBox(height: 8),
                         const Text('Ses kaydını dinlemek için çal butonunu kullanabilirsiniz.', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
                     ],
                   ],
                 ),
              ),
              actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context), // context kullanımı
                      child: const Text('Tamam'),
                  ),
              ],
              insetPadding: const EdgeInsets.all(24.0),
          ),
      );
  }
  

  // --- Veritabanı ve Günlük Yönetimi ---
  Future<void> _loadJournalEntries() async {
    if (!mounted) return;
    
    try {
       final List<Map<String, dynamic>> entries = await _apiService.getDiaryEntries();
       if (mounted) { // mounted kontrolü
         setState(() { // setState kullanımı
           // Backend'den gelen tarih string'ini DateTime'a çevirip sıralama yapabiliriz
           // Şimdilik backend'in sıralı gönderdiğini varsayalım veya ters çevirelim
           _journalEntries = entries.reversed.toList();
           debugPrint("Loaded ${_journalEntries.length} journal entries."); // state değişkeni
         });
       }
    } on ApiException catch (e) {
       debugPrint("API Error loading journal entries: ${e.message}");
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Günlükler yüklenirken API hatası: ${e.message}')),
         );
       }
    } catch (e) { // Diğer genel hatalar
       debugPrint("Error loading journal entries: $e");
       if (mounted) { // mounted kontrolü
         ScaffoldMessenger.of(context).showSnackBar( // context kullanımı
           SnackBar(content: Text('Günlükler yüklenirken hata oluştu: ${e.toString()}')),
         );
       }
    }
  }

  Future<void> _saveJournalEntry() async {
    String title = _titleController.text.trim(); // controller kullanımı
    String content = _contentController.text.trim(); // controller kullanımı

    if (title.isEmpty && content.isEmpty && _audioFilePath == null && _selectedImageFile == null && !_isEditing) {
       if (!mounted) return; // mounted kontrolü
       ScaffoldMessenger.of(context).showSnackBar( // context kullanımı
         const SnackBar(content: Text('Başlık, içerik veya ses kaydı boş olamaz.')),
       );
       return;
    }

    if (_recordState != RecordState.stop) { // state değişkeni
       await _stopRecording(); // _stopRecording metodu
    }


    bool success = false;
    String successMessage = '';

    File? audioToSave = _audioFilePath != null ? File(_audioFilePath!) : null;
    File? imageToSave = _selectedImageFile;

    JournalStyle currentStyle = JournalStyle(
      backgroundColor: _backgroundColor,
      fontSize: _fontSize,
      fontFamily: _selectedFont,
      textColor: _textColor,
      isBold: _isBold,
      isItalic: _isItalic,
      isUnderlined: _isUnderlined,
    );
    Map<String, dynamic> styleMap = await currentStyle.toMap(); // JournalStyle'ı Map'e çevir

    try {
      if (_isEditing) { // _isEditing getter'ı
        // Düzenleme
        if (_editingEntry == null || _editingEntry!.id == null) {
          debugPrint("Error: Editing entry or its ID is null.");
          if (mounted) {
            _showErrorSnackbar('Düzenlenecek giriş bulunamadı.');
          }
          return;
        }
        await _apiService.updateDiaryEntry(
          entryId: _editingEntry!.id!, // Backend'den gelen ID'yi kullan
          baslik: title,
          dusunce: content,
          audioFile: audioToSave, // Yeni ses dosyası varsa gönder
          imageFile: imageToSave, // Yeni resim dosyası varsa gönder
          style: styleMap, // styleMap'i buraya ekle
        );
        debugPrint("Updating entry ID: ${_editingEntry!.id}");
        successMessage = 'Günlük başarıyla güncellendi!';
        success = true;
      } else {
        // Yeni giriş
        await _apiService.addDiaryEntry(
          baslik: title,
          dusunce: content,
          audioFile: audioToSave,
          imageFile: imageToSave,
          style: styleMap, // styleMap'i buraya ekle
        );
        debugPrint("Inserting new entry.");
        successMessage = 'Günlük başarıyla kaydedildi!';
        success = true;
      }

      if (success) {
        await _loadJournalEntries(); // _loadJournalEntries metodu
        _clearForm(); // _clearForm metodu
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar( // context kullanımı
            SnackBar(content: Text(successMessage)),
          );
        }
      }
    } on ApiException catch (e) {
      debugPrint('API Error saving journal entry: ${e.message}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Günlük kaydedilirken API hatası: ${e.message}')),
      );
    } catch (e, stackTrace) { // Diğer genel hatalar
      debugPrint('Error saving journal entry: $e');
       debugPrint('Stack trace: $stackTrace');
      if (!mounted) return; // mounted kontrolü
      ScaffoldMessenger.of(context).showSnackBar( // context kullanımı
        SnackBar(content: Text('Günlük kaydedilirken hata oluştu: ${e.toString()}')),
      );
    }
  }

  void _clearForm() {
    setState(() { // setState kullanımı
      _titleController.clear(); // controller kullanımı
      _contentController.clear(); // controller kullanımı
      _selectedImageFile = null; // state değişkeni
      _audioFilePath = null; // state değişkeni
      _editingEntry = null; // state değişkeni
      _editingImageUrl = null;
      _editingAudioUrl = null;

      // Stili varsayılana döndür
      _backgroundColor = Colors.white; // state değişkeni
      _fontSize = 18.0; // state değişkeni
      _selectedFont = 'Roboto'; // state değişkeni
      _textColor = Colors.black87; // state değişkeni
      _isBold = false; // state değişkeni
      _isItalic = false; // state değişkeni
      _isUnderlined = false; // state değişkeni
      // Kayıt devam ediyorsa durdur
      if (_recordState != RecordState.stop) { // state değişkeni
         _stopRecording(); // _stopRecording metodu
      }
    });
     // TextField focus'unu kaldır
    FocusScope.of(context).unfocus(); // context kullanımı
  }

  void _editJournalEntry(Map<String, dynamic> entryMap) {
    if (_recordState != RecordState.stop) { // state değişkeni
       if (!mounted) return; // mounted kontrolü
       ScaffoldMessenger.of(context).showSnackBar( // context kullanımı
        const SnackBar(content: Text('Lütfen kaydı durdurun veya tamamlayın.')),
      );
       return;
    }

    // Backend'den gelen Map'i kullanarak JournalEntry ve JournalStyle oluştur
    // Bu kısım backend'den gelen yanıta göre ayarlanmalı.
    // Şimdilik temel alanları alıyoruz. Stil ve createdAt backend'den nasıl geliyorsa ona göre parse edilmeli.
    final int? entryId = entryMap['id'] as int?;
    if (entryId == null) {
      debugPrint("Error: Entry ID is null in _editJournalEntry.");
      _showErrorSnackbar("Düzenlenecek girişin kimliği bulunamadı.");
      return;
    }

    // _editingEntry'yi JournalEntry olarak tutmaya devam edebiliriz,
    // ancak API'ye gönderirken Map kullanacağız.
    // Backend'den gelen 'created_at' veya benzeri bir tarih alanı varsa onu parse etmeliyiz.
    // Şimdilik varsayılan bir tarih kullanalım veya backend'den geleni doğrudan alalım.
    // Stil bilgisi de backend'den geliyorsa parse edilmeli.
    // Bu örnekte, stil bilgilerini lokal state'ten yüklüyoruz, bu ideal değil.
    // Backend'in stil bilgilerini de döndürmesi ve kaydetmesi gerekir.

    setState(() { // setState kullanımı
      // Workaround: Create a mutable copy of entryMap to preprocess potentially null string fields.
      // This is to prevent errors in JournalEntry.fromMap if it expects non-null strings
      // for fields like 'baslik' or 'dusunce' but receives null from the backend.
      // The ideal fix is to make JournalEntry.fromMap in journal_entry.dart null-safe.
      final Map<String, dynamic> processedEntryMap = Map.from(entryMap);
      if (processedEntryMap['baslik'] == null) {
        processedEntryMap['baslik'] = ''; // Default to empty string if null
      }
      if (processedEntryMap['dusunce'] == null) {
        processedEntryMap['dusunce'] = ''; // Default to empty string if null
      }
      // If other String fields in JournalEntry might be null and cause this error,
      // add similar checks for them here.

      // It's good practice if JournalEntry.fromMap also correctly parses styles.
      // If _editingEntry.style is properly populated, you could use that as the source.
      // For this fix, we'll directly parse from entryMap as the commented code suggested.
      _editingEntry = JournalEntry.fromMap(processedEntryMap); // Use the preprocessed map
      _titleController.text = processedEntryMap['baslik'] as String? ?? ''; // This was already null-safe
      _contentController.text = processedEntryMap['dusunce'] as String? ?? ''; // This was also null-safe
      
      _editingAudioUrl = processedEntryMap['audio_url'] as String?; // Backend'den gelen URL
      _editingImageUrl = processedEntryMap['image_url'] as String?; // Backend'den gelen URL
      _audioFilePath = null; // Düzenleme modunda yeni lokal kayıt yok
      _selectedImageFile = null; // Düzenleme modunda yeni lokal resim yok
      // Load styles from the entryMap. Assumes entryMap might have a 'style' sub-map.
      // Using processedEntryMap here too, though 'style' handling was likely already robust.
      final Map<String, dynamic> styles = processedEntryMap['style'] as Map<String, dynamic>? ?? {};

      // ignore: deprecated_member_use
      _backgroundColor = Color(styles['backgroundColor'] as int? ?? Colors.white.value);
      _fontSize = (styles['fontSize'] as num? ?? 18.0).toDouble();
      // Assuming the style map uses 'fontFamily' for the font name. Adjust if your backend uses a different key.
      _selectedFont = styles['fontFamily'] as String? ?? 'Roboto'; 
      // ignore: deprecated_member_use
      _textColor = Color(styles['textColor'] as int? ?? Colors.black87.value);
      _isBold = styles['isBold'] as bool? ?? false;
      _isItalic = styles['isItalic'] as bool? ?? false;
      _isUnderlined = styles['isUnderlined'] as bool? ?? false;
    });

    _scrollToTop(); // _scrollToTop metodu
  }

  Future<void> _deleteJournalEntry(int entryId) async {
    final confirmed = await showDialog<bool>( // context kullanımı
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Silmeyi Onayla'),
        content: const Text('Bu günlük girdisini silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), // context kullanımı
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true), // context kullanımı
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _apiService.deleteDiaryEntry(entryId);

         // Eğer silinen giriş şu anda düzenleniyorsa formu temizle
        if (_editingEntry?.id == entryId) { // state değişkeni
           _clearForm(); // _clearForm metodu
        }
        await _loadJournalEntries(); // _loadJournalEntries metodu

        if (!mounted) return; // mounted kontrolü
        ScaffoldMessenger.of(context).showSnackBar( // context kullanımı
          const SnackBar(content: Text('Günlük başarıyla silindi.')),
        );
      } on ApiException catch (e) {
        debugPrint("API Error deleting journal entry: ${e.message}");
        if (!mounted) return;
        _showErrorSnackbar("Günlük silinirken API hatası: ${e.message}");
      } catch (e) {
        debugPrint("Error deleting journal entry: $e");
         if (!mounted) return; // mounted kontrolü
         ScaffoldMessenger.of(context).showSnackBar( // context kullanımı
           SnackBar(content: Text('Günlük silinirken hata oluştu: ${e.toString()}')),
         );
      }
    }
  }

  void _scrollToTop() {
     if (_scrollController.hasClients) { // _scrollController kullanımı
        _scrollController.animateTo( // _scrollController kullanımı
           0,
           duration: const Duration(milliseconds: 300),
           curve: Curves.easeOut,
        );
     }
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // --- Build Metodu ---
  @override
  Widget build(BuildContext context) { // context parametresi
    final bool isRecording = _recordState == RecordState.record; // state değişkeni
    final bool isPaused = _recordState == RecordState.pause; // state değişkeni
    final bool isStopped = _recordState == RecordState.stop; // state değişkeni

    // TextField'lar için stil (Kullanıcının seçtiği rengi kullanır)
    final currentTextFieldTextStyle = TextStyle(
      fontSize: _fontSize, // state değişkeni
      fontFamily: _selectedFont == 'Roboto' ? null : _selectedFont, // state değişkeni
      color: _textColor, // state değişkeni
      fontWeight: _isBold ? FontWeight.bold : FontWeight.normal, // state değişkeni
      fontStyle: _isItalic ? FontStyle.italic : FontStyle.normal, // state değişkeni
      decoration: _isUnderlined ? TextDecoration.underline : TextDecoration.none, // state değişkeni
      decorationColor: _textColor, // state değişkeni
      decorationThickness: _isUnderlined ? 1.5 : 1.0, // state değişkeni
    );


    final ColorScheme colorScheme = Theme.of(context).colorScheme; // context kullanımı
    final Color onSurfaceColor = colorScheme.onSurface;
    // final Color inactiveIconColor = onSurfaceColor.withAlpha(153); // Bu değişken kullanılmıyor, kaldırıldı.
    // final Color activeIconHighlightColor = colorScheme.primary.withAlpha(31); // Artık kullanılmayacak

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Günlük Düzenle' : 'Günlük Oluştur'), // _isEditing getter'ı
        // Deprecated withOpacity yerine withAlpha kullanıldı
        backgroundColor: isRecording ? Colors.red.withAlpha(26) : null, // (255 * 0.1).round() -> 26
        elevation: isRecording ? 0 : null,
        actions: [
           if (_isEditing) // _isEditing getter'ı
             IconButton(
               icon: const Icon(Icons.add_box_outlined, color: Colors.black),
               tooltip: 'Yeni Giriş',
               onPressed: _clearForm, // _clearForm metodu
             ),
          IconButton(
            icon: Icon(_isEditing ? Icons.save_as_outlined : Icons.save_outlined, color: Colors.black), // _isEditing getter'ı
            tooltip: _isEditing ? 'Güncelle' : 'Kaydet', // _isEditing getter'ı
            onPressed: (isRecording || isPaused) ? null : _saveJournalEntry,
            disabledColor: onSurfaceColor.withAlpha(77), // (255 * 0.3).round() -> 77
          ),
           IconButton(
             icon: const Icon(Icons.analytics_outlined, color: Colors.black),
             tooltip: 'Duygu Analizi Yap',
             onPressed: _analyzeSentiment, // _analyzeSentiment metodu
           ),
           IconButton(
             icon: const Icon(Icons.photo_camera_outlined, color: Colors.black),
             tooltip: 'Resim Ekle/Değiştir',
             onPressed: () => _showImageSourceDialog(context),
           ),
        ],
      ),
      body: Container(
        // Arka plan rengi Container'ın dekorasyonunda değil, doğrudan renginde ayarlandı
        color: _backgroundColor, // state değişkeni
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
            child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Expanded(
                   flex: 1, // Metin alanının esnekçe büyümesini sağla
                   child: SingleChildScrollView(
                     controller: _scrollController, // _scrollController kullanımı
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       mainAxisSize: MainAxisSize.min, // İçeriğe göre minimum boyut
                       children: [
                         SingleChildScrollView(
                           scrollDirection: Axis.horizontal,
                           child: Container(
                             padding: const EdgeInsets.symmetric(vertical: 4.0),
                             child: Row(
                               mainAxisSize: MainAxisSize.min,
                               children: [
                                  DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                     value: _selectedFont, // state değişkeni
                                     items: [
                                       'Roboto', 'Arial', 'Times New Roman', 'Courier New',
                                       'Verdana', 'Georgia', 'Comic Sans MS', 'Trebuchet MS',
                                       'Impact', 'Tahoma',
                                     ].map((font) {
                                       return DropdownMenuItem(
                                         value: font,
                                         child: Text(font, style: TextStyle(fontFamily: font == 'Roboto' ? null : font)),
                                       );
                                     }).toList(),
                                     onChanged: (value) {
                                       if (value != null) _changeFont(value); // _changeFont metodu
                                     },
                                        isDense: true,
                                   ),
                                   ),
                                  const SizedBox(width: 12),
                                 DropdownButtonHideUnderline(
                                   child: DropdownButton<double>(
                                     value: _fontSize, // state değişkeni
                                     items: [12.0, 14.0, 16.0, 18.0, 20.0, 22.0, 24.0, 26.0, 28.0, 30.0]
                                         .map((size) {
                                       return DropdownMenuItem(
                                         value: size,
                                         child: Text('${size.toInt()}'),
                                       );
                                     }).toList(),
                                     onChanged: (value) {
                                       if (value != null) _changeFontSize(value); // _changeFontSize metodu
                                     },
                                     isDense: true,
                                   ),
                                 ),
                                 const SizedBox(width: 12),
                                 IconButton(
                                   icon: const Icon(Icons.format_color_text, color: Colors.black), // Yazı rengi seçici ikonu siyah
                                   tooltip: 'Yazı Rengi Seç',
                                   onPressed: () => _showColorPicker(isBackground: false), // _showColorPicker metodu
                                    iconSize: 24,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                 ),
                                 const SizedBox(width: 12),
                                 IconButton(
                                   icon: const Icon(Icons.format_bold, color: Colors.black),
                                   tooltip: 'Kalın',
                                   // color: _isBold ? colorScheme.primary : inactiveIconColor, // Kaldırıldı, direkt siyah
                                    style: IconButton.styleFrom(
                                      backgroundColor: _isBold ? Colors.grey.shade300 : Colors.transparent, // state değişkeni, aktif arka planı gri tonu yapabiliriz
                                    ),
                                   onPressed: _toggleBold, // _toggleBold metodu
                                    iconSize: 24,
                                    padding: const EdgeInsets.all(6),
                                    constraints: const BoxConstraints(),
                                 ),
                                  const SizedBox(width: 4),
                                 IconButton(
                                   icon: const Icon(Icons.format_italic, color: Colors.black),
                                   tooltip: 'İtalik',
                                   // color: _isItalic ? colorScheme.primary : inactiveIconColor, // Kaldırıldı
                                    style: IconButton.styleFrom(
                                      backgroundColor: _isItalic ? Colors.grey.shade300 : Colors.transparent, // state değişkeni
                                   ),
                                   onPressed: _toggleItalic, // _toggleItalic metodu
                                   iconSize: 24,
                                   padding: const EdgeInsets.all(6),
                                   constraints: const BoxConstraints(),
                                 ),
                                  const SizedBox(width: 4),
                                 IconButton(
                                   icon: const Icon(Icons.format_underline, color: Colors.black),
                                   tooltip: 'Altı Çizili',
                                   // color: _isUnderlined ? colorScheme.primary : inactiveIconColor, // Kaldırıldı
                                    style: IconButton.styleFrom(
                                      backgroundColor: _isUnderlined ? Colors.grey.shade300 : Colors.transparent, // state değişkeni
                                    ),
                                   onPressed: _toggleUnderline, // _toggleUnderline metodu
                                    iconSize: 24,
                                    padding: const EdgeInsets.all(6),
                                    constraints: const BoxConstraints(),
                                 ),
                                 const SizedBox(width: 12),
                                  // Arka plan rengi seçici butonu ve yanındaki renk göstergesi
                                  Row(
                                     mainAxisSize: MainAxisSize.min,
                                     children: [
                                        // Renk göstergesi
                                        Container(
                                           width: 24,
                                           height: 24,
                                           margin: const EdgeInsets.only(right: 4.0),
                                           decoration: BoxDecoration(
                                              color: _backgroundColor, // Şu anki arka plan rengini göster
                                              border: Border.all(color: Colors.grey.shade400, width: 0.5),
                                              shape: BoxShape.circle,
                                           ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.color_lens, color: Colors.black), // Arka plan rengi seçici ikonu siyah
                                          tooltip: 'Arka Plan Rengi Seç',
                                           style: IconButton.styleFrom(
                                              backgroundColor: _backgroundColor, // Arka plan rengi butonun kendi rengi olarak kalabilir
                                              side: BorderSide(color: Colors.grey.shade400, width: 0.5),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                              elevation: 2.0,
                                           ),
                                          onPressed: () => _showColorPicker(isBackground: true), // _showColorPicker metodu
                                           iconSize: 24,
                                           padding: const EdgeInsets.all(6),
                                           constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                        ),
                                     ],
                                  ),
                               ],
                             ),
                           ),
                         ),
                         const Divider(height: 1),

                         // Ses kayıt kontrolleri
                         Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                           child: Row(
                             mainAxisAlignment: MainAxisAlignment.center,
                             children: [
                                // Start Button
                                if (isStopped)
                                   IconButton(
                                    icon: const Icon(Icons.mic_none, color: Colors.black),
                                    tooltip: 'Kaydı Başlat',
                                    onPressed: _startRecording, // _startRecording metodu
                                    // color: colorScheme.primary, // Kaldırıldı
                                     iconSize: 28,
                                  ),
                                // Stop Button
                                   if (isRecording || isPaused)
                                    IconButton(
                                     icon: const Icon(Icons.stop_circle_outlined, color: Colors.redAccent), // Durdurma ikonu kırmızı kalabilir
                                     tooltip: 'Kaydı Durdur',
                                     onPressed: _stopRecording, // _stopRecording metodu
                                     // color: Colors.redAccent, // Zaten ikon içinde belirtildi
                                      iconSize: 28,
                                   ),
                                // Pause Button
                                   if (isRecording)
                                     IconButton(
                                      icon: const Icon(Icons.pause_circle_outline, color: Colors.orangeAccent), // Duraklatma ikonu turuncu kalabilir
                                      tooltip: 'Kaydı Duraklat',
                                      onPressed: _pauseRecording, // _pauseRecording metodu
                                       // color: Colors.orangeAccent, // Zaten ikon içinde belirtildi
                                        iconSize: 28,
                                    ),
                                  // Resume Button
                                  if (isPaused)
                                    IconButton(
                                      icon: const Icon(Icons.play_circle_outline, color: Colors.green), // Devam etme ikonu yeşil kalabilir
                                      tooltip: 'Kayda Devam Et',
                                      onPressed: _resumeRecording, // _resumeRecording metodu
                                      // color: Colors.green, // Zaten ikon içinde belirtildi
                                       iconSize: 28,
                                    ),
                                   // Play Recorded File Button
                                  IconButton(
                                    icon: const Icon(Icons.play_circle_fill_outlined, color: Colors.black),
                                    tooltip: 'Kaydedilen Sesi Çal',
                                    // Sadece kayıt durdurulmuşsa ve dosya yolu varsa çalabilir
                                    onPressed: (_audioFilePath != null && isStopped) // state değişkeni
                                               ? _openRecordedFile // _openRecordedFile metodu
                                               : null, // (255 * 0.3).round() -> 77
                                     disabledColor: onSurfaceColor.withAlpha(77),
                                     iconSize: 28,
                                  ),
                                 // Play existing audio if editing and no new audio recorded
                                 if (_isEditing && _editingAudioUrl != null && _audioFilePath == null && isStopped)
                                   IconButton(
                                     icon: const Icon(Icons.play_arrow, color: Colors.black),
                                     tooltip: 'Mevcut Sesi Çal',
                                     onPressed: () => _playAudioFromUrl(_editingAudioUrl),
                                     iconSize: 28,
                                   ),
                                 IconButton( // Mevcut Play Recorded File Button, biraz sağa kaydırıldı
                                   icon: const Icon(Icons.play_circle_fill_outlined, color: Colors.black),
                                   tooltip: 'Kaydedilen Sesi Çal',
                                   // Sadece kayıt durdurulmuşsa ve dosya yolu varsa çalabilir
                                   onPressed: (_audioFilePath != null && isStopped) // state değişkeni
                                              ? _openRecordedFile // _openRecordedFile metodu
                                              : null, // (255 * 0.3).round() -> 77
                                    disabledColor: onSurfaceColor.withAlpha(77),
                                      iconSize: 28,
                                  ),
                                // Recording Status and Amplitude Indicator
                                AnimatedOpacity(
                                   opacity: (isRecording || isPaused) ? 1.0 : 0.0,
                                   duration: const Duration(milliseconds: 300),
                                    child: (isRecording || isPaused) ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                           isRecording ? Icons.fiber_manual_record : Icons.pause_circle_filled,
                                           color: isRecording ? Colors.redAccent : Colors.orangeAccent,
                                           size: 18
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible( // Metni Flexible ile sarmala
                                          child: Text(isRecording ? "Kayıt yapılıyor..." : "Kayıt duraklatıldı",
                                               style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis),
                                        ), // context kullanımı
                                        if (_amplitude != null && isRecording) ...[ // state değişkeni
                                           const SizedBox(width: 16),
                                           ClipRRect(
                                             borderRadius: BorderRadius.circular(8),
                                             child: SizedBox(
                                                 width: 80,
                                                 height: 6,
                                                 child: LinearProgressIndicator(
                                                     value: ((_amplitude!.current + 60) / 60).clamp(0.0, 1.0), // state değişkeni
                                                     backgroundColor: Colors.grey.shade300,
                                                     valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                                                 ),
                                             ),
                                           ),
                                        ]
                                      ],
                                    ) : const SizedBox.shrink(),
                                 ),
                             ],
                           ),
                         ),
                         const Divider(height: 1),
                         // Başlık TextField
                         TextField(
                           controller: _titleController, // controller kullanımı
                           decoration: InputDecoration(
                             hintText: 'Başlık',
                             border: InputBorder.none,
                             contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
                              isDense: true,
                             hintStyle: currentTextFieldTextStyle.copyWith(
                               fontWeight: FontWeight.bold,
                               // Arka plan rengine göre hint rengi ayarı
                               color: _backgroundColor.computeLuminance() > 0.5 ? Colors.black54 : Colors.white70, // state değişkeni
                             ),
                           ),
                           style: currentTextFieldTextStyle.copyWith(
                               fontSize: _fontSize + 4, // state değişkeni (Başlık daha büyük)
                               fontWeight: FontWeight.bold
                           ),
                           textCapitalization: TextCapitalization.sentences,
                         ),
                         const SizedBox(height: 4),
                         // Resim Önizleme Alanı (Başlığın altına taşındı)
                         if (_selectedImageFile != null)
                           Padding(
                             padding: const EdgeInsets.symmetric(vertical: 8.0),
                             child: Stack(
                               alignment: Alignment.topRight,
                               children: [
                                 Image.file(
                                   _selectedImageFile!,
                                   height: 150,
                                   width: double.infinity,
                                   fit: BoxFit.cover,
                                 ),
                                 IconButton(
                                   icon: const Icon(Icons.cancel, color: Colors.white70, shadows: [Shadow(color: Colors.black54, blurRadius: 2.0)]),
                                   onPressed: () {
                                     setState(() {
                                       _selectedImageFile = null;
                                     });
                                   },
                                 ),
                               ],
                             ),
                           )
                         else if (_editingImageUrl != null)
                            Padding(
                             padding: const EdgeInsets.symmetric(vertical: 8.0),
                             child: Image.network( // Backend'den gelen URL ile resmi göster
                               _editingImageUrl!,
                               height: 150,
                               width: double.infinity,
                               fit: BoxFit.cover,
                               errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                             ),
                           ),
                         // İçerik TextField
                         TextField(
                           controller: _contentController, // controller kullanımı
                           decoration: InputDecoration(
                             hintText: 'Düşüncelerinizi yazın...',
                             border: InputBorder.none,
                             contentPadding: EdgeInsets.zero,
                              isDense: true,
                              hintStyle: currentTextFieldTextStyle.copyWith(
                                 // Arka plan rengine göre hint rengi ayarı
                                 color: _backgroundColor.computeLuminance() > 0.5 ? Colors.black54 : Colors.white70, // state değişkeni
                              )
                           ),
                           maxLines: null, // Otomatik satır sayısı
                           keyboardType: TextInputType.multiline,
                           style: currentTextFieldTextStyle,
                            textCapitalization: TextCapitalization.sentences,
                         ),
                       ],
                     ),
                   ),
                 ),
                 const SizedBox(height: 20),
                 Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                   child: Text('Kaydedilmiş Günlükler', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), // context kullanımı
                 ),
                 const Divider(height: 1),
                 Expanded(
                   flex: 1, // Kaydedilmiş günlükler listesinin esnekçe büyümesini sağla
                   child: _journalEntries.isEmpty // state değişkeni
                       ? Center(
                           child: Text('Henüz kaydedilmiş bir günlük yok.',
                               style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600])),
                         )
                       : ListView.builder(
                           itemCount: _journalEntries.length, // state değişkeni
                           itemBuilder: (context, index) { // context parametresi
                             final entryMap = _journalEntries[index]; // Artık Map
                             final JournalEntry entry = JournalEntry.fromMap(entryMap); // JournalEntry nesnesi oluştur
                             // JournalEntry nesnesinden değerleri al
                             final String title = entry.title;
                             final String content = entry.content;
                             final String? audioUrl = entry.audioUrl; // Bu da tam URL'ye çevrilebilir
                             final String? displayImageUrl = entry.fullImageUrl; // Tam URL'yi kullan
                             final DateTime createdAt = entry.createdAt; // JournalEntry nesnesinden createdAt değerini al

                             final entryTextStyle = TextStyle(
                               color: _backgroundColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                               fontSize: 16.0, // Varsayılan
                             );

                             // ignore: prefer_typing_uninitialized_variables
                             return Card( // createdAt değişkeni artık yukarıda tanımlandı ve kullanılıyor
                               elevation: 3.0,
                               margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                               clipBehavior: Clip.antiAlias, // İçeriğin kartın kenarlarını kesmesini sağlar
                               child: Container(
                                  color: _backgroundColor, 
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                    title: Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                       style: entryTextStyle.copyWith(fontWeight: FontWeight.bold, fontSize: entryTextStyle.fontSize! * 1.1),
                                    ),
                                    subtitle: Column(
                                       crossAxisAlignment: CrossAxisAlignment.start,
                                       children: [
                                         if (displayImageUrl != null)
                                           Padding(
                                             padding: const EdgeInsets.only(top: 4.0, bottom: 6.0),
                                             child: Image.network(
                                               displayImageUrl, // Güncellenmiş URL
                                               height: 100,
                                               width: double.infinity,
                                               fit: BoxFit.cover,
                                               errorBuilder: (context, error, stackTrace) => 
                                                 Text('[Resim yüklenemedi]', style: entryTextStyle.copyWith(fontSize: 12, fontStyle: FontStyle.italic)),
                                             ),
                                           ),
                                         const SizedBox(height: 4),
                                         // Text widget'ı yerine Html widget'ını kullan
                                         if (content.isNotEmpty)
                                           Html(
                                             data: content, // HTML içeriğini buraya ver
                                             style: { // İsteğe bağlı: HTML elemanları için varsayılan stiller
                                               "body": Style( // Köşeli parantez hatası düzeltildi
                                                 fontSize: FontSize(entryTextStyle.fontSize! * 0.9),
                                                 color: entryTextStyle.color,
                                                 margin: Margins.zero, // Html widget'ının kendi margin'ini sıfırla
                                                 padding: HtmlPaddings.zero, // Html widget'ının kendi padding'ini sıfırla
                                               ),
                                             },
                                           )
                                         // Eğer content boşsa ama medya varsa '[Medya İçeriği]' göster
                                         else if (content.isEmpty && (audioUrl != null || displayImageUrl != null))
                                           Text('[Medya İçeriği]', style: entryTextStyle.copyWith(fontSize: entryTextStyle.fontSize! * 0.9))
                                         // Eğer content de boşsa ve medya da yoksa 'İçerik Yok' göster
                                         else
                                           Text('İçerik Yok', style: entryTextStyle.copyWith(fontSize: entryTextStyle.fontSize! * 0.9)),
                                         const SizedBox(height: 8),
                                         Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                               // Tarih ve Saat gösterimi (Format isteğe bağlı olarak ayarlanabilir)
                                               Text(
                                                  // DateFormat('yyyy-MM-dd HH:mm').format(createdAt.toLocal()), // Örnek format
                                                  '${createdAt.toLocal().year}-${createdAt.toLocal().month.toString().padLeft(2, '0')}-${createdAt.toLocal().day.toString().padLeft(2, '0')} ${createdAt.toLocal().hour.toString().padLeft(2, '0')}:${createdAt.toLocal().minute.toString().padLeft(2, '0')}',
                                                  style: entryTextStyle.copyWith(
                                                    fontSize: entryTextStyle.fontSize! * 0.8, // (255 * 0.7).round() -> 179
                                                    color: entryTextStyle.color?.withAlpha(179),
                                                 ),
                                               ),
                                               if (audioUrl != null)
                                                 GestureDetector(
                                                   onTap: () => _playAudioFromUrl(audioUrl), // _playAudioFromUrl metodu
                                                   child: const Tooltip(
                                                      message: 'Ses Kaydını Dinle', // entryTextStyle.color?.withAlpha(204) olarak basitleştirilebilir
                                                      child: Icon(Icons.volume_up, size: 20, color: Colors.blueAccent),
                                                   ),
                                                 ),
                                            ],
                                         ),
                                       ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, color: Colors.black),
                                          tooltip: 'Düzenle',
                                          onPressed: () => _editJournalEntry(entryMap), // _editJournalEntry metodu
                                          // color: colorScheme.primary, // Kaldırıldı
                                           visualDensity: VisualDensity.compact,
                                           padding: const EdgeInsets.all(8),
                                           constraints: const BoxConstraints(),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent), // Silme ikonu kırmızı kalabilir
                                          tooltip: 'Sil',
                                          onPressed: () => _deleteJournalEntry(entryMap['id'] as int), // _deleteJournalEntry metodu
                                           // color: Colors.redAccent, // Zaten ikon içinde belirtildi
                                           visualDensity: VisualDensity.compact,
                                           padding: const EdgeInsets.all(8),
                                           constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                  ),
                               ),
                             );
                           },
                         ),
                 ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showImageSourceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Resim Kaynağı Seçin'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galeri'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Kamera'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Renk Seçici Dialog (Color Picker Dialog)
    // Renk Seçici Dialog (Color Picker Dialog)
  void _showColorPicker({required bool isBackground}) { // context kullanımı showDialog içinde
      List<Color> colors = isBackground
      ? [
          Colors.white, Colors.grey.shade100, Colors.blueGrey.shade50,
          Colors.yellow.shade100, Colors.lightGreen.shade100, Colors.red.shade100,
          Colors.lightBlue.shade100, Colors.purple.shade100, Colors.orange.shade100,
          Colors.pink.shade100, Colors.teal.shade100, Colors.cyan.shade100,
          Colors.amber.shade100, Colors.lime.shade100, Colors.indigo.shade100,
          Colors.brown.shade100,
           Colors.blue.shade50, Colors.green.shade50,
           Colors.deepOrange.shade50, Colors.tealAccent.shade100,
           Colors.white70, // Yarı saydam beyaz
           Colors.black12, // Çok hafif siyah (koyu modda kullanılabilir)
        ]
      : [ // Yazı renkleri (genellikle koyu veya parlak)
          Colors.black87, Colors.grey.shade900, Colors.blueGrey.shade900,
          Colors.blue.shade900, Colors.green.shade900, Colors.red.shade900,
          Colors.purple.shade900, Colors.orange.shade900, Colors.pink.shade900,
          Colors.teal.shade900, Colors.cyan.shade900, Colors.indigo.shade900,
          Colors.brown.shade900, Colors.amber.shade900, Colors.lime.shade900,
          Colors.white, Colors.white70, // Beyaz ve yarı saydam beyaz
           Colors.blueAccent.shade700, Colors.greenAccent.shade700, Colors.redAccent.shade700,
           Colors.deepOrange.shade900, Colors.tealAccent.shade700, Colors.purpleAccent.shade700,
           Colors.deepPurple.shade900,
        ];

    Color currentColor = isBackground ? _backgroundColor : _textColor; // state değişkenleri

    showDialog(
      context: context, // context kullanımı
      builder: (context) { // context parametresi
        return AlertDialog(
          title: Text(isBackground ? 'Arka Plan Rengi Seç' : 'Yazı Rengi Seç'),
          contentPadding: const EdgeInsets.all(12.0),
          content: SingleChildScrollView(
            child: Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: colors.map((color) {
                 // İkon rengi hesabını buraya, Icon widget'ından önce taşıdık
                 Color iconColor = color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white; // <<< Hesaplama buraya taşındı

                 // ARGB32 değerini kullanarak renk eşitliğini kontrol et (daha güvenli)
                 bool isSelected = color.toARGB32() == currentColor.toARGB32();

                 return GestureDetector(
                    onTap: () {
                      if (isBackground) {
                        _changeBackgroundColor(color); // Arka plan rengi seçildiğinde bu çağrılır
                      } else {
                        _changeTextColor(color); // Yazı rengi seçildiğinde bu çağrılır
                      }
                      // Dialogu kapat
                      Navigator.pop(context); // context kullanımı
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        border: Border.all(
                           // Seçili rengin parlaklığına göre kenarlık rengini ayarla (varsa)
                           color: isSelected
                                  ? Theme.of(context).primaryColor // Seçiliyse tema primary rengi
                                  : color.computeLuminance() > 0.8 ? Colors.grey.shade400 : Colors.transparent, // Değilse parlaklığa göre
                           width: isSelected ? 2.5 : 1.0, // Seçiliyse kalınlaştır
                        ),
                        shape: BoxShape.circle,
                        boxShadow: const [
                            BoxShadow( // BoxShadow çağrısının başına 'const' eklendi
                            color: Color(0x26000000),
                            spreadRadius: 1,
                            blurRadius: 3,
                            offset: Offset(0, 1),
                          )
                        ]
                      ),
                       child: isSelected
                           ? Icon(Icons.check,
                                  // Burada hesaplanmış yerel değişkeni kullanıyoruz
                                  color: iconColor, // <<< Yerel değişken kullanılıyor
                                  size: 24)
                           : null,
                    ),
                  );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // context kullanımı
              child: const Text('İptal'),
            )
          ],
           actionsPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        );
      },
    );
  }


    Future<void> _playAudioFromUrl(String? audioUrl) async {
     if (audioUrl == null || audioUrl.isEmpty) return;
     if (_recordState != RecordState.stop) { // state değişkeni
        if (!mounted) return; // mounted kontrolü
        ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Lütfen kaydı durdurun veya tamamlayın.')),
       );
        return;
     }
     final file = File(audioUrl); // Hata düzeltildi: audioPath -> audioUrl
       if (await file.exists()) {
         try {
          // Eğer audioUrl bir lokal dosya yolu ise (örn: daha önce indirilmişse)
          // veya OpenFile.open() URL'leri de açabiliyorsa (genellikle açamaz)
          // Bu kısım, backend'den gelen URL'nin nasıl işleneceğine bağlı olarak değişir.
          // Genellikle bir ses URL'sini oynatmak için `audioplayers` gibi bir paket kullanılır.
          // `OpenFile.open` genellikle lokal dosyalar içindir.
          // Şimdilik, `OpenFile.open`'ın URL'leri de açabildiğini varsayalım (basitlik adına)
          // veya bu URL'nin aslında bir lokal dosya yolu olduğunu.
          // İDEAL ÇÖZÜM: `audioplayers` paketi ile URL'den stream etmek.
          if (!mounted) return;
          final result = await OpenFile.open(audioUrl); // Bu satır URL için çalışmayabilir.
          debugPrint('OpenFile result: ${result.type} ${result.message}');
          if (!mounted) return;
          if (result.type != ResultType.done) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ses dosyası açılamadı: ${result.message}')));
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ses dosyası açılırken hata: ${e.toString()}')));
        }
       } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ses dosyası bulunamadı veya URL geçersiz.')));
       }
  }

}
