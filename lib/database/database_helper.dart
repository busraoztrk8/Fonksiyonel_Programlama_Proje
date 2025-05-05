import 'dart:async';
import 'package:sqflite/sqflite.dart'; // sqflite paketi
import 'package:path/path.dart';
// import '../models/journal_entry.dart'; // JournalEntry modelini import edin

// JournalEntry'nin tam yolunu belirtelim, import sorunu yaşamamak için
// Ancak JournalEntry, DatabaseHelper'ı kullanıyor. Bu bir döngü yaratabilir.
// Genellikle model veritabanını bilmez, veritabanı modeli bilir.
// JournalEntry'yi burada doğrudan kullanmak yerine, toMap ve fromMap
// mantığını modelde bırakıp burada sadece Map'lerle çalışmak daha iyidir.
// Veya, model importu gerekiyorsa döngüden kaçınmak için dikkatli olunmalı.
// Şimdilik importu kaldırıp Map'ler üzerinden JournalEntry oluşturalım/güncelleyelim.

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String documentsPath = await getDatabasesPath(); // sqflite'den gelir
    String path = join(documentsPath, 'journal_database.db');

    return await openDatabase( // sqflite'den gelir
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade, // Eğer versiyon artarsa burası çalışır
    );
  }

  FutureOr<void> _onCreate(Database db, int version) async { // sqflite'den gelir
    await db.execute(
      // style sütunu TEXT olarak JSON string saklayacak
      'CREATE TABLE journals(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, content TEXT, createdAt TEXT, audioPath TEXT, style TEXT)',
    );
  }

  FutureOr<void> _onUpgrade(Database db, int oldVersion, int newVersion) async { // sqflite'den gelir
     // Veritabanı şemasında gelecekte değişiklik olursa buraya eklenecek
     // Örneğin, yeni bir sütun eklemek gibi
     if (oldVersion < 2) {
        // await db.execute('ALTER TABLE journals ADD COLUMN newColumn TEXT;');
     }
  }


  // Yeni günlük girdisi ekleme veya güncelleme (replace strategy)
  // JournalEntry nesnesi alıp Map'e dönüştürür
  Future<int> insertJournal(Map<String, dynamic> entryMap) async {
    final db = await database;
    // JournalEntry toMap metodu, id null ise yeni kayıt ekler
    return await db.insert('journals', entryMap, conflictAlgorithm: ConflictAlgorithm.replace); // ConflictAlgorithm sqflite'den gelir
  }

   // Bir günlük girdisini güncelleme (sadece belirli id'yi günceller)
  Future<int> updateJournal(Map<String, dynamic> entryMap) async {
     final db = await database;
     final int? id = entryMap['id'] as int?;
     if (id == null) {
       throw Exception("Güncellenecek girdinin ID'si olmalı.");
     }
     return await db.update(
       'journals',
       entryMap,
       where: 'id = ?',
       whereArgs: [id],
     );
   }


  // Tüm günlük girdilerini getirme (tarihe göre tersten sıralı)
  // Map listesi döndürüp journal_screen'da JournalEntry'ye dönüştürelim
  Future<List<Map<String, dynamic>>> getJournalsMaps() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('journals', orderBy: 'createdAt DESC');
    return maps;
  }

  // Bir günlük girdisini silme
  Future<int> deleteJournal(int id) async {
    final db = await database;
    return await db.delete(
      'journals',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Veritabanını kapatma
  Future<void> close() async {
    final db = await database;
    db.close(); // Singleton olduğu için uygulamada kapatmaya gerek kalmaz genelde
  }
}