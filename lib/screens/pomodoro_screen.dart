import 'package:flutter/material.dart';
import 'dart:async';

// --- Constants for Colors and Styling ---
const Color _darkBgColor = Color(0xFF1E1E2C); // Arka plan rengi
const Color _lightTextColor = Colors.white70;
const Color _whiteTextColor = Colors.white;
const Color _accentColor = Color(0xFF6C63FF);
const Color _pauseColor = Colors.orangeAccent;

class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({super.key});

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen> {
  int _goalMinutes = 25; // Default pomodoro duration
  late int _totalDurationSeconds;
  late int _currentTimeSeconds;
  bool _isRunning = false;
  Timer? _timer;

  int _completedPomodoros = 0; // Pomodoro döngüsü takibi
  final int _pomodoroCycle = 4; // 4 pomodoro tamamlandığında uzun mola

  @override
  void initState() {
    super.initState();
    _totalDurationSeconds = _goalMinutes * 60;
    _currentTimeSeconds = _totalDurationSeconds;
  }

  void _toggleTimer() {
    if (_isRunning) {
      _stopTimer();
    } else {
      _startTimer();
    }
  }

  void _startTimer() {
    if (_isRunning || _currentTimeSeconds <= 0) return;

    setState(() {
      _isRunning = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentTimeSeconds > 0) {
        setState(() {
          _currentTimeSeconds--;
        });
      } else {
        _stopTimer();
        _completedPomodoros++;
        _showCompletionDialog();
        if (_completedPomodoros % _pomodoroCycle == 0) {
          _showLongBreakDialog();
        } else {
          _resetTimerToGoal();
        }
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });
  }

  void _resetTimerToGoal() {
    _stopTimer();
    setState(() {
      _currentTimeSeconds = _totalDurationSeconds;
    });
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _darkBgColor,
        title: const Text('Pomodoro Tamamlandı!', style: TextStyle(color: _whiteTextColor)),
        content: Text('Bir pomodoro tamamladınız. Toplam: $_completedPomodoros', style: const TextStyle(color: _lightTextColor)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tamam', style: TextStyle(color: _accentColor)),
          ),
        ],
      ),
    );
  }

  void _showLongBreakDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _darkBgColor,
        title: const Text('Uzun Mola Zamanı!', style: TextStyle(color: _whiteTextColor)),
        content: const Text('4 pomodoro tamamladınız. Uzun bir mola verin!', style: TextStyle(color: _lightTextColor)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetTimerToGoal();
            },
            child: const Text('Tamam', style: TextStyle(color: _accentColor)),
          ),
        ],
      ),
    );
  }

  String _formatTime(int totalSeconds) {
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBgColor, // Arka plan rengi burada kullanıldı
      body: SafeArea(
        child: Column(
          children: [
            // Timer Display with 3D Frame
            Expanded(
              flex: 3,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.blue, Colors.purple],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: const [
                      BoxShadow(
                        color: Color.fromARGB(128, 0, 0, 0), // %50 opaklık
                        offset: Offset(4, 4),
                        blurRadius: 8,
                      ),
                      BoxShadow(
                        color: Color.fromARGB(51, 255, 255, 255), // %20 opaklık
                        offset: Offset(-4, -4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(_currentTimeSeconds),
                        style: Theme.of(context).textTheme.displayLarge,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Tamamlanan Pomodorolar: $_completedPomodoros',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Circular Timer
            Expanded(
              flex: 3,
              child: Center(
                child: SizedBox(
                  width: 200,
                  height: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: _currentTimeSeconds / _totalDurationSeconds,
                        strokeWidth: 10,
                        valueColor: const AlwaysStoppedAnimation<Color>(_accentColor),
                      ),
                      GestureDetector(
                        onTap: _toggleTimer,
                        child: Icon(
                          _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          size: 80,
                          color: _isRunning ? _pauseColor : _whiteTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Controls and Quick Start Buttons
            Expanded(
              flex: 2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Slider(
                    value: _goalMinutes.toDouble(),
                    min: 1,
                    max: 60,
                    divisions: 59,
                    label: '$_goalMinutes min',
                    onChanged: (value) {
                      setState(() {
                        _goalMinutes = value.toInt();
                        _totalDurationSeconds = _goalMinutes * 60;
                        _currentTimeSeconds = _totalDurationSeconds;
                      });
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _goalMinutes = 25;
                            _totalDurationSeconds = _goalMinutes * 60;
                            _currentTimeSeconds = _totalDurationSeconds;
                          });
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: _accentColor),
                        child: const Text('25 dk Odaklan'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _goalMinutes = 5;
                            _totalDurationSeconds = _goalMinutes * 60;
                            _currentTimeSeconds = _totalDurationSeconds;
                          });
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 25, 93, 60)),
                        child: const Text('5 dk Mola'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}