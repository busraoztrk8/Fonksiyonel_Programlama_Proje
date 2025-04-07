import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  DateTime _selectedDate = DateTime.now();
  final Map<DateTime, List<String>> _events = {};

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  void _initializeNotifications() {
    tz.initializeTimeZones(); // Timezone verilerini başlat
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    _notificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _scheduleNotification(DateTime date, String event) async {
    const androidDetails = AndroidNotificationDetails(
      'reminder_channel',
      'Reminders',
      channelDescription: 'Channel for event reminders',
      importance: Importance.high,
      priority: Priority.high,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.zonedSchedule(
      0,
      'Hatırlatma',
      event,
      tz.TZDateTime.from(date, tz.local), // DateTime -> TZDateTime dönüşümü
      notificationDetails,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  void _addEvent(String eventText) {
    if (eventText.isEmpty) return;

    setState(() {
      if (_events[_selectedDate] != null) {
        _events[_selectedDate]!.add(eventText);
      } else {
        _events[_selectedDate] = [eventText];
      }
    });

    // Bildirim planlama
    _scheduleNotification(_selectedDate, eventText);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      body: Column(
        children: [
          // Takvim
          TableCalendar(
            focusedDay: _selectedDate,
            firstDay: DateTime(2000),
            lastDay: DateTime(2100),
            calendarFormat: CalendarFormat.month,
            selectedDayPredicate: (day) => isSameDay(day, _selectedDate),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDate = selectedDay;
              });
            },
            calendarStyle: const CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.purple,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Etkinlik Listesi
          Expanded(
            child: ListView(
              children: _events[_selectedDate]?.map((event) {
                    return ListTile(
                      title: Text(event),
                    );
                  }).toList() ??
                  [const Center(child: Text('Bugün için bir not yok.'))],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final TextEditingController eventController =
              TextEditingController(); // Yeni bir controller oluştur
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Yeni Not Ekle'),
              content: TextField(
                controller: eventController,
                decoration: const InputDecoration(hintText: 'Notunuzu yazın'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('İptal'),
                ),
                TextButton(
                  onPressed: () {
                    _addEvent(eventController.text);
                    eventController.dispose(); // Controller'ı temizle
                    Navigator.of(context).pop();
                  },
                  child: const Text('Kaydet'),
                ),
              ],
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}