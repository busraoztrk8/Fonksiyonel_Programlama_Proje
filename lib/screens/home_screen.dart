import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Örnek günlük girişleri listesi (ileride veritabanından alınacak)
  final List<String> _entries = ["HOŞ GELDİNİZ", "SİTEMİZE"]; // final yapıldı
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Günlüğüm'),
        actions: [
          // Ayarlar butonu (isteğe bağlı)
          IconButton(
            onPressed: () {
              // Ayarlar sayfasına yönlendirme (örnek)
              // Navigator.push(context, MaterialPageRoute(builder: (context) => SettingsScreen()));
            },
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: _entries.isEmpty
          ? const Center(
              child: Text('Henüz günlük girişi yok.'),
            )
          : ListView.builder(
              itemCount: _entries.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_entries[index]),
                  subtitle: Text('Tarih: ${DateTime.now().toLocal()}'), // Örnek tarih
                  // Diğer ListTile özellikleri (örneğin, onTap)
                  onTap: () {
                    // Günlük detay sayfasına yönlendirme (örnek)
                    // Navigator.push(context, MaterialPageRoute(builder: (context) => EntryDetailScreen(entry: _entries[index])));
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Yeni günlük girişi ekleme sayfası (örnek)
          // Navigator.push(context, MaterialPageRoute(builder: (context) => AddEntryScreen()));

          // Örnek: Yeni giriş ekleme (geçici olarak listeye ekliyoruz)
          setState(() {
             _entries.add("Yeni bir giriş eklendi. Düzenlemek için dokunun.");

          });
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}