import 'package:flutter/material.dart';

/// Layar pembuka: gambar logo + teks, tampil sebentar lalu masuk ke halaman utama.
class SplashPage extends StatefulWidget {
  final Widget next;
  const SplashPage({super.key, required this.next});
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(PageRouteBuilder(
        pageBuilder: (_, __, ___) => widget.next,
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      ));
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF006A7A),
      body: Center(
        child: FadeTransition(
          opacity: _c,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Image.asset('assets/splash_logo.png', width: 150),
            const SizedBox(height: 24),
            const Text('Cleaner Pro',
                style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 8),
            const Text('Bersihkan HP Anda dengan mudah', style: TextStyle(color: Colors.white70, fontSize: 14)),
          ]),
        ),
      ),
    );
  }
}
