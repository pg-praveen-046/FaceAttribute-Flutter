import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:facesdk_plugin/facedetection_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:facesdk_plugin/facesdk_plugin.dart';
import 'person.dart';
import 'facecaptureview.dart';

// ignore: must_be_immutable
class FaceRecognitionView extends StatefulWidget {
  final List<Person> personList;
  final Function(Person, {String type, String remark})? logAttendance;
  final Future<Map<String, dynamic>?> Function(String)? getLastPunchToday;
  final Function(Person)? insertPerson;
  FaceDetectionViewController? faceDetectionViewController;

  FaceRecognitionView({super.key, required this.personList, this.logAttendance, this.getLastPunchToday, this.insertPerson});

  @override
  State<StatefulWidget> createState() => FaceRecognitionViewState();
}

class FaceRecognitionViewState extends State<FaceRecognitionView> {
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

    loadSettings();
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
        Text(label, style: const TextStyle(fontSize: 16, color: Colors.white70)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
      print('x1: ' + face['x1'].toString() + ', y1: ' + face['y1'].toString() + ', x2: ' + face['x2'].toString() + ', y2: ' + face['y2'].toString());
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

      if (maxSimilarity > _identifyThreshold && maxLiveness > _livenessThreshold) {
        recognized = true;
      }
    }

    Future.delayed(const Duration(milliseconds: 100), () async {
      if (!mounted) return false;
      
      if (recognized && !_showOutRequest && !_showWelcomeCard) {
        _lastMatchedPerson = widget.personList.firstWhere((p) => p.name == maxSimilarityName);
        
        // Check if first scan today
        Map<String, dynamic>? lastPunch;
        if (widget.getLastPunchToday != null) {
          lastPunch = await widget.getLastPunchToday!(_lastMatchedPerson!.name);
        }

        final now = DateTime.now();
        final timeStr = "${now.hour % 12 == 0 ? 12 : now.hour % 12}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}";
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
            widget.logAttendance!(_lastMatchedPerson!, type: "IN", remark: _currentPunchRemark);
          }
          
          setState(() {
            _recognized = true;
            _showWelcomeCard = true;
            _faces = null;
          });
        } else {
          // Subsequent scan - Out Request (OUT)
          setState(() {
            _recognized = true;
            _showOutRequest = true;
            _faces = null;
          });
          startOutRequestTimer();
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

        if (!recognized && faces.length > 0 && faces[0]['liveness'] > _livenessThreshold && maxSimilarity <= _identifyThreshold) {
          var face = faces[0];
          if (face['yaw'].abs() < 15 && face['roll'].abs() < 15 && face['pitch'].abs() < 15 && face['face_quality'] > 0.4) {
            _isDialogShowing = true;
            faceDetectionViewController?.stopCamera();
            showEnrollDialog();
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
      widget.logAttendance!(_lastMatchedPerson!, type: "OUT", remark: _currentPunchRemark);
    }

    setState(() {
      _showOutRequest = false;
      _showWelcomeCard = true;
    });
  }

  void showEnrollDialog() async {
    bool? enroll = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Face Not Recognized'),
          content: const Text('This face is not enrolled. Do you want to enroll now?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Enroll'),
            ),
          ],
        );
      }
    );

    if (enroll == true && widget.insertPerson != null) {
       await Navigator.push(
          context,
          MaterialPageRoute(
             builder: (context) => FaceCaptureView(
                personList: widget.personList,
                insertPerson: widget.insertPerson!,
             ),
          ),
       );
    }
    
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
        faceDetectionViewController?.stopCamera();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              faceDetectionViewController?.stopCamera();
              Navigator.pop(context);
            },
          ),
          title: const Text('Face Recognition'),
          toolbarHeight: 70,
          centerTitle: true,
        ),
        body: Stack(
          children: <Widget>[
            FaceDetectionView(faceRecognitionViewState: this),
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
                bottom: 30,
                left: 15,
                right: 15,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutBack,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, 30 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: SafeArea(
                    top: false,
                    left: false,
                    right: false,
                    child: Card( 
                      elevation: 12,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      color: const Color(0xFF252525),
                      child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      child: Row(
                        children: [
                          if (_identifiedFace != null)
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.greenAccent, width: 2),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(
                                  _identifiedFace,
                                  width: 65,
                                  height: 65,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _identifiedName.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _identifiedDesignation.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.greenAccent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.check_circle, color: Colors.greenAccent, size: 32),
                        ],
                      ),
                    ),
                    ),
                  ),
                ),
              ),
            
            // Out Request Purpose Dialog
            if (_showOutRequest)
              Container(
                color: Colors.black.withOpacity(0.7),
                child: Center(
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.85,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.5), width: 1),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Out Request Purpose",
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.access_time, size: 18, color: Colors.white70),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Next face attendance check in: ${_outRequestTimer}s",
                                style: const TextStyle(fontSize: 14, color: Colors.white70),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        GridView.count(
                          shrinkWrap: true,
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 2.2,
                          children: [
                            _buildPurposeButton("Tea", Icons.coffee, Colors.blue),
                            _buildPurposeButton("Lunch", Icons.restaurant, Colors.green),
                            _buildPurposeButton("Bank", Icons.account_balance, Colors.cyan),
                            _buildPurposeButton("Others", Icons.more_horiz, Colors.orange),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Welcome / Success Card
            if (_showWelcomeCard && _lastMatchedPerson != null)
              Container(
                color: Colors.black.withOpacity(0.8),
                child: Center(
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.9,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Welcome",
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        Text(
                          _lastMatchedPerson!.name,
                          style: const TextStyle(fontSize: 22, color: Color(0xFF673AB7), fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 20),
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: MemoryImage(_lastMatchedPerson!.faceJpg),
                        ),
                        const SizedBox(height: 30),
                        _buildDetailRow("Employee ID:", "12100"),
                        _buildDetailRow("Location:", "IDL"),
                        _buildDetailRow("Email:", "ranjithkumarb8072@gmail.com"),
                        _buildDetailRow("Phone:", "8072974576"),
                        _buildDetailRow("Punch Time:", _currentPunchTime, valueColor: Colors.green),
                        _buildDetailRow("Entry Type:", _currentPunchType),
                        _buildDetailRow("Remark:", _currentPunchRemark, valueColor: Colors.black54),
                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _showWelcomeCard = false;
                                _recognized = false;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text("Next Scan", style: TextStyle(fontSize: 18, color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurposeButton(String title, IconData icon, Color color) {
    return InkWell(
      onTap: () => selectOutPurpose(title),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.6), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 16, color: valueColor ?? Colors.black54, fontWeight: valueColor != null ? FontWeight.bold : FontWeight.normal),
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
    await widget.faceRecognitionViewState._facesdkPlugin
        .setParam({'check_liveness_level': livenessLevel ?? 0, 'check_eye_closeness': true, 'check_face_occlusion': true, 'check_mouth_opened': true, 'estimate_age_gender': true});

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
        canvas.drawRect(
            Offset(face['x1'] / xScale, face['y1'] / yScale) &
                Size((face['x2'] - face['x1']) / xScale,
                    (face['y2'] - face['y1']) / yScale),
            paint);
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
