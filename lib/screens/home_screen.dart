import 'package:flutter/material.dart';
import 'package:gunluk/screens/pomodoro_screen.dart';
import 'package:gunluk/screens/planner_screen.dart';
import 'dart:math';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0; // Alt navigasyon çubuğu için seçili sekme
  bool _isDarkMode = true; // Varsayılan olarak karanlık mod
  Color _selectedColor = Colors.blue; // Varsayılan tema rengi
  String _userName = "Kullanıcı"; // Kullanıcının adı
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _todoController = TextEditingController();
  final TextEditingController _editTodoController = TextEditingController();

  // Haftalık yapılacaklar listesi
  final Map<String, List<Map<String, dynamic>>> _weeklyTodoList = {
    'Pazartesi': [],
    'Salı': [],
    'Çarşamba': [],
    'Perşembe': [],
    'Cuma': [],
    'Cumartesi': [],
    'Pazar': [],
  };
String _selectedDay = 'Pazartesi';


  // Haftalık duygu tablosu
  final Map<String, String> _weeklyMoodTable = {
    'Pazartesi': '😊',
    'Salı': '😊',
    'Çarşamba': '😊',
    'Perşembe': '😊',
    'Cuma': '😊',
    'Cumartesi': '😊',
    'Pazar': '😊',
  };

  // Günlük motivasyon yazıları
  final List<String> _dailyMotivations = [
    "Bugün harika bir gün olacak!",
    "Kendine inan, her şey mümkün!",
    "Başarı, küçük adımlarla gelir.",
    "Hayallerine ulaşmak için çalışmaya devam et.",
    "Her yeni gün, yeni bir başlangıçtır.",
    "Küçük şeylerden mutlu olmayı öğren.",
    "Bugün, en iyi versiyonun ol!"
  ];

  String _getDailyMotivation() {
    final int dayOfWeek = DateTime.now().weekday - 1; // Haftanın günü (0 = Pazartesi)
    return _dailyMotivations[dayOfWeek];
  }


  final List<Widget> _pages = [
    const HomeContent(),
    const PlannerScreen(),
    const PomodoroScreen(),
    const JournalListScreen(),
    const SettingsScreen(),
  ];

  bool _showWelcomeText = false; // Hoş geldin yazısı animasyonu için
  final List<Widget> _hearts = []; // Kalp animasyonu için

  @override
  void initState() {
    super.initState();
    _startWelcomeAnimation();
    _startHeartAnimation();
  }

  @override
  void dispose() {
    _todoController.dispose();
    _nameController.dispose();
    _editTodoController.dispose();
    super.dispose();
  }

  void _startWelcomeAnimation() {
    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        _showWelcomeText = true;
      });
    });
  }

  void _startHeartAnimation() {
    Future.delayed(const Duration(milliseconds: 300), () {
      for (int i = 0; i < 10; i++) {
        Future.delayed(Duration(milliseconds: i * 300), () {
          setState(() {
            _hearts.add(_buildHeart());
          });
        });
      }
    });
  }

  Widget _buildHeart() {
    final random = Random();
    final left = random.nextDouble() * MediaQuery.of(context).size.width;
    final size = random.nextInt(30) + 20.0;

    return Positioned(
      bottom: 0,
      left: left,
      child: AnimatedOpacity(
        opacity: 0,
        duration: const Duration(seconds: 3),
        child: Icon(
          Icons.favorite,
          color: Colors.red,
          size: size,
        ),
        onEnd: () {
          setState(() {
            _hearts.removeAt(0);
          });
        },
      ),
    );
  }

  void _changeUserName() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Kullanıcı Adını Değiştir'),
          content: TextField(
            controller: _nameController,
            decoration: const InputDecoration(hintText: 'Yeni kullanıcı adı'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _userName = _nameController.text.isNotEmpty
                      ? _nameController.text
                      : _userName;
                });
                Navigator.of(context).pop();
              },
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );
  }

  void _changeBackgroundColor() {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Arka Plan Rengini Seç'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.blue),
                title: const Text('Mavi'),
                onTap: () {
                  setState(() {
                    _selectedColor = Colors.blue;
                  });
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.green),
                title: const Text('Yeşil'),
                onTap: () {
                  setState(() {
                    _selectedColor = Colors.green;
                  });
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.red),
                title: const Text('Kırmızı'),
                onTap: () {
                  setState(() {
                    _selectedColor = Colors.red;
                  });
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.orange),
                title: const Text('Turuncu'),
                onTap: () {
                  setState(() {
                    _selectedColor = Colors.orange;
                  });
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.purple),
                title: const Text('Mor'),
                onTap: () {
                  setState(() {
                    _selectedColor = Colors.purple;
                  });
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.yellow),
                title: const Text('Sarı'),
                onTap: () {
                  setState(() {
                    _selectedColor = Colors.yellow;
                  });
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.pink),
                title: const Text('Pembe'),
                onTap: () {
                  setState(() {
                    _selectedColor = Colors.pink;
                  });
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.teal),
                title: const Text('Camgöbeği'),
                onTap: () {
                  setState(() {
                    _selectedColor = Colors.teal;
                  });
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.cyan),
                title: const Text('Açık Mavi'),
                onTap: () {
                  setState(() {
                    _selectedColor = Colors.cyan;
                  });
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.brown),
                title: const Text('Kahverengi'),
                onTap: () {
                  setState(() {
                    _selectedColor = Colors.brown;
                  });
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.grey),
                title: const Text('Gri'),
                onTap: () {
                  setState(() {
                    _selectedColor = Colors.grey;
                  });
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.indigo),
                title: const Text('Çivit Mavisi'),
                onTap: () {
                  setState(() {
                    _selectedColor = Colors.indigo;
                  });
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.lime),
                title: const Text('Açık Yeşil'),
                onTap: () {
                  setState(() {
                    _selectedColor = Colors.lime;
                  });
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.amber),
                title: const Text('Kehribar'),
                onTap: () {
                  setState(() {
                    _selectedColor = Colors.amber;
                  });
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.deepOrange),
                title: const Text('Koyu Turuncu'),
                onTap: () {
                  setState(() {
                    _selectedColor = Colors.deepOrange;
                  });
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

  void _addTodoItem() {
    if (_todoController.text.isNotEmpty) {
      setState(() {
        _weeklyTodoList[_selectedDay]!.add({
          'task': _todoController.text,
          'isCompleted': false,
        });
      });
      _todoController.clear();
      Navigator.of(context).pop();
    }
  }

void _editTodoItem(String day, int index) {
    _editTodoController.text = _weeklyTodoList[day]![index]['task'];
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Görevi Düzenle'),
          content: TextField(
            controller: _editTodoController,
            decoration: const InputDecoration(hintText: 'Görev Girin'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _weeklyTodoList[day]![index]['task'] =
                      _editTodoController.text;
                });
                Navigator.of(context).pop();
              },
              child: const Text('Kaydet'),
            ),
          ],
      );
      },
    );
  }

  
     void _showAddTodoDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Yeni Yapılacak Ekle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedDay,
                items: _weeklyTodoList.keys
                    .map((day) => DropdownMenuItem(
                          value: day,
                          child: Text(day),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedDay = value;
                    });
                  }
                },
                decoration: const InputDecoration(labelText: 'Gün Seçin'),
              ),
               TextField(
                controller: _todoController,
                decoration: const InputDecoration(hintText: 'Görev Girin'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: _addTodoItem,
              child: const Text('Ekle'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        brightness: _isDarkMode ? Brightness.dark : Brightness.light,
        primaryColor: _selectedColor,
        scaffoldBackgroundColor: _isDarkMode ? Colors.black : Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: _selectedColor,
          foregroundColor: _isDarkMode ? Colors.white : Colors.black,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          selectedItemColor: _selectedColor,
          unselectedItemColor: _isDarkMode ? Colors.white70 : Colors.black54,
        ),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('WhispDiary'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(_isDarkMode ? Icons.dark_mode : Icons.light_mode),
              onPressed: () {
                setState(() {
                  _isDarkMode = !_isDarkMode;
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.color_lens),
              onPressed: _changeBackgroundColor,
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _changeUserName,
            ),
          ],
        ),
        body: Stack(
          children: [
            _selectedIndex == 0
                ? SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedPositioned(
                            duration: const Duration(seconds: 1),
                            top: _showWelcomeText ? 0 : 50,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Text(
                                'Hoş Geldin, $_userName!',
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Haftalık Duygu Tablosu',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Table(
                            border: TableBorder.all(color: Colors.grey),
                            children: _weeklyMoodTable.keys.map((day) {
                              return TableRow(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(day),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: DropdownButton<String>(
                                      value: _weeklyMoodTable[day],
                                      items: ['😊', '😢', '😡', '😴', '😎']
                                          .map((mood) => DropdownMenuItem(
                                                value: mood,
                                                child: Text(mood),
                                              ))
                                          .toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(() {
                                            _weeklyMoodTable[day] = value;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Haftalık Yapılacaklar Listesi',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: const BoxDecoration(
                              border: Border(
                                left: BorderSide(
                                    color: Colors.blue, width: 5.0),
                                right: BorderSide(
                                    color: Colors.green, width: 5.0),
                              ),
                            ),
                            child: Column(
                              children: _weeklyTodoList.keys.map((day) {
                                return ExpansionTile(
                                  title: Text(day),
                                  children: _weeklyTodoList[day]!.isEmpty
                                      ? [
                                          const Padding(
                                            padding: EdgeInsets.all(8.0),
                                            child: Text(
                                                'Henüz bir görev eklenmedi.'),
                                          )
                                        ]
                                      : _weeklyTodoList[day]!
                                          .asMap()
                                          .entries
                                          .map((entry) {
                                          int index = entry.key;
                                          Map<String, dynamic> todo =
                                              entry.value;
                                          return ListTile(
                                            title: Text(
                                              todo['task'],
                                              style: TextStyle(
                                                decoration: todo['isCompleted']
                                                    ? TextDecoration.lineThrough
                                                    : TextDecoration.none,
                                              ),
                                            ),
                                            leading: IconButton(
                                              icon: Icon(
                                                todo['isCompleted']
                                                    ? Icons.check_circle
                                                    : Icons
                                                        .radio_button_unchecked,
                                                color: todo['isCompleted']
                                                    ? Colors.green
                                                    : Colors.grey,
                                              ),
                                              onPressed: () => setState(() {
                                                _weeklyTodoList[day]![index]
                                                        ['isCompleted'] =
                                                    !_weeklyTodoList[day]![index]
                                                        ['isCompleted'];
                                              }),
                                            ),
                                            trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editTodoItem(day, index),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => setState(() {
                                _weeklyTodoList[day]!.removeAt(index);
                              }),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
             );
                              }).toList(),
                            ),
                            
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: ElevatedButton.icon(
                              onPressed: _showAddTodoDialog,
                              icon: const Icon(Icons.add),
                              label: const Text('Yeni Yapılacak Ekle'),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          Text(
                            'Günlük Motivasyon: ${_getDailyMotivation()}',
                            style: const TextStyle(
                                fontSize: 16, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                  )
                : _pages[_selectedIndex],
            ..._hearts,
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Anasayfa',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today),
              label: 'Takvim',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.timer),
              label: 'Pomodoro',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.book),
              label: 'Günlüklerim',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Ayarlar',
            ),
          ],
        ),
      ),
    );
  }
}

class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Anasayfa İçeriği'),
    );
  }
}

class JournalListScreen extends StatelessWidget {
  const JournalListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Günlüklerim Ekranı'),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Ayarlar Ekranı'),
    );
  }
}