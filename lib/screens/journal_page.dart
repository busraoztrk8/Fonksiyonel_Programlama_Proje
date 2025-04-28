import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

class JournalPage extends StatefulWidget {
  const JournalPage({super.key});

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<RecordState>? _recordSub;
  RecordState _recordState = RecordState.stop;
  StreamSubscription<Amplitude>? _amplitudeSub;
  Amplitude? _amplitude;

  String? _audioFilePath;

  Color _backgroundColor = Colors.white;
  double _fontSize = 16.0;
  String _selectedFont = 'Roboto';
  Color _textColor = Colors.black;
  bool _isBold = false;
  bool _isItalic = false;
  bool _isUnderlined = false;

  @override
  void initState() {
    super.initState();
    _recordSub = _recorder.onStateChanged().listen((recordState) {
      if (mounted) {
        setState(() => _recordState = recordState);
      }
      debugPrint("Record state changed: $recordState");
    });

    _amplitudeSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 300))
        .listen((amp) {
           if (mounted) {
              setState(() => _amplitude = amp);
           }
        });

    _checkPermissions();
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
       if (!mounted) return false;
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mikrofon izni reddedildi! Kayıt yapılamaz.')),
      );
    } else {
       debugPrint("Microphone permission granted.");
    }
    return status.isGranted;
  }

  void _changeBackgroundColor(Color color) {
    setState(() {
      _backgroundColor = color;
    });
  }

  void _changeFontSize(double size) {
    setState(() {
      _fontSize = size;
    });
  }

  void _changeFont(String font) {
    setState(() {
      _selectedFont = font;
    });
  }

  void _changeTextColor(Color color) {
    setState(() {
      _textColor = color;
    });
  }

  void _toggleBold() {
    setState(() {
      _isBold = !_isBold;
    });
  }

  void _toggleItalic() {
    setState(() {
      _isItalic = !_isItalic;
    });
  }

  void _toggleUnderline() {
    setState(() {
      _isUnderlined = !_isUnderlined;
    });
  }

 Future<void> _startRecording() async {
    debugPrint("Attempting to start recording...");
    if (!await _checkPermissions()) {
       debugPrint("Permission check failed before starting.");
       return;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
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

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kayıt başladı!')),
      );
    } catch (e, stackTrace) {
      debugPrint('Error starting recording: $e');
      debugPrint('Stack trace: $stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kayıt başlatılamadı: ${e.toString()}')),
      );
      if (mounted) {
        setState(() {
           _recordState = RecordState.stop;
           _audioFilePath = null;
        });
      }
    }
  }

  Future<void> _stopRecording() async {
    debugPrint("Attempting to stop recording...");
    if (_recordState == RecordState.record || _recordState == RecordState.pause) {
       try {
        final path = await _recorder.stop();
        debugPrint("Recorder stopped. Returned path: $path");
        if (!mounted) return;

        setState(() {
          _audioFilePath = path;
          // State listener should update _recordState to stop.
        });

        if (path != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ses kaydı tamamlandı! Kaydedildi: $path')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kayıt durduruldu ancak dosya yolu alınamadı.')),
          );
           if (mounted) {
              setState(() => _audioFilePath = null);
           }
        }
      } catch (e, stackTrace) {
        debugPrint('Error stopping recording: $e');
        debugPrint('Stack trace: $stackTrace');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kayıt durdurulamadı: ${e.toString()}')),
        );
         if (mounted) {
           setState(() {
             _recordState = RecordState.stop;
             _audioFilePath = null;
           });
         }
      }
    } else {
       debugPrint("Stop recording called but recorder state is already: $_recordState");
    }
  }

  Future<void> _pauseRecording() async {
    if (_recordState == RecordState.record) {
      try {
        debugPrint("Attempting to pause recording...");
        await _recorder.pause();
        debugPrint("Recording paused state triggered via API.");
        // State listener updates _recordState
      } catch (e) {
         debugPrint("Error pausing recording: $e");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Kayıt duraklatılamadı: ${e.toString()}')),
            );
          }
      }
    } else {
       debugPrint("Pause recording called but recorder state is: $_recordState");
    }
  }

  Future<void> _resumeRecording() async {
     if (_recordState == RecordState.pause) {
      try {
        debugPrint("Attempting to resume recording...");
        await _recorder.resume();
        debugPrint("Recording resumed state triggered via API.");
         // State listener updates _recordState
      } catch (e) {
         debugPrint("Error resuming recording: $e");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Kayda devam edilemedi: ${e.toString()}')),
            );
          }
      }
    } else {
       debugPrint("Resume recording called but recorder state is: $_recordState");
    }
  }


  Future<void> _openRecordedFile() async {
    if (_audioFilePath != null) {
       final file = File(_audioFilePath!);
       if (await file.exists()) {
         try {
          final result = await OpenFile.open(_audioFilePath!);
          debugPrint('OpenFile result: ${result.type} ${result.message}');
          if (!mounted) return;

          if (result.type != ResultType.done) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Dosya açılamadı: ${result.message}')),
            );
          }
        } catch (e) {
          debugPrint('Error opening file: $e');
          if (!mounted) return;
           ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Dosya açılırken hata oluştu: ${e.toString()}')),
            );
        }
       } else {
          debugPrint("Attempted to open file, but file doesn't exist at path: $_audioFilePath");
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ses dosyası bulunamadı (silinmiş olabilir)!')),
          );
       }
    } else {
      debugPrint("Attempted to open file, but _audioFilePath is null.");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce bir ses kaydı yapın veya kayıt yolu bulunamadı.')),
      );
    }
  }

  @override
  void dispose() {
    _recordSub?.cancel();
    _amplitudeSub?.cancel();
    _recorder.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  // --- Save Logic Placeholder ---
  Future<void> _saveJournalEntry() async {
    String title = _titleController.text;
    String content = _contentController.text;

    Map<String, dynamic> journalData = {
      'title': title,
      'content': content,
      'createdAt': DateTime.now().toIso8601String(),
      'audioPath': _audioFilePath,
      'style': {
        // FIX: Replace deprecated .value with .toARGB32()
        'backgroundColor': _backgroundColor.toARGB32(),
        'fontSize': _fontSize,
        'fontFamily': _selectedFont,
        // FIX: Replace deprecated .value with .toARGB32()
        'textColor': _textColor.toARGB32(),
        'isBold': _isBold,
        'isItalic': _isItalic,
        'isUnderlined': _isUnderlined,
      }
    };

    debugPrint('Kaydedilecek Veri: $journalData');

    await Future.delayed(const Duration(milliseconds: 500)); // Simulate saving

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Günlük kaydedildi! (Simülasyon)')),
    );
  }


  @override
  Widget build(BuildContext context) {
    final bool isRecording = _recordState == RecordState.record;
    final bool isPaused = _recordState == RecordState.pause;
    final bool isStopped = _recordState == RecordState.stop;

    final currentTextStyle = TextStyle(
      fontSize: _fontSize,
      fontFamily: _selectedFont == 'Roboto' ? null : _selectedFont,
      color: _textColor,
      fontWeight: _isBold ? FontWeight.bold : FontWeight.normal,
      fontStyle: _isItalic ? FontStyle.italic : FontStyle.normal,
      decoration: _isUnderlined ? TextDecoration.underline : TextDecoration.none,
      decorationColor: _textColor,
      decorationThickness: _isUnderlined ? 1.5 : 1.0,
    );

    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final Color onSurfaceColor = colorScheme.onSurface;
    final Color inactiveIconColor = onSurfaceColor.withAlpha((255 * 0.6).round());
    final Color activeIconHighlightColor = colorScheme.primary.withAlpha((255 * 0.12).round());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Günlük Oluştur'),
        backgroundColor: isRecording ? Colors.red.withAlpha((255 * 0.1).round()) : AppBarTheme.of(context).backgroundColor,
        elevation: isRecording ? 0 : AppBarTheme.of(context).elevation,
        actions: [
          // --- Recording Controls ---
          if (isStopped)
           IconButton(
            icon: const Icon(Icons.mic_none),
            tooltip: 'Kaydı Başlat',
            onPressed: _startRecording,
          ),
          if (isRecording)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.stop_circle_outlined),
                  tooltip: 'Kaydı Durdur',
                  onPressed: _stopRecording,
                  color: Colors.redAccent,
                ),
                 IconButton(
                  icon: const Icon(Icons.pause_circle_outline),
                  tooltip: 'Kaydı Duraklat',
                  onPressed: _pauseRecording,
                ),
              ],
            ),
          if (isPaused)
             Row(
               mainAxisSize: MainAxisSize.min,
              children: [
                 IconButton(
                  icon: const Icon(Icons.stop_circle_outlined),
                  tooltip: 'Kaydı Durdur',
                  onPressed: _stopRecording,
                  color: Colors.redAccent,
                ),
                IconButton(
                  icon: const Icon(Icons.play_circle_outline),
                  tooltip: 'Kayda Devam Et',
                  onPressed: _resumeRecording,
                  color: Colors.green,
                ),
              ],
            ),

          // --- Other Actions ---
          IconButton(
            icon: const Icon(Icons.folder_open_outlined),
            tooltip: 'Kaydedilen Sesi Aç',
            onPressed: (isStopped && _audioFilePath != null)
                       ? _openRecordedFile
                       : null,
             disabledColor: onSurfaceColor.withAlpha((255 * 0.3).round()),
          ),
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Günlüğü Kaydet',
            onPressed: _saveJournalEntry,
          ),
        ],
      ),
      body: Container(
        color: _backgroundColor,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
            child: Column(
              children: [
                // --- Toolbar ---
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                         DropdownButtonHideUnderline(
                           child: DropdownButton<String>(
                            value: _selectedFont,
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
                              if (value != null) _changeFont(value);
                            },
                               isDense: true,
                          ),
                         ),
                        const SizedBox(width: 12),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<double>(
                            value: _fontSize,
                            items: [12.0, 14.0, 16.0, 18.0, 20.0, 22.0, 24.0, 26.0, 28.0, 30.0]
                                .map((size) {
                              return DropdownMenuItem(
                                value: size,
                                child: Text('${size.toInt()}'),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) _changeFontSize(value);
                            },
                            isDense: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: Icon(Icons.format_color_text, color: _textColor),
                          tooltip: 'Yazı Rengi Seç',
                          onPressed: () => _showColorPicker(isBackground: false),
                           iconSize: 20,
                           padding: EdgeInsets.zero,
                           constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.format_bold),
                          tooltip: 'Kalın',
                          color: _isBold ? colorScheme.primary : inactiveIconColor,
                           style: IconButton.styleFrom(
                             backgroundColor: _isBold ? activeIconHighlightColor : Colors.transparent,
                           ),
                          onPressed: _toggleBold,
                           iconSize: 20,
                           padding: const EdgeInsets.all(8),
                           constraints: const BoxConstraints(),
                        ),
                         const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.format_italic),
                          tooltip: 'İtalik',
                          color: _isItalic ? colorScheme.primary : inactiveIconColor,
                           style: IconButton.styleFrom(
                             backgroundColor: _isItalic ? activeIconHighlightColor : Colors.transparent,
                          ),
                          onPressed: _toggleItalic,
                          iconSize: 20,
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                        ),
                         const SizedBox(width: 4),
                         IconButton(
                          icon: const Icon(Icons.format_underline),
                          tooltip: 'Altı Çizili',
                          color: _isUnderlined ? colorScheme.primary : inactiveIconColor,
                           style: IconButton.styleFrom(
                             backgroundColor: _isUnderlined ? activeIconHighlightColor : Colors.transparent,
                           ),
                          onPressed: _toggleUnderline,
                           iconSize: 20,
                           padding: const EdgeInsets.all(8),
                           constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: Icon(Icons.format_color_fill,
                                    color: _backgroundColor.computeLuminance() > 0.5 ? Colors.black54 : Colors.white70),
                          tooltip: 'Arka Plan Rengi Seç',
                           style: IconButton.styleFrom(
                             backgroundColor: _backgroundColor,
                             side: BorderSide(color: Colors.grey.shade400, width: 0.5),
                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                           ),
                          onPressed: () => _showColorPicker(isBackground: true),
                           iconSize: 20,
                           padding: const EdgeInsets.all(8),
                           constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),

                // --- Recording Status Indicator ---
                AnimatedOpacity(
                  opacity: (isRecording || isPaused) ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                   child: (isRecording || isPaused) ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                           isRecording ? Icons.fiber_manual_record : Icons.pause_circle_filled,
                           color: isRecording ? Colors.redAccent : Colors.orangeAccent,
                           size: 18
                        ),
                        const SizedBox(width: 8),
                        Text(isRecording ? "Kayıt yapılıyor..." : "Kayıt duraklatıldı",
                             style: Theme.of(context).textTheme.bodySmall),
                        if (_amplitude != null && isRecording) ...[
                           const SizedBox(width: 16),
                           ClipRRect(
                             borderRadius: BorderRadius.circular(8),
                             child: SizedBox(
                                 width: 80,
                                 height: 6,
                                 child: LinearProgressIndicator(
                                     value: ((_amplitude!.current + 60) / 60).clamp(0.0, 1.0),
                                     backgroundColor: Colors.grey.shade300,
                                     valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                                 ),
                             ),
                           ),
                        ]
                      ],
                    ),
                  ) : const SizedBox.shrink(),
                ),

                // --- Text Fields ---
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    hintText: 'Başlık',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 8.0),
                     isDense: true,
                    hintStyle: TextStyle(fontWeight: FontWeight.bold)
                  ),
                  style: currentTextStyle.copyWith(
                      fontSize: _fontSize + 4,
                      fontWeight: FontWeight.bold
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: TextField(
                    controller: _contentController,
                    decoration: const InputDecoration(
                      hintText: 'Düşüncelerinizi yazın...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                       isDense: true,
                    ),
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: currentTextStyle,
                     textCapitalization: TextCapitalization.sentences,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Renk Seçici Dialog (Color Picker Dialog)
  void _showColorPicker({required bool isBackground}) {
      List<Color> colors = isBackground
      ? [
          Colors.white, Colors.grey.shade100, Colors.blueGrey.shade50,
          Colors.yellow.shade50, Colors.lightGreen.shade50, Colors.red.shade50,
          Colors.lightBlue.shade50, Colors.purple.shade50, Colors.orange.shade50,
          Colors.pink.shade50, Colors.teal.shade50, Colors.cyan.shade50,
          Colors.amber.shade50, Colors.lime.shade50, Colors.indigo.shade50,
          Colors.brown.shade50,
        ]
      : [
          Colors.black, Colors.grey.shade800, Colors.blueGrey.shade800,
          Colors.blue.shade800, Colors.green.shade800, Colors.red.shade700,
          Colors.purple.shade700, Colors.orange.shade800, Colors.pink.shade700,
          Colors.teal.shade700, Colors.cyan.shade700, Colors.indigo.shade700,
          Colors.brown.shade700, Colors.amber.shade900, Colors.lime.shade900,
          Colors.white,
        ];

    Color currentColor = isBackground ? _backgroundColor : _textColor;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isBackground ? 'Arka Plan Rengi Seç' : 'Yazı Rengi Seç'),
          contentPadding: const EdgeInsets.all(12.0),
          content: SingleChildScrollView(
            child: Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: colors.map((color) {
                 bool isSelected = color == currentColor;
                 return GestureDetector(
                    onTap: () {
                      if (isBackground) {
                        _changeBackgroundColor(color);
                      } else {
                        _changeTextColor(color);
                      }
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        border: Border.all(
                          color: color.computeLuminance() > 0.8 ? Colors.grey.shade400 : Colors.transparent,
                          width: 1.0
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha((255 * 0.1).round()),
                            spreadRadius: 1,
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          )
                        ]
                      ),
                       child: isSelected
                           ? Icon(Icons.check,
                                  color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                                  size: 20)
                           : null,
                    ),
                  );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            )
          ],
           actionsPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        );
      },
    );
  }
}
//nbc