// ignore_for_file: depend_on_referenced_packages

import 'package:facerecognition_flutter/EmployeeListView.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import 'package:facesdk_plugin/facesdk_plugin.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_exif_rotation/flutter_exif_rotation.dart';
import 'package:path/path.dart' hide context;
import 'package:sqflite/sqflite.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import 'settings.dart';
import 'person.dart';
import 'personview.dart';
import 'facedetectionview.dart';
import 'facecaptureview.dart';
import 'attendance_history_view.dart';
import 'staff_enrollment_view.dart';
import 'login_view.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Face Recognition',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          primaryColor: Colors.indigoAccent,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.indigoAccent,
            brightness: Brightness.dark,
            primary: Colors.indigoAccent,
            secondary: Colors.cyanAccent,
            surface: const Color(0xFF0F0F0F),
          ),
          scaffoldBackgroundColor: const Color(0xFF0F0F0F),
          cardTheme: CardTheme(
            color: const Color(0xFF1A1A1A),
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            margin: const EdgeInsets.symmetric(vertical: 8),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            titleTextStyle: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: Colors.white,
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigoAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 4,
            ),
          ),
        ),
        home: const LoginView());
  }
}

class MyHomePage extends StatefulWidget {
  final String title;
  final String role;

  const MyHomePage({super.key, required this.title, this.role = 'admin'});

