import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:facesdk_plugin/facedetection_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:facesdk_plugin/facesdk_plugin.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'person.dart';
import 'facecaptureview.dart';
import 'login_view.dart';

// ignore: must_be_immutable
class FaceRecognitionView extends StatefulWidget {
  final List<Person> personList;
  final Function(Person, {String type, String remark})? logAttendance;
  final Future<Map<String, dynamic>?> Function(String)? getLastPunchToday;
  final Function(Person)? insertPerson;
  final String role;
  FaceDetectionViewController? faceDetectionViewController;

  FaceRecognitionView(
      {super.key,
      required this.personList,
      this.logAttendance,
      this.getLastPunchToday,
      this.insertPerson,
      this.role = 'admin'});

  @override
  State<StatefulWidget> createState() => FaceRecognitionViewState();
}

class FaceRecognitionViewState extends State<FaceRecognitionView>
    with SingleTickerProviderStateMixin {
  dynamic _faces;
  double _livenessThreshold = 0;
  double _identifyThreshold = 0;
  bool _recognized = false;
  String _identifiedName = "";
  String _identifiedDesignation = "";
  String _identifiedSimilarity = "";
  String _identifiedLiveness = "";
  String _identifiedYaw = "";
  String _identifiedRoll = "";
  String _identifiedPitch = "";
  // ignore: prefer_typing_uninitialized_variables
  var _identifiedFace;
  // ignore: prefer_typing_uninitialized_variables
  var _enrolledFace;
  final _facesdkPlugin = FacesdkPlugin();
  FaceDetectionViewController? faceDetectionViewController;
  bool _isDialogShowing = false;
  late AnimationController _scannerController;
  late Animation<double> _scannerAnimation;
  bool _showOutRequest = false;
  bool _showWelcomeCard = false;
  Person? _lastMatchedPerson;
  String _currentPunchType = "IN";
  String _currentPunchRemark = "";
  String _currentPunchTime = "";
  int _outRequestTimer = 30;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();

    // Initialize scanner animation
    _scannerController = AnimationController(
      vsync: this as TickerProvider,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scannerAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _scannerController, curve: Curves.easeInOut),
    );

    loadSettings();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    String? livenessThreshold = prefs.getString("liveness_threshold");
    String? identifyThreshold = prefs.getString("identify_threshold");
    setState(() {
      _livenessThreshold = double.parse(livenessThreshold ?? "0.7");
      _identifyThreshold = double.parse(identifyThreshold ?? "0.8");
    });
  }

  Future<void> faceRecognitionStart() async {
    final prefs = await SharedPreferences.getInstance();
    var cameraLens = prefs.getInt("camera_lens");

    setState(() {
      _faces = null;
      _recognized = false;
    });

    await faceDetectionViewController?.startCamera(cameraLens ?? 1);
  }

  String _formatPercent(String value) {
    try {
      return '${(double.parse(value) * 100).toStringAsFixed(1)}%';
    } catch (e) {
      return value;
    }
  }

  String _formatDecimal(String value) {
    try {
      return double.parse(value).toStringAsFixed(2);
    } catch (e) {
      return value;
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 22, color: Colors.white70),
        const SizedBox(width: 12),
        Text(label,
            style: const TextStyle(fontSize: 16, color: Colors.white70)),
        const Spacer(),
        Text(value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Future<bool> onFaceDetected(faces) async {
    if (_recognized == true || _isDialogShowing == true) {
      return false;
    }

    if (!mounted) return false;

    setState(() {
      _faces = faces;
    });

    bool recognized = false;
    double maxSimilarity = -1;
    String maxSimilarityName = "";
    String maxSimilarityDesignation = "";
    double maxLiveness = -1;
    double maxYaw = -1;
    double maxRoll = -1;
    double maxPitch = -1;
    // ignore: prefer_typing_uninitialized_variables
    var enrolledFace, identifedFace;
    if (faces.length > 0) {
      var face = faces[0];
      print('x1: ' +
          face['x1'].toString() +
          ', y1: ' +
          face['y1'].toString() +
          ', x2: ' +
          face['x2'].toString() +
          ', y2: ' +
          face['y2'].toString());
      print('liveness: ' + face['liveness'].toString());
      print('yaw: ' + face['yaw'].toString());
      print('roll: ' + face['roll'].toString());
      print('pitch: ' + face['pitch'].toString());
      print('face_quality: ' + face['face_quality'].toString());
      print(' : ' + face['face_luminance'].toString());
      print('left_eye_closed: ' + face['left_eye_closed'].toString());
      print('right_eye_closed: ' + face['right_eye_closed'].toString());
      print('face_occlusion: ' + face['face_occlusion'].toString());
      print('mouth_opened: ' + face['mouth_opened'].toString());
      print('age: ' + face['age'].toString());
      print('gender: ' + face['gender'].toString());

      for (var person in widget.personList) {
        double similarity = await _facesdkPlugin.similarityCalculation(
                face['templates'], person.templates) ??
            -1;
        if (maxSimilarity < similarity) {
          maxSimilarity = similarity;
          maxSimilarityName = person.name;
          maxSimilarityDesignation = person.designation;
          maxLiveness = face['liveness'];
          maxYaw = face['yaw'];
          maxRoll = face['roll'];
          maxPitch = face['pitch'];
          identifedFace = face['faceJpg'];
          enrolledFace = person.faceJpg;
        }
      }

      if (maxSimilarity > _identifyThreshold &&
          maxLiveness > _livenessThreshold) {
        recognized = true;
      }
    }

    Future.delayed(const Duration(milliseconds: 100), () async {
      if (!mounted) return false;

      if (recognized && !_showOutRequest && !_showWelcomeCard) {
        _lastMatchedPerson =
            widget.personList.firstWhere((p) => p.name == maxSimilarityName);

        // Check if first scan today
        Map<String, dynamic>? lastPunch;
        if (widget.getLastPunchToday != null) {
          lastPunch = await widget.getLastPunchToday!(_lastMatchedPerson!.name);
        }

        final now = DateTime.now();
        final timeStr =
            "${(now.hour % 12 == 0 ? 12 : now.hour % 12).toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}";
        _currentPunchTime = timeStr;

        if (lastPunch == null) {
          // First scan - Attendance (IN)
          _currentPunchType = "IN";

          // Logic: 10:00 to 10:15 is Present, after 10:15 is Late
          if (now.hour < 10 || (now.hour == 10 && now.minute <= 15)) {
            _currentPunchRemark = "PRESENT";
          } else {
            int lateMinutes = (now.hour - 10) * 60 + now.minute;
            _currentPunchRemark = "$lateMinutes MINS LATE";
          }

          if (widget.logAttendance != null) {
            widget.logAttendance!(_lastMatchedPerson!,
                type: "IN", remark: _currentPunchRemark);
          }

          setState(() {
            _recognized = true;
            _showWelcomeCard = true;
            _faces = null;
          });
        } else {
          // Subsequent scan - Check if coming back from break (IN) or going on break (OUT)
          if (lastPunch != null && lastPunch['type'] == 'OUT') {
            _currentPunchType = "IN";
            _currentPunchRemark =
                "Back from ${lastPunch['remark']?.replaceAll('OUT for ', '') ?? 'Break'}";

            if (widget.logAttendance != null) {
              widget.logAttendance!(_lastMatchedPerson!,
                  type: "IN", remark: _currentPunchRemark);
            }

            setState(() {
              _recognized = true;
              _showWelcomeCard = true;
              _showOutRequest = false;
              _faces = null;
            });
          } else {
            setState(() {
              _recognized = true;
              _showOutRequest = true;
              _faces = null;
            });
            startOutRequestTimer();
          }
        }
      } else {
        setState(() {
          _recognized = recognized;
          _identifiedName = maxSimilarityName;
          _identifiedDesignation = maxSimilarityDesignation;
          _identifiedSimilarity = maxSimilarity.toString();
          _identifiedLiveness = maxLiveness.toString();
          _identifiedYaw = maxYaw.toString();
          _identifiedRoll = maxRoll.toString();
          _identifiedPitch = maxPitch.toString();
          _enrolledFace = enrolledFace;
          _identifiedFace = identifedFace;
        });

        if (!recognized &&
            faces.length > 0 &&
            faces[0]['liveness'] > _livenessThreshold &&
            maxSimilarity <= _identifyThreshold) {
          var face = faces[0];
          if (face['yaw'].abs() < 15 &&
              face['roll'].abs() < 15 &&
              face['pitch'].abs() < 15 &&
              face['face_quality'] > 0.4) {
            _isDialogShowing = true;
            faceDetectionViewController?.stopCamera();
            showNotRecognizedDialog();
          }
        }
      }
    });

    return recognized;
  }

  void startOutRequestTimer() {
    _outRequestTimer = 30;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_outRequestTimer > 0) {
          _outRequestTimer--;
        } else {
          _showOutRequest = false;
          _recognized = false;
          timer.cancel();
        }
      });
    });
  }

  void selectOutPurpose(String purpose) {
    _countdownTimer?.cancel();
    _currentPunchType = "OUT";
    _currentPunchRemark = "OUT for $purpose Break";

    if (widget.logAttendance != null && _lastMatchedPerson != null) {
      widget.logAttendance!(_lastMatchedPerson!,
          type: "OUT", remark: _currentPunchRemark);
    }

    setState(() {
      _showOutRequest = false;
      _showWelcomeCard = true;
    });
  }

  void showNotRecognizedDialog() async {
    await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 40),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 30,
                    spreadRadius: 10,
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.no_accounts_rounded,
                        color: Colors.orangeAccent, size: 48),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Face Not Recognized',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'This face is not currently in our database. Please contact admin.',
                    style: TextStyle(
                        fontSize: 14, color: Colors.white60, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orangeAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('OK',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        });

    _isDialogShowing = false;
    faceRecognitionStart();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_recognized) {
          faceRecognitionStart();
          return false;
        }
        if (widget.role == 'user') {
          return false;
        }
        faceDetectionViewController?.stopCamera();
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1117), // Portal Navy
        body: Stack(
          children: <Widget>[
            // Decorative Corner Blobs (Portal Style)
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF161B22).withOpacity(0.3),
                ),
              ),
            ),
            Positioned(
              bottom: -150,
              left: -150,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF161B22).withOpacity(0.2),
                ),
              ),
            ),

            FaceDetectionView(faceRecognitionViewState: this),

            // Dark Overlay with cutout
            IgnorePointer(
              child: CustomPaint(
                size: Size.infinite,
                painter: ScannerOverlayPainter(),
              ),
            ),

            // Header and Buttons Row
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Back Button (only for admin)
                    if (widget.role != 'user')
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                          ),
                          onPressed: () {
                            faceDetectionViewController?.stopCamera();
                            Navigator.pop(context);
                          },
                        ),
                      ),

                    // Titles
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Face Scanner',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5,
                              shadows: [
                                Shadow(
                                  color: Colors.black54,
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Position your face within the frame',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.85),
                              fontWeight: FontWeight.w500,
                              shadows: const [
                                Shadow(
                                  color: Colors.black54,
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Logout Button (only for user)
                    if (widget.role == 'user')
                      GestureDetector(
                        onTap: () {
                          faceDetectionViewController?.stopCamera();
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginView()),
                            (route) => false,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.redAccent.withOpacity(0.5), width: 1.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 16),
                              const SizedBox(width: 6),
                              const Text(
                                "Logout",
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Scanner Overlay Frame
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _scannerAnimation,
                builder: (context, child) {
                  return Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.of(context).size.width * 0.1,
                      vertical: MediaQuery.of(context).size.height * 0.2,
                    ),
                    child: Stack(
                      children: [
                        // Corners
                        _buildScannerCorner(Alignment.topLeft),
                        _buildScannerCorner(Alignment.topRight),
                        _buildScannerCorner(Alignment.bottomLeft),
                        _buildScannerCorner(Alignment.bottomRight),

                        // Scanning Line
                        if (!_recognized &&
                            !_showOutRequest &&
                            !_showWelcomeCard)
                          Positioned(
                            top: (MediaQuery.of(context).size.height * 0.6) *
                                _scannerAnimation.value,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 3,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.cyanAccent.withOpacity(0),
                                    Colors.cyanAccent,
                                    Colors.cyanAccent.withOpacity(0),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.cyanAccent.withOpacity(0.8),
                                    blurRadius: 15,
                                    spreadRadius: 3,
                                  ),
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.5),
                                    blurRadius: 5,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),

            SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: CustomPaint(
                painter: FacePainter(
                    faces: _faces, livenessThreshold: _livenessThreshold),
              ),
            ),
            if (_recognized && !_showOutRequest && !_showWelcomeCard)
              Positioned(
                bottom: 40,
                left: 20,
                right: 20,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Opacity(
                        opacity: value.clamp(0.0, 1.0),
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF1A1A1A).withOpacity(0.9),
                          const Color(0xFF2D2D2D).withOpacity(0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: Colors.cyanAccent.withOpacity(0.3),
                          width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.cyanAccent.withOpacity(0.2),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          if (_identifiedFace != null)
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.cyanAccent, width: 2),
                              ),
                              child: CircleAvatar(
                                radius: 30,
                                backgroundImage: MemoryImage(_identifiedFace),
                              ),
                            ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _identifiedName,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 1,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.cyanAccent.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _identifiedDesignation.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.cyanAccent,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.greenAccent.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.verified,
                                color: Colors.greenAccent, size: 28),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Out Request Purpose Dialog (Matched to Image)
            if (_showOutRequest)
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color: Colors.black.withOpacity(0.8),
                  child: Center(
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.95,
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1117), // Deep Portal Navy
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.05), width: 1),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              blurRadius: 20)
                        ],
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              "Out Request Purpose",
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF161B22),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.history_toggle_off,
                                      size: 14, color: Colors.blueAccent),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Next scan in: ",
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white.withOpacity(0.6)),
                                  ),
                                  Text(
                                    "${_outRequestTimer}s",
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blueAccent),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 2.5,
                              children: [
                                _buildImageStyleButton("Tea", Icons.coffee,
                                    const Color(0xFF2962FF)),
                                _buildImageStyleButton("Lunch",
                                    Icons.restaurant, const Color(0xFF2962FF)),
                                _buildImageStyleButton(
                                    "Bank",
                                    Icons.account_balance,
                                    const Color(0xFF2962FF)),
                                _buildImageStyleButton("Others",
                                    Icons.more_horiz, const Color(0xFF2962FF)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Welcome / Success Card (Modern Portal Style)
            if (_showWelcomeCard && _lastMatchedPerson != null)
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color: Colors.black.withOpacity(0.9),
                  child: Center(
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.95,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1117),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.05), width: 1),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 20),
                            // Profile with Portal guide
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: const Color(0xFF00F2FF),
                                        width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                          color: const Color(0xFF00F2FF)
                                              .withOpacity(0.2),
                                          blurRadius: 10)
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: 48,
                                    backgroundColor: Colors.black,
                                    backgroundImage: MemoryImage(
                                        _lastMatchedPerson!.faceJpg),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                        color: Color(0xFF00F2FF),
                                        shape: BoxShape.circle),
                                    child: const Icon(Icons.check,
                                        size: 14, color: Colors.black),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text("Identity Verified",
                                style: TextStyle(
                                    color: Color(0xFF00F2FF),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2)),
                            Text(_lastMatchedPerson!.name,
                                style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white)),
                            const SizedBox(height: 8),
                            // Status Pill
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: _currentPunchType == "OUT"
                                    ? Colors.red.withOpacity(0.1)
                                    : Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: (_currentPunchType == "OUT"
                                            ? Colors.red
                                            : Colors.green)
                                        .withOpacity(0.3)),
                              ),
                              child: Text(
                                "$_currentPunchType — ${_currentPunchRemark.replaceAll('OUT for ', '')}",
                                style: TextStyle(
                                    color: _currentPunchType == "OUT"
                                        ? Colors.redAccent
                                        : Colors.greenAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13),
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Info List
                            Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF161B22),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                children: [
                                  _buildImageStyleRow(
                                      Icons.work_outline,
                                      "Designation",
                                      _lastMatchedPerson!.designation),
                                  _buildImageStyleRow(Icons.alternate_email,
                                      "Email", _lastMatchedPerson!.email),
                                  _buildImageStyleRow(Icons.phone_android,
                                      "Phone", _lastMatchedPerson!.contact),
                                  _buildImageStyleRow(Icons.schedule,
                                      "Punch Time", _currentPunchTime,
                                      valueColor: Colors.blueAccent),
                                  _buildImageStyleRow(Icons.sync_alt,
                                      "Entry Type", _currentPunchType),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Done Button (Portal Blue)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                              child: SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _showWelcomeCard = false;
                                      _recognized = false;
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2962FF),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    elevation: 0,
                                  ),
                                  child: const Text("Confirm & Continue",
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerCorner(Alignment alignment) {
    bool isLeft =
        alignment == Alignment.topLeft || alignment == Alignment.bottomLeft;
    bool isTop =
        alignment == Alignment.topLeft || alignment == Alignment.topRight;

    return Align(
      alignment: alignment,
      child: Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          border: Border(
            top: isTop
                ? const BorderSide(color: Colors.cyanAccent, width: 4)
                : BorderSide.none,
            bottom: !isTop
                ? const BorderSide(color: Colors.cyanAccent, width: 4)
                : BorderSide.none,
            left: isLeft
                ? const BorderSide(color: Colors.cyanAccent, width: 4)
                : BorderSide.none,
            right: !isLeft
                ? const BorderSide(color: Colors.cyanAccent, width: 4)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildImageStyleButton(String title, IconData icon, Color color) {
    return InkWell(
      onTap: () => selectOutPurpose(title),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(icon, color: Colors.blueAccent, size: 18),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageStyleRow(IconData icon, String label, String value,
      {Color? valueColor, bool isLast = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white.withOpacity(0.4)),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(
                      fontSize: 14, color: Colors.white.withOpacity(0.5)),
                ),
                Text(
                  value.isEmpty ? "N/A" : value,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: valueColor ?? Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FaceDetectionView extends StatefulWidget
    implements FaceDetectionInterface {
  FaceRecognitionViewState faceRecognitionViewState;

  FaceDetectionView({super.key, required this.faceRecognitionViewState});

  @override
  Future<void> onFaceDetected(faces) async {
    await faceRecognitionViewState.onFaceDetected(faces);
  }

  @override
  State<StatefulWidget> createState() => _FaceDetectionViewState();
}

class _FaceDetectionViewState extends State<FaceDetectionView> {
  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidView(
        viewType: 'facedetectionview',
        onPlatformViewCreated: _onPlatformViewCreated,
      );
    } else {
      return UiKitView(
        viewType: 'facedetectionview',
        onPlatformViewCreated: _onPlatformViewCreated,
      );
    }
  }

  void _onPlatformViewCreated(int id) async {
    final prefs = await SharedPreferences.getInstance();
    var cameraLens = prefs.getInt("camera_lens");

    widget.faceRecognitionViewState.faceDetectionViewController =
        FaceDetectionViewController(id, widget);

    await widget.faceRecognitionViewState.faceDetectionViewController
        ?.initHandler();

    int? livenessLevel = prefs.getInt("liveness_level");
    await widget.faceRecognitionViewState._facesdkPlugin.setParam({
      'check_liveness_level': livenessLevel ?? 0,
      'check_eye_closeness': true,
      'check_face_occlusion': true,
      'check_mouth_opened': true,
      'estimate_age_gender': true
    });

    await widget.faceRecognitionViewState.faceDetectionViewController
        ?.startCamera(cameraLens ?? 1);
  }
}

class FacePainter extends CustomPainter {
  dynamic faces;
  double livenessThreshold;
  FacePainter({required this.faces, required this.livenessThreshold});

  @override
  void paint(Canvas canvas, Size size) {
    if (faces != null) {
      var paint = Paint();
      paint.color = const Color.fromARGB(0xff, 0xff, 0, 0);
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 3;

      for (var face in faces) {
        double xScale = face['frameWidth'] / size.width;
        double yScale = face['frameHeight'] / size.height;

        String title = "";
        Color color = const Color.fromARGB(0xff, 0xff, 0, 0);
        if (face['liveness'] < livenessThreshold) {
          color = const Color.fromARGB(0xff, 0xff, 0, 0);
          title = "Spoof" + face['liveness'].toString();
        } else {
          color = const Color.fromARGB(0xff, 0, 0xff, 0);
          title = "Real " + face['liveness'].toString();
        }

        TextSpan span =
            TextSpan(style: TextStyle(color: color, fontSize: 20), text: title);
        TextPainter tp = TextPainter(
            text: span,
            textAlign: TextAlign.left,
            textDirection: TextDirection.ltr);
        tp.layout();
        tp.paint(canvas, Offset(face['x1'] / xScale, face['y1'] / yScale - 30));

        paint.color = color;
        double left = face['x1'] / xScale;
        double top = face['y1'] / yScale;
        double right = face['x2'] / xScale;
        double bottom = face['y2'] / yScale;
        double cornerSize = 20;

        // Draw corners instead of full rect for a cleaner look
        Path path = Path()
          ..moveTo(left, top + cornerSize)
          ..lineTo(left, top)
          ..lineTo(left + cornerSize, top)
          ..moveTo(right - cornerSize, top)
          ..lineTo(right, top)
          ..lineTo(right, top + cornerSize)
          ..moveTo(right, bottom - cornerSize)
          ..lineTo(right, bottom)
          ..lineTo(right - cornerSize, bottom)
          ..moveTo(left + cornerSize, bottom)
          ..lineTo(left, bottom)
          ..lineTo(left, bottom - cornerSize);

        canvas.drawPath(path, paint);

        // Add subtle glow to corners
        paint.strokeWidth = 1;
        paint.color = color.withOpacity(0.3);
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final scanArea = Rect.fromLTWH(
      size.width * 0.1,
      size.height * 0.2,
      size.width * 0.8,
      size.height * 0.6,
    );

    final paint = Paint()
      ..color = Colors.black.withOpacity(0.75)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..addRect(rect)
      ..addRect(scanArea);
    
    path.fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
