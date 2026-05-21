import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'facedetectionview.dart';
import 'person.dart';

class ScannerIntroView extends StatefulWidget {
  final List<Person> personList;
  final dynamic Function(Person, {String remark, String type})? logAttendance;
  final Future<Map<String, dynamic>?> Function(String)? getLastPunchToday;
  final dynamic Function(Person)? insertPerson;
  final String role;

  const ScannerIntroView({
    super.key,
    required this.personList,
    required this.logAttendance,
    required this.getLastPunchToday,
    required this.insertPerson,
    required this.role,
  });

  @override
  State<ScannerIntroView> createState() => _ScannerIntroViewState();
}

class _ScannerIntroViewState extends State<ScannerIntroView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startScanning() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => FaceRecognitionView(
          personList: widget.personList,
          logAttendance: widget.logAttendance,
          getLastPunchToday: widget.getLastPunchToday,
          insertPerson: widget.insertPerson,
          role: widget.role,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutQuart;

          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Stack(
        children: [
          // Background Glow
          Positioned.fill(
            child: CustomPaint(
              painter: _BackgroundGlowPainter(),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      
                      // Animated Face Scanner Graphic
                      Center(
                        child: SizedBox(
                          width: 200,
                          height: 200,
                          child: AnimatedBuilder(
                            animation: _controller,
                            builder: (context, child) {
                              return CustomPaint(
                                painter: _ScannerAnimationPainter(
                                  progress: _controller.value,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 50),
                      
                      // Text Description
                      const Text(
                        "Face Scanner",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          "Securely log your attendance by verifying your identity with the advanced facial recognition system.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // Start Button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                        child: GestureDetector(
                          onTap: _startScanning,
                          child: Container(
                            width: double.infinity,
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Colors.cyanAccent, Colors.indigoAccent],
                              ),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.cyanAccent.withOpacity(0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                "START SCANNING",
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackgroundGlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.05)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 100);

    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.3),
      size.width * 0.5,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScannerAnimationPainter extends CustomPainter {
  final double progress;

  _ScannerAnimationPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw outer rings
    final ringPaint = Paint()
      ..color = Colors.indigoAccent.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
      
    canvas.drawCircle(center, radius, ringPaint);
    canvas.drawCircle(center, radius * 0.8, ringPaint..color = Colors.cyanAccent.withOpacity(0.1));

    // Draw scanning arc
    final arcPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.cyanAccent.withOpacity(0.0),
          Colors.cyanAccent,
          Colors.cyanAccent.withOpacity(0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
        transform: GradientRotation(progress * 2 * math.pi),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      progress * 2 * math.pi,
      math.pi / 2,
      false,
      arcPaint,
    );
    
    // Draw center face outline (simplified)
    final facePaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
      
    final facePath = Path()
      ..moveTo(center.dx - radius * 0.3, center.dy - radius * 0.2)
      ..lineTo(center.dx - radius * 0.2, center.dy + radius * 0.3)
      ..lineTo(center.dx + radius * 0.2, center.dy + radius * 0.3)
      ..lineTo(center.dx + radius * 0.3, center.dy - radius * 0.2)
      ..close();
      
    canvas.drawPath(facePath, facePaint);
    
    // Face nodes
    final nodePaint = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.fill;
      
    canvas.drawCircle(Offset(center.dx - radius * 0.15, center.dy - radius * 0.05), 3, nodePaint);
    canvas.drawCircle(Offset(center.dx + radius * 0.15, center.dy - radius * 0.05), 3, nodePaint);
    canvas.drawCircle(Offset(center.dx, center.dy + radius * 0.15), 3, nodePaint);
  }

  @override
  bool shouldRepaint(covariant _ScannerAnimationPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
