import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'facedetectionview.dart';
import 'person.dart';
import 'login_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:facerecognition_flutter/main.dart';

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

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 48),
                const SizedBox(height: 16),
                const Text(
                  "Confirm Logout",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Are you sure you want to log out and end this session?",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text("Cancel", style: TextStyle(color: Colors.white54, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginView()),
                            (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text("Logout", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background Glow
          Positioned.fill(
            child: CustomPaint(
              painter: _BackgroundGlowPainter(brightness: theme.brightness),
            ),
          ),

          // Back Button for Admin
          if (widget.role != 'user')
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                    shape: BoxShape.circle,
                    border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                  ),
                  child: Icon(Icons.arrow_back_ios_new, color: isDark ? Colors.white : Colors.black87, size: 18),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),

          // Theme Toggle Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 130,
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                  shape: BoxShape.circle,
                  border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                ),
                child: ValueListenableBuilder<ThemeMode>(
                  valueListenable: themeNotifier,
                  builder: (_, mode, __) {
                    return Icon(
                      mode == ThemeMode.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      color: mode == ThemeMode.dark ? Colors.yellowAccent : Colors.grey,
                      size: 20,
                    );
                  },
                ),
              ),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                if (themeNotifier.value == ThemeMode.dark) {
                  themeNotifier.value = ThemeMode.light;
                  await prefs.setBool("is_dark_mode", false);
                } else {
                  themeNotifier.value = ThemeMode.dark;
                  await prefs.setBool("is_dark_mode", true);
                }
              },
            ),
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 16,
            child: ElevatedButton.icon(
              onPressed: _showLogoutDialog,
              icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 16),
              label: const Text(
                "Logout",
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.15),
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.redAccent.withOpacity(0.5), width: 1.5),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
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
                                  brightness: theme.brightness,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 50),
                      
                      // Text Description
                      Text(
                        "Face Scanner",
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
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
                            color: isDark ? Colors.white.withOpacity(0.6) : Colors.black87.withOpacity(0.6),
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
  final Brightness brightness;
  _BackgroundGlowPainter({required this.brightness});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (brightness == Brightness.dark ? Colors.cyanAccent : Colors.cyan).withOpacity(0.05)
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
  final Brightness brightness;

  _ScannerAnimationPainter({required this.progress, required this.brightness});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw outer rings
    final ringPaint = Paint()
      ..color = (brightness == Brightness.dark ? Colors.indigoAccent : Colors.indigo).withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
      
    canvas.drawCircle(center, radius, ringPaint);
    canvas.drawCircle(center, radius * 0.8, ringPaint..color = (brightness == Brightness.dark ? Colors.cyanAccent : Colors.cyan).withOpacity(0.1));

    // Draw scanning arc
    final arcPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          (brightness == Brightness.dark ? Colors.cyanAccent : Colors.cyan).withOpacity(0.0),
          brightness == Brightness.dark ? Colors.cyanAccent : Colors.cyan,
          (brightness == Brightness.dark ? Colors.cyanAccent : Colors.cyan).withOpacity(0.0),
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
      ..color = (brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.8)
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
      ..color = brightness == Brightness.dark ? Colors.cyanAccent : Colors.cyan
      ..style = PaintingStyle.fill;
      
    canvas.drawCircle(Offset(center.dx - radius * 0.15, center.dy - radius * 0.05), 3, nodePaint);
    canvas.drawCircle(Offset(center.dx + radius * 0.15, center.dy - radius * 0.05), 3, nodePaint);
    canvas.drawCircle(Offset(center.dx, center.dy + radius * 0.15), 3, nodePaint);
  }

  @override
  bool shouldRepaint(covariant _ScannerAnimationPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.brightness != brightness;
  }
}