  @override
  MyHomePageState createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> {
  String _warningState = "";
  bool _visibleWarning = false;
  List<Person> personList = [];
  bool _isFirstLoad = true;

  final _facesdkPlugin = FacesdkPlugin();

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    int facepluginState = -1;
    String warningState = "";
    bool visibleWarning = false;

    try {
      if (Platform.isAndroid) {
        await _facesdkPlugin
            .setActivation(
                "wWevuh/4kYz0O/XvtfJv0O0IvTJao7E4XWnKBLpQ32+bwH3GRmBGgY3RXHjQlukOsZiW/Y8uhGr8"
                "zFGb/I3AoO53qLRUbGX8BV50AF3fGXTmmoY8uj8ZKqOF7OJWZZgSEyZs36r+0kxDRiApdZa20jhq"
                "fZ56VbL+TDkA9fWu4w0EJYKsSr/t5k9hE2vfuPDczPigr0q3aZyqCvXm1foKDsCzJ2WFD2MBZy/F"
                "g/smbQLFXJmo/o8e+F64bzMc4Hf/qWvXzzCbnVVdaZPr2BTWXZ2SEpPLf6triL+tvURcUVaVP0M2"
                "qPB27Gja5dunn4PhEEtTDn1RWtFPfk7vJAmhyg==")
            .then((value) => facepluginState = value ?? -1);
      } else {
        await _facesdkPlugin
            .setActivation(
                "Z6g7MbPXuE/V8YKMxJI60L+SdnAjz6rgtyZ4CWFa2xwU3P91D6Ih0jg70qxcT856LI7TwUlQbfYs0"
                "LrEW+9B2gAeSzYHa6LQIRbSNJ5BBZ13WmOPJglJSB7G1CSYTc6YPl1ioKS0o0Vh5SwSKh5oXhavSq"
                "c2ClL6Uu4kAxKO/jE+l/EC8ifvVX5oo8HUQ/H76I0eMig8yDq9Wvci6U7IxWMZlRjCtTiZvE/nC73"
                "6sY7d/DgYhu7/i9BkRkdslvEAfi6Mcc2tOcGHX3TpZ0dv5K8bOunVt6Fe6aDAtwypeovE8nL+NRpt"
                "8L90fO1s6MRMT6gez2der2aiv2vSSo+J0g==")
            .then((value) => facepluginState = value ?? -1);
      }

      if (facepluginState == 0) {
        await _facesdkPlugin
            .init()
            .then((value) => facepluginState = value ?? -1);
      }
    } catch (e) {}

    List<Person> personList = await loadAllPersons();
    await SettingsPageState.initSettings();

    final prefs = await SharedPreferences.getInstance();
    int? livenessLevel = prefs.getInt("liveness_level");

    try {
      await _facesdkPlugin.setParam({
        'check_liveness_level': livenessLevel ?? 0,
        'check_eye_closeness': true,
        'check_face_occlusion': true,
        'check_mouth_opened': true,
        'estimate_age_gender': true
      });
    } catch (e) {}

    if (!mounted) return;

    if (facepluginState == -1) {
      warningState = "Invalid license!";
      visibleWarning = true;
    } else if (facepluginState == -2) {
      warningState = "License expired!";
      visibleWarning = true;
    } else if (facepluginState == -3) {
      warningState = "Invalid license!";
      visibleWarning = true;
    } else if (facepluginState == -4) {
      warningState = "No activated!";
      visibleWarning = true;
    } else if (facepluginState == -5) {
      warningState = "Init error!";
      visibleWarning = true;
    }

    setState(() {
      _warningState = warningState;
      _visibleWarning = visibleWarning;
      this.personList = personList;
    });

    if (facepluginState == 0 && widget.role == 'user') {
      Future.delayed(Duration.zero, () {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => FaceRecognitionView(
                    personList: this.personList,
                    logAttendance: logAttendance,
                    getLastPunchToday: getLastPunchToday,
                    insertPerson: insertPerson,
                    role: widget.role,
                  )),
        ).then((_) {
          if (mounted) {
            setState(() {
              _isFirstLoad = false;
            });
          }
        });
      });
    } else {
      setState(() {
        _isFirstLoad = false;
      });
    }
  }

  Future<Database> createDB() async {
    final database = openDatabase(
      join(await getDatabasesPath(), 'person.db'),
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE person(name text, designation text, email text, contact text, inTime text, outTime text, faceJpg blob, templates blob)',
        );
        await db.execute(
          'CREATE TABLE attendance(id INTEGER PRIMARY KEY AUTOINCREMENT, name text, designation text, date text, time text, type text, remark text)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute(
                "ALTER TABLE person ADD COLUMN designation text DEFAULT ''");
          } catch (e) {}
          try {
            await db.execute(
              'CREATE TABLE attendance(id INTEGER PRIMARY KEY AUTOINCREMENT, name text, designation text, date text, time text, type text, remark text)',
            );
          } catch (e) {}
        }
        if (oldVersion < 3) {
          try {
            await db
                .execute("ALTER TABLE person ADD COLUMN email text DEFAULT ''");
          } catch (e) {}
          try {
            await db.execute(
                "ALTER TABLE person ADD COLUMN contact text DEFAULT ''");
          } catch (e) {}
          try {
            await db.execute(
                "ALTER TABLE person ADD COLUMN inTime text DEFAULT '09:00 AM'");
          } catch (e) {}
          try {
            await db.execute(
                "ALTER TABLE person ADD COLUMN outTime text DEFAULT '06:00 PM'");
          } catch (e) {}
        }
        if (oldVersion < 4) {
          try {
            await db.execute(
                "ALTER TABLE attendance ADD COLUMN type text DEFAULT 'IN'");
          } catch (e) {}
        }
        if (oldVersion < 5) {
          try {
            await db.execute(
                "ALTER TABLE attendance ADD COLUMN remark text DEFAULT ''");
          } catch (e) {}
          try {
            await db.execute(
                "ALTER TABLE attendance ADD COLUMN designation text DEFAULT ''");
          } catch (e) {}
        }
      },
      version: 5,
    );

    return database;
  }

  Future<void> logAttendance(Person person,
      {String type = "IN", String remark = ""}) async {
    final db = await createDB();
    final now = DateTime.now();
    final dateStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final timeStr =
        "${(now.hour % 12 == 0 ? 12 : now.hour % 12).toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}";
    await db.insert('attendance', {
      'name': person.name,
      'designation': person.designation,
      'date': dateStr,
      'time': timeStr,
      'type': type,
      'remark': remark,
    });
    Fluttertoast.showToast(
      msg: "${type == "IN" ? "Attendance" : "Break"} logged for ${person.name}",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.green,
      textColor: Colors.white,
    );
  }

  Future<Map<String, dynamic>?> getLastPunchToday(String name) async {
    final db = await createDB();
    final now = DateTime.now();
    final dateStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    final List<Map<String, dynamic>> maps = await db.query(
      'attendance',
      where: 'name = ? AND date = ?',
      whereArgs: [name, dateStr],
      orderBy: 'id DESC',
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  Future<List<Person>> loadAllPersons() async {
    final db = await createDB();
    final List<Map<String, dynamic>> maps = await db.query('person');
    return List.generate(maps.length, (i) {
      return Person.fromMap(maps[i]);
    });
  }

  Future<void> insertPerson(Person person) async {
    final db = await createDB();
    await db.insert(
      'person',
      person.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    setState(() {
      personList.add(person);
    });
  }

  Future<void> deleteAllPerson() async {
    final db = await createDB();
    await db.delete('person');
    setState(() {
      personList.clear();
    });
    Fluttertoast.showToast(
        msg: "All person deleted!",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0);
  }

  Future<void> deletePerson(index) async {
    final db = await createDB();
    await db
        .delete('person', where: 'name=?', whereArgs: [personList[index].name]);
    setState(() {
      personList.removeAt(index);
    });
    Fluttertoast.showToast(
        msg: "Person removed!",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0);
  }

  Future<void> enrollPerson() async {
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image == null) return;

      var rotatedImage =
          await FlutterExifRotation.rotateImage(path: image.path);

      final faces = await _facesdkPlugin.extractFaces(rotatedImage.path);
      for (var face in faces) {
        final prefs = await SharedPreferences.getInstance();
        String? identifyThresholdStr = prefs.getString("identify_threshold");
        double identifyThreshold = double.parse(identifyThresholdStr ?? "0.8");

        bool faceExists = false;
        String matchedName = "";
        for (var p in personList) {
          double similarity = await _facesdkPlugin.similarityCalculation(
                  face['templates'], p.templates) ??
              -1;
          if (similarity > identifyThreshold) {
            faceExists = true;
            matchedName = p.name;
            break;
          }
        }

        if (faceExists) {
          Fluttertoast.showToast(
            msg: "This face is already enrolled as $matchedName!",
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
          continue;
        }

        if (mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StaffEnrollmentView(
                faceJpg: face['faceJpg'],
                templates: face['templates'],
                onEnroll: (person) async {
                  await insertPerson(person);
                },
              ),
            ),
          );
        }
      }

      if (faces.length == 0) {
        Fluttertoast.showToast(
            msg: "No face detected!",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 16.0);
      } else {
        Fluttertoast.showToast(
            msg: "Person enrolled!",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 16.0);
      }
    } catch (e) {}
  }

  // ── Name input dialog before face capture ──
  Future<void> _addEmployeeWithName() async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Employee Name',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: nameController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter full name',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: const Color(0xFF2A2A2A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            prefixIcon: const Icon(Icons.person_outline, color: Colors.white54),
          ),
          onSubmitted: (val) => Navigator.pop(ctx, val.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigoAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Next'),
          ),
        ],
      ),
    );

    nameController.dispose();

    if (name == null || name.isEmpty) return;
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FaceCaptureView(
          personList: personList,
          insertPerson: insertPerson,
          prefillName: name,
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isFirstLoad) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return WillPopScope(
      // ── Back button closes app ──
      onWillPop: () async {
        SystemNavigator.pop();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: null,
          actions: [
            if (widget.role == 'admin')
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginView()),
                    (route) => false,
                  );
                },
              ),
          ],
          title: const Text(
            'Dashboard',
            style: TextStyle(
              letterSpacing: 1,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
          toolbarHeight: 70,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        extendBodyBehindAppBar: true,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).colorScheme.surface,
                Theme.of(context).colorScheme.surface.withOpacity(0.8),
              ],
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                const SizedBox(height: 100),

                // ── Stats Header ──
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade900, Colors.blue.shade700],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Enrolled',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${personList.length} Staff',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.people_outline,
                            color: Colors.white, size: 30),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Action Grid ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      // Row 1: Add Employee + History
                      Row(
                        children: [
                          _buildActionCard(
                            context,
                            'Add Employee',
                            'Enter name & face',
                            Icons.person_add_rounded,
                            Colors.green,
                            _addEmployeeWithName,
                          ),
                          const SizedBox(width: 16),
                          _buildActionCard(
                            context,
                            'History',
                            'Log Records',
                            Icons.history_rounded,
                            Colors.purple,
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        AttendanceHistoryView()),
                              );
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Row 2: Employees (full width)
                      Row(
                        children: [
                          _buildActionCard(
                            context,
                            'Employees',
                            'View all staff',
                            Icons.people_alt_rounded,
                            Colors.orange,
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const EmployeeListView(),
                                ),
                              ).then((_) {
                                if (mounted) setState(() {});
                              });
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Settings button
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => SettingsPage(
                                      homePageState: this,
                                    )),
                          );
                        },
                        icon: const Icon(Icons.settings_outlined),
                        label: const Text('System Settings'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Text(
                        'Recent Staff',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      if (personList.isNotEmpty)
                        TextButton(
                          onPressed: deleteAllPerson,
                          child: const Text('Clear All',
                              style: TextStyle(color: Colors.redAccent)),
                        ),
                    ],
                  ),
                ),

                Stack(
                  children: [
                    PersonView(
                      personList: personList,
                      homePageState: this,
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Visibility(
                            visible: _visibleWarning,
                            child: Container(
                              width: double.infinity,
                              height: 40,
                              color: Colors.redAccent,
                              child: Center(
                                child: Text(
                                  _warningState,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 20),
                                ),
                              ),
                            ))
                      ],
                    )
                  ],
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, String title, String subtitle,
      IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.2), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                subtitle,
                style:
                    TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
