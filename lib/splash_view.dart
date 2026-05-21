import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'login_view.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _scanController;
  late AnimationController _pulseController;
  late AnimationController _progressController;

  late Animation<double> _fadeIn;
  late Animation<double> _scale;
  late Animation<double> _titleSlide;
  late Animation<double> _scanY;
  late Animation<double> _pulse;
  late Animation<double> _progress;

  static const _bgDark = Color(0xFF080C14);
  static const _cyan = Color(0xFF22D3EE);
  static const _indigo = Color(0xFF6366F1);

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..forward();

    _fadeIn = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    _scale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    _titleSlide = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    _scanY = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOut),
    );

    _pulse = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _progress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    _mainController.forward();

    Timer(const Duration(milliseconds: 3000), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 700),
            pageBuilder: (_, __, ___) => const LoginView(),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _scanController.dispose();
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _bgDark,
      body: Stack(
        children: [
          // Grid dot background
          CustomPaint(
            size: size,
            painter: _GridPainter(),
          ),

          // Ambient glow blobs
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (_, __) => CustomPaint(
                painter: _GlowPainter(_pulseController.value),
              ),
            ),
          ),

          // Main content
          AnimatedBuilder(
            animation: _mainController,
            builder: (context, _) {
              return Opacity(
                opacity: _fadeIn.value,
                child: Transform.scale(
                  scale: _scale.value,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Pulsing rings + scan frame
                        AnimatedBuilder(
                          animation: Listenable.merge(
                              [_pulseController, _scanController]),
                          builder: (_, __) {
                            return SizedBox(
                              width: 220,
                              height: 220,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Outer rings
                                  ...[200.0, 240.0, 280.0].asMap().entries.map(
                                        (e) => Transform.scale(
                                          scale: e.key == 0
                                              ? _pulse.value
                                              : (e.key == 1
                                                  ? 1 + (_pulse.value - 1) * 0.6
                                                  : 1 +
                                                      (_pulse.value - 1) * 0.3),
                                          child: Container(
                                            width: e.value,
                                            height: e.value,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: _cyan.withOpacity(
                                                  [0.25, 0.15, 0.08][e.key],
                                                ),
                                                width: 1,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                  // Face container
                                  Container(
                                    width: 160,
                                    height: 160,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _cyan.withOpacity(0.04),
                                      border: Border.all(
                                        color: _cyan.withOpacity(0.22),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          const Icon(
                                            Icons.face_unlock_rounded,
                                            size: 72,
                                            color: _cyan,
                                          ),
                                          // Scan line
                                          Positioned(
                                            top: 160 * _scanY.value,
                                            left: 0,
                                            right: 0,
                                            child: Opacity(
                                              opacity: _scanLineOpacity(
                                                  _scanY.value),
                                              child: Container(
                                                height: 2,
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      Colors.transparent,
                                                      _cyan.withOpacity(0.7),
                                                      _cyan,
                                                      _cyan.withOpacity(0.7),
                                                      Colors.transparent,
                                                    ],
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: _cyan
                                                          .withOpacity(0.5),
                                                      blurRadius: 8,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Corner brackets
                                  CustomPaint(
                                    size: const Size(180, 180),
                                    painter: _CornerBracketPainter(
                                      _pulseController.value,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 36),

                        // Title
                        Transform.translate(
                          offset: Offset(0, _titleSlide.value),
                          child: const Text(
                            'FACE SCANNER',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 4.0,
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        Transform.translate(
                          offset: Offset(0, _titleSlide.value * 1.4),
                          child: Text(
                            'SECURE ACCESS PORTAL',
                            style: TextStyle(
                              fontSize: 12,
                              color: _cyan.withOpacity(0.65),
                              letterSpacing: 4.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                        const SizedBox(height: 48),

                        // Progress bar
                        AnimatedBuilder(
                          animation: _progress,
                          builder: (_, __) => Column(
                            children: [
                              SizedBox(
                                width: 160,
                                height: 2,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: _progress.value,
                                    backgroundColor:
                                        Colors.white.withOpacity(0.08),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                            _cyan),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'INITIALIZING...',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withOpacity(0.3),
                                  letterSpacing: 3.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // Version tag
          const Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'v2.4.1 · BIOMETRIC',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0x30FFFFFF),
                  letterSpacing: 2.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _scanLineOpacity(double t) {
    if (t < 0.1) return t / 0.1;
    if (t > 0.9) return (1.0 - t) / 0.1;
    return 1.0;
  }
}

// --- Custom Painters ---

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF44AAFF).withOpacity(0.1)
      ..style = PaintingStyle.fill;
    const spacing = 28.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}

class _GlowPainter extends CustomPainter {
  final double t;
  _GlowPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    canvas.drawCircle(
      Offset(cx, cy),
      160 + t * 12,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF22D3EE).withOpacity(0.08),
            Colors.transparent,
          ],
        ).createShader(
            Rect.fromCircle(center: Offset(cx, cy), radius: 160 + t * 12)),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      240 + t * 8,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF6366F1).withOpacity(0.05),
            Colors.transparent,
          ],
        ).createShader(
            Rect.fromCircle(center: Offset(cx, cy), radius: 240 + t * 8)),
    );
  }

  @override
  bool shouldRepaint(_GlowPainter old) => old.t != t;
}

class _CornerBracketPainter extends CustomPainter {
  final double pulse;
  _CornerBracketPainter(this.pulse);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF22D3EE).withOpacity(0.5 + pulse * 0.5)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const len = 22.0;
    final pad = (size.width - 170) / 2;

    void drawCorner(double x, double y, double dx, double dy) {
      canvas.drawLine(Offset(x, y + dy * len), Offset(x, y), paint);
      canvas.drawLine(Offset(x, y), Offset(x + dx * len, y), paint);
    }

    drawCorner(pad, pad, 1, 1);
    drawCorner(size.width - pad, pad, -1, 1);
    drawCorner(pad, size.height - pad, 1, -1);
    drawCorner(size.width - pad, size.height - pad, -1, -1);
  }

  @override
  bool shouldRepaint(_CornerBracketPainter old) => old.pulse != pulse;
}
