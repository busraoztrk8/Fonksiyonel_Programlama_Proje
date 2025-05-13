import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart'; // SchedulerBinding için

class AnimatedHeart extends StatefulWidget {
  final double startLeft;
  final double size;
  final Color color;
  final VoidCallback onAnimationComplete;
  final double screenHeight; // Ekran yüksekliğini almak için yeni parametre

  const AnimatedHeart({
    super.key,
    required this.startLeft,
    required this.size,
    required this.color,
    required this.onAnimationComplete,
    required this.screenHeight, // Yeni parametre zorunlu kılındı
  });

  @override
  State<AnimatedHeart> createState() => _AnimatedHeartState();
}

class _AnimatedHeartState extends State<AnimatedHeart>
    with SingleTickerProviderStateMixin {

  late AnimationController _controller;
  late Animation<double> _bottomAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    const Duration animationDuration = Duration(seconds: 2);

    _controller = AnimationController(
      duration: animationDuration,
      vsync: this,
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onAnimationComplete();
      }
    });

    // Kalbin alttan yukarı uçması için bottom değerini 0'dan ekran yüksekliğinin dışına kadar animasyonlaştır
    // screenHeight değeri artık widget parametresinden geliyor, MediaQuery kullanmıyoruz.
    _bottomAnimation = Tween<double>(
      begin: 0.0, // Ekranın altından başla
      end: widget.screenHeight + 50, // Widget'tan gelen yüksekliği kullan
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
      ),
    );

    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOutSine),
      ),
    );

    // Animasyonu başlatmak için post-frame callback hala gerekli olabilir
    // Widget layout'u tamamlandıktan sonra animasyonu başlat
     SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _controller.forward();
        }
     });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // AnimatedBuilder, _controller her değiştiğinde build metodunu yeniden çalıştırır
    // build metodu içinde context geçerlidir, ancak AnimatedHeart artık doğrudan MediaQuery kullanmıyor.
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          bottom: _bottomAnimation.value, // Animasyonlu alt pozisyon
          left: widget.startLeft, // Başlangıç sol pozisyonu (değişmez)
          child: Opacity(
            opacity: _opacityAnimation.value, // Animasyonlu opaklık
            child: Icon(
              Icons.favorite, // Kalp ikonu
              color: widget.color, // Kalp rengi
              size: widget.size,   // Kalp boyutu
            ),
          ),
        );
      },
    );
  }
}