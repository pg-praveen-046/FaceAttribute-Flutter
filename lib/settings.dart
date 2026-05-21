import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'main.dart';

class SettingsPage extends StatefulWidget {
  final MyHomePageState homePageState;

  const SettingsPage({super.key, required this.homePageState});

  @override
  SettingsPageState createState() => SettingsPageState();
}

class LivenessDetectionLevel {
  String levelName;
  int levelValue;

  LivenessDetectionLevel(this.levelName, this.levelValue);
}

const double _kItemExtent = 40.0;
const List<String> _livenessLevelNames = <String>[
  'Best Accuracy',
  'Light Weight',
];

class SettingsPageState extends State<SettingsPage> {
  bool _cameraLens = false;
  String _livenessThreshold = "0.7";
  String _identifyThreshold = "0.8";
  List<LivenessDetectionLevel> livenessDetectionLevel = [
    LivenessDetectionLevel('Best Accuracy', 0),
    LivenessDetectionLevel('Light Weight', 1),
  ];
  int _selectedLivenessLevel = 0;

  final livenessController = TextEditingController();
  final identifyController = TextEditingController();

  static Future<void> initSettings() async {
    final prefs = await SharedPreferences.getInstance();
    var firstWrite = prefs.getInt("first_write");
    if (firstWrite == 0) {
      await prefs.setInt("first_write", 1);
      await prefs.setInt("camera_lens", 1);
      await prefs.setInt("liveness_level", 0);
      await prefs.setString("liveness_threshold", "0.7");
      await prefs.setString("identify_threshold", "0.8");
    }
  }

  @override
  void initState() {
    super.initState();

    loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    var cameraLens = prefs.getInt("camera_lens");
    var livenessLevel = prefs.getInt("liveness_level");
    var livenessThreshold = prefs.getString("liveness_threshold");
    var identifyThreshold = prefs.getString("identify_threshold");

    setState(() {
      _cameraLens = cameraLens == 1 ? true : false;
      _livenessThreshold = livenessThreshold ?? "0.7";
      _identifyThreshold = identifyThreshold ?? "0.8";
      _selectedLivenessLevel = livenessLevel ?? 0;
      livenessController.text = _livenessThreshold;
      identifyController.text = _identifyThreshold;
    });
  }

  Future<void> restoreSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("first_write", 0);
    await initSettings();
    await loadSettings();

    Fluttertoast.showToast(
        msg: "Default settings restored!",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0);
  }

  Future<void> updateLivenessLevel(value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("liveness_level", value);
  }

  Future<void> updateCameraLens(value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("camera_lens", value ? 1 : 0);

    setState(() {
      _cameraLens = value;
    });
  }

  Future<void> updateLivenessThreshold(BuildContext context) async {
    try {
      var doubleValue = double.parse(livenessController.text);
      if (doubleValue >= 0 && doubleValue < 1.0) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("liveness_threshold", livenessController.text);

        setState(() {
          _livenessThreshold = livenessController.text;
        });
      }
    } catch (e) {}

    // ignore: use_build_context_synchronously
    Navigator.pop(context, 'OK');
    setState(() {
      livenessController.text = _livenessThreshold;
    });
  }

  Future<void> updateIdentifyThreshold(BuildContext context) async {
    try {
      var doubleValue = double.parse(identifyController.text);
      if (doubleValue >= 0 && doubleValue < 1.0) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("identify_threshold", identifyController.text);

        setState(() {
          _identifyThreshold = identifyController.text;
        });
      }
    } catch (e) {}

    // ignore: use_build_context_synchronously
    Navigator.pop(context, 'OK');
    setState(() {
      identifyController.text = _identifyThreshold;
    });
  }

// This shows a CupertinoModalPopup with a reasonable fixed height which hosts CupertinoPicker.
  void _showDialog(Widget child) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => Container(
        height: 216,
        padding: const EdgeInsets.only(top: 6.0),
        // The Bottom margin is provided to align the popup above the system navigation bar.
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        // Provide a background color for the popup.
        color: CupertinoColors.systemBackground.resolveFrom(context),
        // Use a SafeArea widget to avoid system overlaps.
        child: SafeArea(
          top: false,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('System Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
            const SizedBox(height: 16),
            _buildSectionHeader('General Configuration'),
            _buildSettingsCard([
              _buildSwitchTile(
                'Front Camera',
                'Toggle front/back camera',
                Icons.camera_front_rounded,
                _cameraLens,
                (value) => updateCameraLens(value),
              ),
            ]),
            const SizedBox(height: 24),
            _buildSectionHeader('Recognition Thresholds'),
            _buildSettingsCard([
              _buildNavigationTile(
                'Liveness Level',
                _livenessLevelNames[_selectedLivenessLevel],
                Icons.security_rounded,
                Colors.orangeAccent,
                () => _showLivenessPicker(),
              ),
              const Divider(height: 1, color: Colors.white10),
              _buildNavigationTile(
                'Liveness Threshold',
                _livenessThreshold,
                Icons.radar_rounded,
                Colors.cyanAccent,
                () => _showThresholdDialog('Liveness Threshold', livenessController, () => updateLivenessThreshold(context)),
              ),
              const Divider(height: 1, color: Colors.white10),
              _buildNavigationTile(
                'Identify Threshold',
                _identifyThreshold,
                Icons.face_retouching_natural_rounded,
                Colors.indigoAccent,
                () => _showThresholdDialog('Identify Threshold', identifyController, () => updateIdentifyThreshold(context)),
              ),
            ]),
            const SizedBox(height: 24),
            _buildSectionHeader('Data Management'),
            _buildSettingsCard([
              _buildNavigationTile(
                'Restore Defaults',
                'Reset all system values',
                Icons.settings_backup_restore_rounded,
                Colors.amberAccent,
                () => restoreSettings(),
              ),
              const Divider(height: 1, color: Colors.white10),
              _buildNavigationTile(
                'Clear Database',
                'Delete all enrolled persons',
                Icons.delete_sweep_rounded,
                Colors.redAccent,
                () => widget.homePageState.deleteAllPerson(),
              ),
            ]),
            const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: Colors.white.withOpacity(0.4),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, IconData icon, bool value, Function(bool) onChanged) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: Colors.blueAccent),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4))),
      trailing: CupertinoSwitch(
        value: value,
        activeColor: Colors.indigoAccent,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildNavigationTile(String title, String value, IconData icon, Color color, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14)),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white.withOpacity(0.2)),
        ],
      ),
    );
  }

  void _showLivenessPicker() {
    _showDialog(
      CupertinoPicker(
        magnification: 1.22,
        squeeze: 1.2,
        useMagnifier: true,
        itemExtent: _kItemExtent,
        scrollController: FixedExtentScrollController(initialItem: _selectedLivenessLevel),
        onSelectedItemChanged: (int selectedItem) {
          setState(() => _selectedLivenessLevel = selectedItem);
          updateLivenessLevel(selectedItem);
        },
        children: List<Widget>.generate(_livenessLevelNames.length, (int index) {
          return Center(child: Text(_livenessLevelNames[index], style: const TextStyle(color: Colors.white)));
        }),
      ),
    );
  }

  void _showThresholdDialog(String title, TextEditingController controller, VoidCallback onSave) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.indigoAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.tune_rounded, color: Colors.indigoAccent, size: 32),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter value (0.0 - 1.0)',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigoAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
