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
  final Function(Person)? logAttendance;
  final Function(Person)? insertPerson;
  FaceDetectionViewController? faceDetectionViewController;

  FaceRecognitionView({super.key, required this.personList, this.logAttendance, this.insertPerson});

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
        if (widget.logAttendance != null) {
          final matchedPerson = widget.personList.firstWhere((p) => p.name == maxSimilarityName);
          widget.logAttendance!(matchedPerson);
        }
      }
    }

    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return false;
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
      if (recognized) {
        // faceDetectionViewController?.stopCamera(); 
        setState(() {
          _faces = null;
          _recognized = true;
        });

        Timer(const Duration(seconds: 5), () {
          if (mounted) {
            setState(() {
              _recognized = false;
            });
          }
        });
      } else if (faces.length > 0 && faces[0]['liveness'] > _livenessThreshold && maxSimilarity <= _identifyThreshold) {
        var face = faces[0];
        if (face['yaw'].abs() < 15 && face['roll'].abs() < 15 && face['pitch'].abs() < 15 && face['face_quality'] > 0.4) {
          _isDialogShowing = true;
          faceDetectionViewController?.stopCamera();
          showEnrollDialog();
        }
      }
    });

    return recognized;
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
            if (_recognized)
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
          ],
        ),
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
